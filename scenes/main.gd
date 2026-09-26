extends Node2D

## Main del juego. Se encarga de:
##   - Sesión anónima en Supabase (sólo para subir la partida al ranking)
##   - Oleadas de monstruos: wave N tiene 3 + N*2 bichos; cuando
##     matás todos, break de 3s y viene la próxima
##   - Wire del daño monster→player y muerte del player

const MONSTER_SCENE := preload("res://scenes/monster.tscn")
const LEVEL_UP_MENU_SCENE := preload("res://scenes/level_up_menu.tscn")
const TOUCH_CONTROLS_SCENE := preload("res://scenes/touch_controls.tscn")
const PAUSE_MENU_SCENE := preload("res://scenes/pause_menu.tscn")
const RESULTS_SCENE := preload("res://scenes/results_screen.tscn")
const RpgTheme := preload("res://scenes/rpg_theme.gd")

## Muerte: cámara lenta, la pantalla se oscurece y aparece MORISTE;
## recién después los resultados (antes saltaban casi al instante y no
## se entendía que habías perdido).
const DEATH_SLOWMO := 0.3
const DEATH_SCREEN_SEC := 2.4   # segundos reales hasta los resultados

## La partida se gana al limpiar esta oleada (jefe en la 10 y jefe
## final en la 20). Después de ganar se puede seguir en modo infinito.
const FINAL_WAVE := 20
const BOSS_EVERY := 10

## El kind (rata/murciélago/cangrejo/etc, con su propio set de
## animaciones) lo resuelve monster.gd — ver KIND_IDS/BOSS_KIND_ID/
## KIND_DATA ahí. Acá sólo elegimos cuál al azar.

const SPAWN_INNER := 500.0
const SPAWN_OUTER := 800.0
const WAVE_BREAK_SEC := 2.5
# Densidad VS: mucho más volumen. Waves cortas y agresivas.
const BASE_MONSTERS := 8
const MONSTERS_PER_WAVE := 4

# La velocidad de los monstruos sube con cada wave, no sólo la
# cantidad — 3.5% más rápido por wave, tope en 75% extra (wave ~21)
# para que no se vuelva injugable en runs largas.
const WAVE_SPEED_STEP := 0.035
const WAVE_SPEED_CAP := 1.75

@onready var _monsters_container: Node2D = $Monsters
@onready var _player: CharacterBody2D = $Player
@onready var _hud: CanvasLayer = $HUD
@onready var _world = $World

var _current_wave: int = 0
var _monsters_alive: int = 0
var _in_break: bool = false
## Cuenta cuántos bosses ya spawneó la run — para elegir demon1/2/3.
var _bosses_spawned: int = 0
## true después de ganar y elegir SEGUIR: el desafío de las oleadas
## 21-30 (mucho más duro). Superarlo abre la legendaria del mapa.
var _challenge: bool = false
var _run_over: bool = false
var _death_label: Label
## FINAL_WAVE salvo en el reto diario (más corto).
var _final_wave: int = FINAL_WAVE
## Umbrales de dificultad. Debajo de MID sólo tier 1 (crías). Entre
## MID y HIGH mix de tier 1 y 2. En HIGH sólo tier 2 y 3 (los más
## amenazantes). Se siente la escalada de la run sin necesidad de
## tocar nada más.
const WAVE_MID_START := 4
const WAVE_HIGH_START := 7

