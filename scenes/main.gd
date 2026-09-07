extends Node2D

## Escena principal del juego.
##   1. Loguea anónimo en Supabase al arrancar
##   2. Escucha signals de Realtime → spawn/despawn de remote players
##   3. Spawnea unos cuantos monstruos en el mundo
##   4. Conecta el daño del monster con el HP del player + HUD

const REMOTE_PLAYER_SCENE := preload("res://scenes/remote_player.tscn")
const MONSTER_SCENE := preload("res://scenes/monster.tscn")

# Los archivos de sprites que copiamos del Pipoya pack. Cada uno
# es un monster distinto; el spawner elige al azar.
const MONSTER_TEXTURES: Array[String] = [
	"res://assets/sprites/monsters/pipo-enemy001.png",
	"res://assets/sprites/monsters/pipo-enemy004.png",
	"res://assets/sprites/monsters/pipo-enemy008.png",
	"res://assets/sprites/monsters/pipo-enemy015.png",
	"res://assets/sprites/monsters/pipo-enemy023.png",
	"res://assets/sprites/monsters/pipo-boss001.png",
]

const MONSTER_COUNT := 6
const SPAWN_RADIUS := 400.0

@onready var _remote_players_container: Node2D = $RemotePlayers
@onready var _monsters_container: Node2D = $Monsters
@onready var _player: CharacterBody2D = $Player
@onready var _hud: CanvasLayer = $HUD

var _remote_players: Dictionary = {}

func _ready() -> void:
	print("[main] booting…")
	# Auth + realtime
	Supabase.auth_ready.connect(_on_auth_ready)
	Realtime.remote_join.connect(_on_remote_join)
	Realtime.remote_leave.connect(_on_remote_leave)
	Realtime.remote_move.connect(_on_remote_move)
	Supabase.sign_in_anonymous("player_" + str(randi() % 9999))
	# HUD escucha el HP del player local
	_player.hp_changed.connect(_hud.on_hp_changed)
	_player.died.connect(_on_player_died)
	# Poblá el mundo
	_spawn_monsters()

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

# ── Monsters ────────────────────────────────────────────────────

func _spawn_monsters() -> void:
	for i in range(MONSTER_COUNT):
		var m = MONSTER_SCENE.instantiate()
		# Posición random en un anillo alrededor del player
		var ang := randf() * TAU
		var r := SPAWN_RADIUS * (0.6 + randf() * 0.4)
		m.position = _player.position + Vector2(cos(ang) * r, sin(ang) * r)
		# Sprite random
		var tex_path: String = MONSTER_TEXTURES[randi() % MONSTER_TEXTURES.size()]
		_monsters_container.add_child(m)
		m.set_sprite(load(tex_path))
		m.hit_player.connect(_on_monster_hit_player)

func _on_monster_hit_player(damage: float) -> void:
	_player.take_damage(damage)

func _on_player_died() -> void:
	# TODO: pantalla de game over / respawn. Por ahora reinicio la
	# escena así podés seguir probando.
	get_tree().reload_current_scene()
