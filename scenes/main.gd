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
const CharSelect := preload("res://scenes/character_select.gd")

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
# Densidad VS: mucho volumen. Con las oleadas por tiempo (30-09) la
# cantidad crece menos (antes +4 por oleada): el peligro lo ponen el
# daño y el nivel de los monstruos, no que se acumulen sin fin.
const BASE_MONSTERS := 8
const MONSTERS_PER_WAVE := 2
## Ritmo de la etapa (30-09): cada oleada dura WAVE_DURATION aunque
## queden monstruos vivos (siguen en la siguiente); si se limpia todo
## antes, pasa antes. Trae el triple de monstruos y los suelta de a poco
## en el primer SPAWN_WINDOW_FRAC de su tiempo; los que no alcanzaron a
## salir se descartan. Una etapa de 20 oleadas dura ~21 minutos. Lo que
## sube con cada oleada es el peligro: pegan más (WAVE_POWER_STEP) y
## salen monstruos de más nivel (_pick_kind). Las oleadas de jefe no
## terminan hasta que el jefe cae.
const WAVE_COUNT_MULT := 3.0
const WAVE_DURATION := 60.0
const SPAWN_WINDOW_FRAC := 0.85
## Reto diario: la partida corta del día, la mitad de todo.
const DAILY_PACE := 0.5
## Tope de monstruos vivos a la vez: si se juntan muchos, la cola espera.
const MAX_ALIVE := 140

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
## true si el retrato del HUD es la ilustración (no se rehace al subir).
var _illustrated_portrait: bool = false
var _monsters_alive: int = 0
## Reloj de la oleada en curso (false durante la pausa entre oleadas).
var _wave_running: bool = false
var _wave_time_left: float = 0.0
var _boss_alive: bool = false
## Cuenta cuántos bosses ya spawneó la run — para elegir demon1/2/3.
var _bosses_spawned: int = 0
## true después de ganar y elegir SEGUIR: el desafío de las oleadas
## 21-30 (mucho más duro). Superarlo abre la legendaria del mapa.
var _challenge: bool = false
var _run_over: bool = false
var _death_label: Label
## FINAL_WAVE salvo en el reto diario (más corto).
var _final_wave: int = FINAL_WAVE
## Qué monstruos salen: cada mapa trae 3 grupos, de más débil a más
## duro. La oleada pasa de uno al siguiente de a poco, cada
## POOL_WAVES oleadas (en la 9 ya es todo del tercero), y desde la
## TIER_BIAS_START, dentro del grupo, los de nivel más alto salen cada
## vez más seguido: en la 20, ~70 % de nivel 3.
const POOL_WAVES := 4.0
const TIER_BIAS_START := 9
const TIER_BIAS_STEP := 0.2
const MonsterScript := preload("res://scenes/monster.gd")

func _ready() -> void:
	print("[main] booting…")
	GameState.start_run()
	# Reto diario: misma semilla para todos ese día (cartas y oleadas
	# arrancan igual), 10 oleadas y el modificador del día.
	if GameState.daily_active:
		seed(GameState.daily_info()["seed"])
		_final_wave = GameState.DAILY_WAVES
	# Desafío: sus oleadas y sus reglas (GameState.TRIALS).
	if GameState.trial_active != "":
		_final_wave = int(GameState.trial_data()["waves"])
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
	# El player ya avisó su vida en su _ready, antes de estas conexiones:
	# sin esto el HUD arrancaba en 100/100 aunque la tienda o el héroe
	# (EDRIC, SIRA) le cambien la vida máxima.
	_hud.on_hp_changed(_player.hp, _player.max_hp)
	_hud.on_defense_changed(_player.defense, _player.max_defense)
	if GameState.has_modifier("meteoros"):
		_player.apply_upgrade("meteors")
	if GameState.has_modifier("cristal"):
		_player.max_hp *= 0.5
		_player.hp = _player.max_hp
		_player.damage_mult *= 1.5
		_player.emit_signal("hp_changed", _player.hp, _player.max_hp)
	# Retrato del círculo: la ilustración del héroe centrada en la cara si
	# la tiene (GAROTH); si su retrato está pendiente, la cara del sprite.
	var hero: Dictionary = CharSelect.find_character(GameState.selected_character_id)
	if hero.has("face_rect") and not hero.get("portrait_pending", false):
		_hud.set_portrait_illustration(load(hero["portrait"]), hero["face_rect"])
		_illustrated_portrait = true
	else:
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
	var pace: float = DAILY_PACE if GameState.daily_active or GameState.trial_active != "" else 1.0
	# En el desafío los monstruos ya son mucho más duros (CHALLENGE_*_STEP):
	# ahí el doble en vez del triple.
	var count_mult: float = 2.0 if _challenge else WAVE_COUNT_MULT
	var count := int((BASE_MONSTERS + _current_wave * MONSTERS_PER_WAVE) * count_mult * pace)
	if GameState.has_modifier("horda"):
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
	if GameState.has_modifier("elites"):
		elite_count = 2
	if _challenge:
		elite_count = 2 if _current_wave < 25 else 3
	# Se encolan y salen repartidos en la ventana de la oleada (ver
	# _process). El jefe va primero y sale apenas empieza; los élites,
	# repartidos entre los demás.
	var entries: Array = []
	for i in range(count):
		entries.append([false, i < elite_count])
	entries.shuffle()
	for i in range(boss_count):
		entries.push_front([true, false])
	_spawn_queue.append_array(entries)
	var window: float = WAVE_DURATION * pace * SPAWN_WINDOW_FRAC
	_spawn_interval = window / maxf(1.0, float(count))
	_wave_time_left = WAVE_DURATION * pace
	_boss_alive = boss_count > 0
	_wave_running = true
	_spawn_accum = _spawn_interval * 4.0   # unos pocos de entrada
	# += y no =: si quedara alguna cría suelta de la oleada anterior,
	# no se pierde de la cuenta. Cuenta también los que están en cola.
	_monsters_alive += count + boss_count
	_update_wave_hud()