func _ready() -> void:
	print("[main] booting…")
	GameState.start_run()
	# Reto diario: misma semilla para todos ese día (cartas y oleadas
	# arrancan igual), 10 oleadas y el modificador del día.
	if GameState.daily_active:
		seed(GameState.daily_info()["seed"])
		_final_wave = GameState.DAILY_WAVES
	Supabase.ensure_session(GameState.ensure_player_name())
	_player.hp_changed.connect(_hud.on_hp_changed)
	_player.defense_changed.connect(_hud.on_defense_changed)
	_player.xp_changed.connect(_hud.on_xp_changed)
	_player.leveled_up.connect(_on_player_leveled_up)
	_player.died.connect(_on_player_died)
	_player.upgrades_changed.connect(_hud.on_upgrades_changed)
	_player.skill_cooldown_changed.connect(_hud.on_skill_cooldown)
	_hud.skill_pressed.connect(_player.use_active_skill)
	_hud.setup_skill(_player.active_skill)
	match GameState.daily_modifier():
		"meteoros":
			_player.apply_upgrade("meteors")
		"cristal":
			_player.max_hp *= 0.5
			_player.hp = _player.max_hp
			_player.damage_mult *= 1.5
			_player.emit_signal("hp_changed", _player.hp, _player.max_hp)
	_hud.set_portrait(_player.portrait_texture())
	_update_wave_hud()
	# Joystick táctil — vive siempre; en desktop no molesta porque
	# no recibe eventos de touch. En web/mobile permite jugar sin
	# teclado.
	var tc = TOUCH_CONTROLS_SCENE.instantiate()
	add_child(tc)
	tc.move_input.connect(_player.set_touch_input)
	# Música de gameplay al arrancar la scene
	Audio.play_music("gameplay_chill", 1200)
	# Primer wave con un delay corto para que veas el mundo un
	# segundo antes de que caiga la fiesta
	get_tree().create_timer(1.5).timeout.connect(_start_next_wave)

## F11 para agrandar/achicar la ventana sin tener que volver al menú
## (ahí las Opciones ya tienen el mismo toggle vía checkbox).
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN
		)
	# ESC abre pausa — sólo si nada más ya pausó el juego (ej: el modal
	# de level-up), para no apilar dos menús pausados a la vez.
	if event.is_action_pressed("ui_cancel") and not get_tree().paused and not _run_over:
		var pause_menu = PAUSE_MENU_SCENE.instantiate()
		add_child(pause_menu)
		pause_menu.setup(_player)
		get_tree().paused = true
		get_viewport().set_input_as_handled()

# ── Waves ────────────────────────────────────────────────────────

func _start_next_wave() -> void:
	if _run_over:
		return
	# Logro "Intocable": oleadas completas sin recibir daño.
	if _current_wave > 0 and not _player.took_damage:
		GameState.report_max("no_hit_wave", _current_wave)
	_current_wave += 1
	_in_break = false
	var count := BASE_MONSTERS + _current_wave * MONSTERS_PER_WAVE
	# En el desafío NO hay más bichos (en el teléfono 180 a la vez era
	# mucho): son más duros (CHALLENGE_*_STEP) y traen más élites.
	if GameState.daily_modifier() == "horda":
		count = int(count * 1.5)
	# Cada 10 waves aparece 1 boss extra, bastante más grande y duro
	# que el resto (ver KIND_DATA["golem"] en monster.gd).
	var boss_count: int = 1 if _current_wave % BOSS_EVERY == 0 else 0
	if boss_count > 0:
		_player.shake(6.0)
	print("[main] wave %d — %d monsters + %d bosses" % [_current_wave, count, boss_count])
	Audio.play_sfx("wave_start")
	# En wave con boss, cambiamos a música de boss (cross-fade)
	if boss_count > 0:
		Audio.play_music("boss", 800)
		Audio.play_sfx("boss_spawn")
	# Cuando la intensidad sube (wave 5+), pasamos a track más agresivo
	elif _current_wave == 5:
		Audio.play_music("gameplay_intense", 1500)
	# Élites (sueltan cofre): uno cada 3 oleadas, dos desde la 12.
	var elite_count: int = 0
	if _current_wave % 3 == 0:
		elite_count = 2 if _current_wave >= 12 else 1
	if GameState.daily_modifier() == "elites":
		elite_count = 2
	if _challenge:
		elite_count = 2 if _current_wave < 25 else 3
	# Se encolan y aparecen de a pocos por frame (ver _process): crear la
	# oleada entera en un frame costaba 20-60 ms en PC y casi un segundo
	# en el teléfono — el juego se "frenaba" al empezar cada oleada.
	for i in range(count):
		_spawn_queue.append([false, i < elite_count])
	for i in range(boss_count):
		_spawn_queue.append([true, false])
	# += y no =: si quedara alguna cría suelta de la oleada anterior,
	# no se pierde de la cuenta. Cuenta también los que están en cola.
	_monsters_alive += count + boss_count
	_update_wave_hud()

