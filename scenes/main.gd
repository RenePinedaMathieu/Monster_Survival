extends Node2D

## Main del juego. Se encarga de:
##   - Auth anónima en Supabase + WebSocket a Realtime
##   - Multiplayer: spawn/despawn/move de remote players
##   - Oleadas de monstruos: wave N tiene 3 + N*2 bichos; cuando
##     matás todos, break de 3s y viene la próxima
##   - Wire del daño monster→player y muerte del player
##
## En multiplayer cada cliente maneja SUS PROPIAS oleadas
## (no hay servidor autoritativo). Los otros players que ves
## están para company/coop cosmético; no comparten enemigos.

const REMOTE_PLAYER_SCENE := preload("res://scenes/remote_player.tscn")
const MONSTER_SCENE := preload("res://scenes/monster.tscn")
const LEVEL_UP_MENU_SCENE := preload("res://scenes/level_up_menu.tscn")
const TOUCH_CONTROLS_SCENE := preload("res://scenes/touch_controls.tscn")
const PAUSE_MENU_SCENE := preload("res://scenes/pause_menu.tscn")

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

@onready var _remote_players_container: Node2D = $RemotePlayers
@onready var _monsters_container: Node2D = $Monsters
@onready var _player: CharacterBody2D = $Player
@onready var _hud: CanvasLayer = $HUD
@onready var _world = $World

var _remote_players: Dictionary = {}
var _current_wave: int = 0
var _monsters_alive: int = 0
var _in_break: bool = false
## Cuenta cuántos bosses ya spawneó la run — para elegir demon1/2/3.
var _bosses_spawned: int = 0
## Umbrales de dificultad. Debajo de MID sólo tier 1 (crías). Entre
## MID y HIGH mix de tier 1 y 2. En HIGH sólo tier 2 y 3 (los más
## amenazantes). Se siente la escalada de la run sin necesidad de
## tocar nada más.
const WAVE_MID_START := 4
const WAVE_HIGH_START := 7

func _ready() -> void:
	print("[main] booting…")
	Supabase.auth_ready.connect(_on_auth_ready)
	Realtime.remote_join.connect(_on_remote_join)
	Realtime.remote_leave.connect(_on_remote_leave)
	Realtime.remote_move.connect(_on_remote_move)
	Supabase.sign_in_anonymous("player_" + str(randi() % 9999))
	_player.hp_changed.connect(_hud.on_hp_changed)
	_player.defense_changed.connect(_hud.on_defense_changed)
	_player.xp_changed.connect(_hud.on_xp_changed)
	_player.leveled_up.connect(_on_player_leveled_up)
	_player.died.connect(_on_player_died)
	_hud.set_wave(0, 0)
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
	if event.is_action_pressed("ui_cancel") and not get_tree().paused:
		var pause_menu = PAUSE_MENU_SCENE.instantiate()
		add_child(pause_menu)
		pause_menu.setup(_player)
		get_tree().paused = true
		get_viewport().set_input_as_handled()

# ── Multiplayer ──────────────────────────────────────────────────

func _on_auth_ready() -> void:
	print("[main] auth ok, uid=", Supabase.user_id)

func _on_remote_join(uid: String, meta: Dictionary) -> void:
	if _remote_players.has(uid): return
	var rp = REMOTE_PLAYER_SCENE.instantiate()
	_remote_players_container.add_child(rp)
	rp.setup(uid, meta)
	_remote_players[uid] = rp

func _on_remote_leave(uid: String) -> void:
	if not _remote_players.has(uid): return
	_remote_players[uid].queue_free()
	_remote_players.erase(uid)

func _on_remote_move(uid: String, x: float, y: float, facing: int, dir: int) -> void:
	if not _remote_players.has(uid):
		_on_remote_join(uid, {})
	_remote_players[uid].apply_move(x, y, facing, dir)

# ── Waves ────────────────────────────────────────────────────────