## Monstruos de la oleada que todavía no aparecieron: [es_jefe, es_élite].
## Salen de a uno cada _spawn_interval segundos (y como mucho de a 3
## por frame: crearlos todos juntos trababa el juego).
var _spawn_queue: Array = []
var _spawn_interval: float = 0.0
var _spawn_accum: float = 0.0
const SPAWNS_PER_FRAME := 3

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if _run_over:
		_spawn_queue.clear()
		return
	_tick_wave(delta)
	if _spawn_queue.is_empty():
		return
	# Si está en el tope de vivos no se acumula de más (saldrían de golpe).
	_spawn_accum = minf(_spawn_accum + delta, _spawn_interval * 6.0 + delta)
	var released := 0
	while not _spawn_queue.is_empty() and released < SPAWNS_PER_FRAME:
		var entry: Array = _spawn_queue[0]
		if not entry[0]:   # el jefe no espera turno
			if _spawn_accum < _spawn_interval:
				break
			if get_tree().get_nodes_in_group("monster").size() >= MAX_ALIVE:
				break
			_spawn_accum -= _spawn_interval
		_spawn_queue.pop_front()
		_spawn_monster(entry[0], entry[1])
		released += 1

## Reloj de la oleada: al terminar su tiempo pasa a la siguiente aunque
## queden monstruos vivos, salvo que el jefe siga en pie. Si no queda
## nada vivo ni por salir, pasa antes.
func _tick_wave(delta: float) -> void:
	if not _wave_running:
		return
	_wave_time_left = maxf(0.0, _wave_time_left - delta)
	_hud.set_wave_time(_wave_time_left, _boss_alive)
	if _monsters_alive == 0 or (_wave_time_left <= 0.0 and not _boss_alive):
		_end_wave()

func _end_wave() -> void:
	_wave_running = false
	if _current_wave == _final_wave:
		_finish_run(true)
		return
	# Los que no alcanzaron a salir se descartan (el jefe sale primero).
	_monsters_alive = maxi(0, _monsters_alive - _spawn_queue.size())
	_spawn_queue.clear()
	_update_wave_hud()
	Audio.play_sfx("wave_clear")
	# Volver a track normal si veníamos de un boss (wave % 10 == 0)
	if _current_wave % 10 == 0:
		var next_track := "gameplay_intense" if _current_wave >= 5 else "gameplay_chill"
		Audio.play_music(next_track, 1200)
	_hud.show_wave_break(WAVE_BREAK_SEC)
	get_tree().create_timer(WAVE_BREAK_SEC).timeout.connect(_start_next_wave)

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
const WAVE_HP_STEP := 0.08      # oleada 20 ≈ x2.5 de vida
## Vida base de todos los monstruos comunes (no jefes): x1,1 desde el
## 29-09, cuando la espada pasó a 9 y las armas a distancia bajaron de
## daño y de alcance (ya no limpian el mapa entero).
const MONSTER_HP_MULT := 1.1
const WAVE_POWER_STEP := 0.06   # oleada 20 ≈ x2.1 de daño
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
		var kind_id: String = _pick_kind()
		m.set_kind(kind_id)
		m.ground_fire_attacks = GameState.selected_map == "desierto" \
			and (kind_id.begins_with("imp") or kind_id.begins_with("beholder"))
		m.max_hp *= _wave_hp_mult() * MONSTER_HP_MULT
		m.hp = m.max_hp
		if is_elite:
			m.make_elite()
	m.coin_reward = maxi(1, int(round(m.coin_reward * _coin_mult())))
	m.speed_mult = min(1.0 + (_current_wave - 1) * WAVE_SPEED_STEP, WAVE_SPEED_CAP)
	if GameState.has_modifier("veloces"):
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
		m.died.connect(func(): _boss_alive = false)