## Monstruos de la oleada que todavía no aparecieron: [es_jefe, es_élite].
var _spawn_queue: Array = []
const SPAWNS_PER_FRAME := 3

func _process(_delta: float) -> void:
	if _spawn_queue.is_empty() or get_tree().paused:
		return
	if _run_over:
		_spawn_queue.clear()
		return
	for i in range(mini(SPAWNS_PER_FRAME, _spawn_queue.size())):
		var entry: Array = _spawn_queue.pop_front()
		_spawn_monster(entry[0], entry[1])

## Anillo alrededor del player, pero reintentando si cae en agua o
## fuera del mapa — antes tiraba el dado una sola vez y podía
## spawnear un monstruo en el lago o más allá del borde.
func _pick_spawn_position() -> Vector2:
	for i in range(20):
		var ang := randf() * TAU
		var r := SPAWN_INNER + randf() * (SPAWN_OUTER - SPAWN_INNER)
		var pos := _player.position + Vector2(cos(ang) * r, sin(ang) * r)
		if _world.is_spawnable_at(pos):
			return pos
	# 20 intentos fallidos es rarísimo (el lago es chico) — mejor
	# spawnear algo cerca del player que trabarnos sin spawnear nada.
	return _player.position + Vector2(SPAWN_INNER, 0)

## Dificultad por oleada: los monstruos tienen más vida y pegan más
## fuerte a medida que avanza la run (además de ser más y más rápidos).
const WAVE_HP_STEP := 0.07      # oleada 20 ≈ x2.3 de vida
const WAVE_POWER_STEP := 0.04   # oleada 20 ≈ x1.76 de daño
## Desafío (oleadas 21-30): cada oleada suma bastante más.
const CHALLENGE_HP_STEP := 0.25     # oleada 30 ≈ x4.8 de vida
const CHALLENGE_POWER_STEP := 0.08  # oleada 30 ≈ x2.6 de daño
## Vida base de los jefes por tier (x la escala de la oleada) — tienen
## que aguantar lo suficiente como para ser una pelea, no un trámite.
const BOSS_BASE_HP := 900.0

## Mapa y dificultad elegidos (map_select): el mapa trae sus propios
## bichos y jefes, y ambos multiplican vida/daño y monedas.
var _map: Dictionary = GameState.map_data()
var _difficulty: Dictionary = GameState.difficulty_data()

func _stat_mult() -> float:
	return float(_map["mult"]) * float(_difficulty["mult"])

func _coin_mult() -> float:
	return float(_map["mult"]) * float(_difficulty["coins"])

func _wave_hp_mult() -> float:
	var extra: float = maxi(0, _current_wave - FINAL_WAVE) * CHALLENGE_HP_STEP
	return (1.0 + (_current_wave - 1) * WAVE_HP_STEP + extra) * _stat_mult()

func _wave_power_mult() -> float:
	var extra: float = maxi(0, _current_wave - FINAL_WAVE) * CHALLENGE_POWER_STEP
	return (1.0 + (_current_wave - 1) * WAVE_POWER_STEP + extra) * _stat_mult()