func _start_next_wave() -> void:
	_current_wave += 1
	_in_break = false
	var count := BASE_MONSTERS + _current_wave * MONSTERS_PER_WAVE
	# Cada 10 waves aparece 1 boss extra, bastante más grande y duro
	# que el resto (ver KIND_DATA["golem"] en monster.gd).
	var boss_count: int = 1 if _current_wave % 10 == 0 else 0
	print("[main] wave %d — %d monsters + %d bosses" % [_current_wave, count, boss_count])
	Audio.play_sfx("wave_start")
	# En wave con boss, cambiamos a música de boss (cross-fade)
	if boss_count > 0:
		Audio.play_music("boss", 800)
		Audio.play_sfx("boss_spawn")
	# Cuando la intensidad sube (wave 5+), pasamos a track más agresivo
	elif _current_wave == 5:
		Audio.play_music("gameplay_intense", 1500)
	for i in range(count):
		_spawn_monster(false)
	for i in range(boss_count):
		_spawn_monster(true)
	_monsters_alive = count + boss_count
	_hud.set_wave(_current_wave, _monsters_alive)

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

func _spawn_monster(is_boss: bool) -> void:
	var m = MONSTER_SCENE.instantiate()
	m.position = _pick_spawn_position()
	if is_boss:
		# HP y coin_reward escalan por tier de boss para que cada
		# encuentro se sienta progresivamente más importante.
		var tier: int = min(_bosses_spawned, m.BOSS_KIND_IDS.size() - 1)
		m.max_hp = 80.0 + tier * 40.0
		m.coin_reward = 25 + tier * 15
	_monsters_container.add_child(m)
	# set_kind necesita @onready resuelto — sólo funciona DESPUÉS de
	# add_child (mismo motivo por el que antes set_sprite iba después).
	if is_boss:
		# Boss tier per encounter: 1er boss → demon1, 2do → demon2, 3ro+ → demon3
		var tier: int = min(_bosses_spawned, m.BOSS_KIND_IDS.size() - 1)
		m.set_kind(m.BOSS_KIND_IDS[tier])
		_bosses_spawned += 1
	else:
		# Pool de spawn depende de la wave — waves altas traen bichos
		# más grandes/duros (tier 2 y 3 sólo aparecen tarde).
		var pool: Array
		if _current_wave >= WAVE_HIGH_START:
			pool = m.KIND_IDS_HIGH
		elif _current_wave >= WAVE_MID_START:
			pool = m.KIND_IDS_MID
		else:
			pool = m.KIND_IDS
		m.set_kind(pool[randi() % pool.size()])
	m.speed_mult = min(1.0 + (_current_wave - 1) * WAVE_SPEED_STEP, WAVE_SPEED_CAP)
	# El monster persigue AL PLAYER LOCAL desde el momento del spawn,
	# sin necesidad de estar en el radio de detección. Los remote
	# players quedan fuera del scope (cada cliente maneja los suyos).
	m.target = _player
	m.hit_player.connect(_on_monster_hit_player)
	m.died.connect(_on_monster_died)
	if is_boss:
		_hud.show_boss_bar(m.max_hp)
		m.hp_changed.connect(_hud.on_boss_hp_changed)
		m.died.connect(_hud.hide_boss_bar)

func _on_monster_hit_player(damage: float) -> void:
	_player.take_damage(damage)

func _on_monster_died() -> void:
	_monsters_alive = max(0, _monsters_alive - 1)
	_hud.set_wave(_current_wave, _monsters_alive)
	if _monsters_alive == 0 and not _in_break:
		_in_break = true
		Audio.play_sfx("wave_clear")
		# Volver a track normal si veníamos de un boss (wave % 10 == 0)
		if _current_wave % 10 == 0:
			var next_track := "gameplay_intense" if _current_wave >= 5 else "gameplay_chill"
			Audio.play_music(next_track, 1200)
		_hud.show_wave_break(WAVE_BREAK_SEC)
		get_tree().create_timer(WAVE_BREAK_SEC).timeout.connect(_start_next_wave)

func _on_player_leveled_up(_new_level: int) -> void:
	# Instanciamos el modal, que se auto-pause y auto-destruye al elegir.
	var menu = LEVEL_UP_MENU_SCENE.instantiate()
	add_child(menu)
	menu.show_for(_player)

func _on_player_died() -> void:
	_hud.stop_timer()
	# La moneda ganada esta run recién queda gastable en la tienda
	# cuando la run termina — ver GameState.bank_run_currency().
	GameState.bank_run_currency()
	# Récord de oleada alcanzada y tiempo sobrevivido — independientes
	# entre sí (ver GameState.report_run_result).
	GameState.report_run_result(_current_wave, _hud.get_run_time())
	# Pequeño delay para que el player vea que murió
	get_tree().create_timer(1.2).timeout.connect(func(): get_tree().reload_current_scene())