## Monstruo común de esta oleada (ver POOL_WAVES y TIER_BIAS_START).
func _pick_kind() -> String:
	var pools: Array = _map["pools"]
	var pos: float = clampf((_current_wave - 1) / POOL_WAVES, 0.0, pools.size() - 1.0)
	var i: int = int(pos)
	if i < pools.size() - 1 and randf() < pos - i:
		i += 1
	var pool: Array = pools[i]
	var bias: float = maxf(0.0, (_current_wave - TIER_BIAS_START) * TIER_BIAS_STEP)
	if bias <= 0.0:
		return pool[randi() % pool.size()]
	# Peso = nivel ^ bias: con bias 2, un nivel 3 sale 9 veces más que un 1.
	var weights: Array = []
	var total := 0.0
	for k in pool:
		var w: float = pow(float(MonsterScript.KIND_DATA[k].get("tier", 1)), bias)
		weights.append(w)
		total += w
	var r := randf() * total
	for j in range(pool.size()):
		r -= weights[j]
		if r <= 0.0:
			return pool[j]
	return pool[pool.size() - 1]

## Crías que aparecen a mitad de oleada (slimes partidos, ratas que
## invoca un jefe): cuentan para cerrar la oleada. Lo llama monster.gd.
func register_monster(m) -> void:
	_monsters_alive += 1
	m.target = _player
	m.hit_player.connect(_on_monster_hit_player)
	m.died.connect(_on_monster_died)
	_update_wave_hud()

func _on_monster_hit_player(damage: float) -> void:
	# Tras ganar pueden quedar monstruos vivos (las oleadas terminan por
	# tiempo): ya no pegan.
	if _run_over:
		return
	_player.take_damage(damage)

func _update_wave_hud() -> void:
	_hud.set_wave(_current_wave, _final_wave)

func _on_monster_died() -> void:
	_monsters_alive = max(0, _monsters_alive - 1)
	_player.on_monster_killed()
	_update_wave_hud()

func _on_player_leveled_up(_new_level: int) -> void:
	# Durante la muerte (o ya terminada la partida) no se sube de nivel:
	# el pollo y las orbas que quedaban podían abrir el menú encima.
	if _run_over:
		return
	# El swordman evoluciona de sprite con el nivel — el retrato lo sigue
	# (salvo que sea la ilustración, que no cambia).
	if not _illustrated_portrait:
		_hud.set_portrait(_player.portrait_texture())
	# Instanciamos el modal, que se auto-pause y auto-destruye al elegir.
	var menu = LEVEL_UP_MENU_SCENE.instantiate()
	add_child(menu)
	menu.show_for(_player)

func _on_player_died() -> void:
	if _run_over:
		return
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
	_trial_reward = {}
	if victory and _challenge:
		_new_legend = GameState.report_challenge_win(GameState.selected_map)
	elif victory and GameState.trial_active != "":
		_trial_reward = GameState.report_trial_win(GameState.trial_active)
	elif victory and not GameState.daily_active:
		GameState.report_win(GameState.selected_character_id, GameState.selected_map, GameState.selected_difficulty)
	if victory:
		Audio.play_music("gameplay_chill", 1200)
	# Ranking diario + analítica de partidas (tabla runs en Supabase).
	var score := GameState.submit_run(_current_wave, _hud.get_run_time(), victory, {
		"weapons": _player.weapon_levels, "passives": _player.passive_levels,
		"evolutions": _player.evolutions, "cards": _player.upgrade_log.size(),
		"level": _player.level,
	}, _player.hp / _player.max_hp if victory else 0.0)
	# Pequeño delay para que se vea el golpe final; al morir, lo que dura
	# la pantalla MORISTE (en tiempo real: el juego va en cámara lenta).
	get_tree().create_timer(1.0 if victory else DEATH_SCREEN_SEC, true, false, true) \
		.timeout.connect(_show_results.bind(victory, score))

## Legendaria que se abrió al superar la oleada 30 (para los resultados).
var _new_legend: String = ""
## Premio del desafío ganado por primera vez (para los resultados).
var _trial_reward: Dictionary = {}

func _show_results(victory: bool, score: int) -> void:
	Engine.time_scale = 1.0
	if _death_label != null:
		_death_label.visible = false
	var results = RESULTS_SCENE.instantiate()
	add_child(results)
	var hero: String = GameState.pending_character.get("name", GameState.CHARACTER_NAMES.get(GameState.selected_character_id, "El héroe"))
	var special_run: bool = GameState.daily_active or GameState.trial_active != ""
	results.show_results(victory, _current_wave, _hud.get_run_time(), hero,
		victory and not _challenge and not special_run, score if GameState.daily_active else -1)
	if not _trial_reward.is_empty():
		results.add_highlight("¡DESAFÍO SUPERADO! " + GameState.reward_text(_trial_reward))
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