func _spawn_monster(is_boss: bool, is_elite: bool = false) -> void:
	var m = MONSTER_SCENE.instantiate()
	m.position = _pick_spawn_position()
	_monsters_container.add_child(m)
	# set_kind necesita @onready resuelto — sólo funciona DESPUÉS de
	# add_child (mismo motivo por el que antes set_sprite iba después).
	m.power_mult = _wave_power_mult()
	if is_boss:
		# 1er jefe (oleada 10) y jefe final (oleada 20) según el mapa.
		var bosses: Array = _map["bosses"]
		var tier: int = mini(_bosses_spawned, bosses.size() - 1)
		m.set_kind(bosses[tier])
		m.max_hp = BOSS_BASE_HP * (1 + mini(_bosses_spawned, 2)) * _wave_hp_mult()
		m.hp = m.max_hp
		m.coin_reward = 25 + tier * 15
		_bosses_spawned += 1
	else:
		# Pool de spawn depende de la wave — waves altas traen bichos
		# más grandes/duros (tier 2 y 3 sólo aparecen tarde).
		var pools: Array = _map["pools"]
		var pool: Array
		if _current_wave >= WAVE_HIGH_START:
			pool = pools[2]
		elif _current_wave >= WAVE_MID_START:
			pool = pools[1]
		else:
			pool = pools[0]
		m.set_kind(pool[randi() % pool.size()])
		m.max_hp *= _wave_hp_mult()
		m.hp = m.max_hp
		if is_elite:
			m.make_elite()
	m.coin_reward = maxi(1, int(round(m.coin_reward * _coin_mult())))
	m.speed_mult = min(1.0 + (_current_wave - 1) * WAVE_SPEED_STEP, WAVE_SPEED_CAP)
	if GameState.daily_modifier() == "veloces":
		m.speed_mult *= 1.3
	# El monster persigue al player desde el momento del spawn,
	# sin necesidad de estar en el radio de detección.
	m.target = _player
	m.hit_player.connect(_on_monster_hit_player)
	m.died.connect(_on_monster_died)
	if is_boss:
		_hud.show_boss_bar(m.max_hp)
		m.hp_changed.connect(_hud.on_boss_hp_changed)
		m.died.connect(_hud.hide_boss_bar)
		m.died.connect(_player.shake.bind(8.0))

## Crías que aparecen a mitad de oleada (slimes partidos, ratas que
## invoca un jefe): cuentan para cerrar la oleada. Lo llama monster.gd.
func register_monster(m) -> void:
	_monsters_alive += 1
	m.target = _player
	m.hit_player.connect(_on_monster_hit_player)
	m.died.connect(_on_monster_died)
	_update_wave_hud()

func _on_monster_hit_player(damage: float) -> void:
	_player.take_damage(damage)

func _update_wave_hud() -> void:
	_hud.set_wave(_current_wave, _monsters_alive, _final_wave)

func _on_monster_died() -> void:
	_monsters_alive = max(0, _monsters_alive - 1)
	_update_wave_hud()
	if _monsters_alive == 0 and not _in_break and not _run_over:
		_in_break = true
		if _current_wave == _final_wave:
			_finish_run(true)
			return
		Audio.play_sfx("wave_clear")
		# Volver a track normal si veníamos de un boss (wave % 10 == 0)
		if _current_wave % 10 == 0:
			var next_track := "gameplay_intense" if _current_wave >= 5 else "gameplay_chill"
			Audio.play_music(next_track, 1200)
		_hud.show_wave_break(WAVE_BREAK_SEC)
		get_tree().create_timer(WAVE_BREAK_SEC).timeout.connect(_start_next_wave)

func _on_player_leveled_up(_new_level: int) -> void:
	# Durante la muerte (o ya terminada la partida) no se sube de nivel:
	# el pollo y las orbas que quedaban podían abrir el menú encima.
	if _run_over:
		return
	# El swordman evoluciona de sprite con el nivel — el retrato lo sigue.
	_hud.set_portrait(_player.portrait_texture())
	# Instanciamos el modal, que se auto-pause y auto-destruye al elegir.
	var menu = LEVEL_UP_MENU_SCENE.instantiate()
	add_child(menu)
	menu.show_for(_player)

func _on_player_died() -> void:
	_player.play_death()
	_play_death_screen()
	_finish_run(false)

