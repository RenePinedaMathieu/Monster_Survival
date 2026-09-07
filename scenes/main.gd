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

const MONSTER_TEXTURES: Array[String] = [
	"res://assets/sprites/monsters/pipo-enemy001.png",
	"res://assets/sprites/monsters/pipo-enemy004.png",
	"res://assets/sprites/monsters/pipo-enemy008.png",
	"res://assets/sprites/monsters/pipo-enemy015.png",
	"res://assets/sprites/monsters/pipo-enemy023.png",
]
const BOSS_TEXTURE := "res://assets/sprites/monsters/pipo-boss001.png"

const SPAWN_INNER := 500.0
const SPAWN_OUTER := 800.0
const WAVE_BREAK_SEC := 3.0
const BASE_MONSTERS := 3
const MONSTERS_PER_WAVE := 2

@onready var _remote_players_container: Node2D = $RemotePlayers
@onready var _monsters_container: Node2D = $Monsters
@onready var _player: CharacterBody2D = $Player
@onready var _hud: CanvasLayer = $HUD

var _remote_players: Dictionary = {}
var _current_wave: int = 0
var _monsters_alive: int = 0
var _in_break: bool = false

func _ready() -> void:
	print("[main] booting…")
	Supabase.auth_ready.connect(_on_auth_ready)
	Realtime.remote_join.connect(_on_remote_join)
	Realtime.remote_leave.connect(_on_remote_leave)
	Realtime.remote_move.connect(_on_remote_move)
	Supabase.sign_in_anonymous("player_" + str(randi() % 9999))
	_player.hp_changed.connect(_hud.on_hp_changed)
	_player.died.connect(_on_player_died)
	_hud.set_wave(0, 0)
	# Primer wave con un delay corto para que veas el mundo un
	# segundo antes de que caiga la fiesta
	get_tree().create_timer(1.5).timeout.connect(_start_next_wave)

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
	# Cada 5 waves aparece 1 boss extra
	var boss_count := 1 if _current_wave % 5 == 0 else 0
	print("[main] wave %d — %d monsters + %d bosses" % [_current_wave, count, boss_count])
	for i in range(count):
		_spawn_monster(false)
	for i in range(boss_count):
		_spawn_monster(true)
	_monsters_alive = count + boss_count
	_hud.set_wave(_current_wave, _monsters_alive)

func _spawn_monster(is_boss: bool) -> void:
	var m = MONSTER_SCENE.instantiate()
	# Spawn en un anillo alrededor del player
	var ang := randf() * TAU
	var r := SPAWN_INNER + randf() * (SPAWN_OUTER - SPAWN_INNER)
	m.position = _player.position + Vector2(cos(ang) * r, sin(ang) * r)
	# Textura al azar (o boss)
	var tex_path: String
	if is_boss:
		tex_path = BOSS_TEXTURE
		m.max_hp = 20.0
		m.scale = Vector2(1.8, 1.8)
	else:
		tex_path = MONSTER_TEXTURES[randi() % MONSTER_TEXTURES.size()]
	_monsters_container.add_child(m)
	m.set_sprite(load(tex_path))
	# El monster persigue AL PLAYER LOCAL desde el momento del spawn,
	# sin necesidad de estar en el radio de detección. Los remote
	# players quedan fuera del scope (cada cliente maneja los suyos).
	m.target = _player
	m.hit_player.connect(_on_monster_hit_player)
	m.died.connect(_on_monster_died)

func _on_monster_hit_player(damage: float) -> void:
	_player.take_damage(damage)

func _on_monster_died() -> void:
	_monsters_alive = max(0, _monsters_alive - 1)
	_hud.set_wave(_current_wave, _monsters_alive)
	if _monsters_alive == 0 and not _in_break:
		_in_break = true
		_hud.show_wave_break(WAVE_BREAK_SEC)
		get_tree().create_timer(WAVE_BREAK_SEC).timeout.connect(_start_next_wave)

func _on_player_died() -> void:
	get_tree().reload_current_scene()