func _play_death_screen() -> void:
	Engine.time_scale = DEATH_SLOWMO
	Audio.stop_music(900)
	var layer := CanvasLayer.new()
	layer.layer = 15   # sobre HUD, level-up y pausa; bajo los resultados (20)
	add_child(layer)
	var dark := ColorRect.new()
	dark.color = Color(0.06, 0.0, 0.0, 0.0)
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dark)
	# Centrado en el 60 % de arriba: el héroe queda en el centro de la
	# pantalla y el texto no tiene que taparlo cayendo.
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.anchor_bottom = 0.6
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	_death_label = Label.new()
	_death_label.text = "MORISTE"
	RpgTheme.style_light_label(_death_label, 72)
	_death_label.add_theme_color_override("font_color", Color("ff5a48"))
	_death_label.add_theme_color_override("font_outline_color", Color("240807"))
	_death_label.add_theme_constant_override("outline_size", 14)
	_death_label.modulate.a = 0.0
	center.add_child(_death_label)
	_death_label.pivot_offset = _death_label.get_combined_minimum_size() / 2.0
	_death_label.scale = Vector2(1.6, 1.6)
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(dark, "color:a", 0.72, 0.9)
	tw.parallel().tween_property(_death_label, "modulate:a", 1.0, 0.45).set_delay(0.35)
	tw.parallel().tween_property(_death_label, "scale", Vector2.ONE, 0.45).set_delay(0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): Engine.time_scale = 1.0).set_delay(0.3)

func _exit_tree() -> void:
	# Por si se sale de la escena en plena cámara lenta.
	Engine.time_scale = 1.0

## Fin de la partida — por victoria (limpiar FINAL_WAVE) o por muerte.
## Banca la moneda, guarda récords y muestra la pantalla de resultados.
func _finish_run(victory: bool) -> void:
	if _run_over:
		return
	_run_over = true
	_hud.stop_timer()
	# La moneda ganada esta run recién queda gastable en la tienda
	# cuando la run termina — ver GameState.bank_run_currency().
	GameState.bank_run_currency()
	# Récord de oleada alcanzada y tiempo sobrevivido — independientes
	# entre sí (ver GameState.report_run_result).
	GameState.report_run_result(_current_wave, _hud.get_run_time())
	# El reto diario (10 oleadas) no cuenta como victoria del mapa para
	# los logros — sería un atajo para abrir mapas y dificultades.
	_new_legend = ""
	if victory and _challenge:
		_new_legend = GameState.report_challenge_win(GameState.selected_map)
	elif victory and not GameState.daily_active:
		GameState.report_win(GameState.selected_character_id, GameState.selected_map, GameState.selected_difficulty)
	if victory:
		Audio.play_music("gameplay_chill", 1200)
	# Ranking diario + analítica de partidas (tabla runs en Supabase).
	var score := GameState.submit_run(_current_wave, _hud.get_run_time(), victory, {
		"weapons": _player.weapon_levels, "passives": _player.passive_levels,
		"evolutions": _player.evolutions, "cards": _player.upgrade_log.size(),
		"level": _player.level,
	})
	# Pequeño delay para que se vea el golpe final; al morir, lo que dura
	# la pantalla MORISTE (en tiempo real: el juego va en cámara lenta).
	get_tree().create_timer(1.0 if victory else DEATH_SCREEN_SEC, true, false, true) \
		.timeout.connect(_show_results.bind(victory, score))

## Legendaria que se abrió al superar la oleada 30 (para los resultados).
var _new_legend: String = ""

func _show_results(victory: bool, score: int) -> void:
	Engine.time_scale = 1.0
	if _death_label != null:
		_death_label.visible = false
	var results = RESULTS_SCENE.instantiate()
	add_child(results)
	var hero: String = GameState.pending_character.get("name", GameState.CHARACTER_NAMES.get(GameState.selected_character_id, "El héroe"))
	results.show_results(victory, _current_wave, _hud.get_run_time(), hero,
		victory and not _challenge and not GameState.daily_active, score if GameState.daily_active else -1)
	if _new_legend != "":
		var skill: Dictionary = GameState.SKILL_TREE[_new_legend]
		results.add_highlight("¡HABILIDAD LEGENDARIA: %s! %s (ya tienes el nivel 1, mejórala en la tienda)" % [skill["name"].to_upper(), skill["desc"]])
	results.continue_pressed.connect(_on_continue_challenge)

## SEGUIR tras la victoria: el desafío de las oleadas 21-30.
func _on_continue_challenge() -> void:
	_challenge = true
	_final_wave = GameState.CHALLENGE_WAVE
	_run_over = false
	get_tree().paused = false
	_hud.resume_timer()
	_update_wave_hud()
	get_tree().create_timer(WAVE_BREAK_SEC).timeout.connect(_start_next_wave)
