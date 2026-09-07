extends Node2D

## Escena principal del juego. Se encarga de:
##   1. Loguear anónimo en Supabase al arranque
##   2. Escuchar los signals de Realtime para joins/leaves/moves
##   3. Spawnear/destruir escenas de remote_player en el nodo
##      "RemotePlayers"
##
## Cuando querés agregar el mundo (tilemap, decoraciones, wolves,
## NPCs), lo hacés como hijos del nodo "World" para mantener orden.

const REMOTE_PLAYER_SCENE := preload("res://scenes/remote_player.tscn")

@onready var _remote_players_container: Node2D = $RemotePlayers

# Diccionario uid -> instancia de RemotePlayer
var _remote_players: Dictionary = {}

func _ready() -> void:
	print("[main] booting…")
	Supabase.auth_ready.connect(_on_auth_ready)
	Realtime.remote_join.connect(_on_remote_join)
	Realtime.remote_leave.connect(_on_remote_leave)
	Realtime.remote_move.connect(_on_remote_move)
	Supabase.sign_in_anonymous("player_" + str(randi() % 9999))

func _on_auth_ready() -> void:
	print("[main] auth ok, uid=", Supabase.user_id)

func _on_remote_join(uid: String, meta: Dictionary) -> void:
	if _remote_players.has(uid): return
	var rp = REMOTE_PLAYER_SCENE.instantiate()
	_remote_players_container.add_child(rp)
	rp.setup(uid, meta)
	_remote_players[uid] = rp
	print("[main] spawned remote player ", uid)

func _on_remote_leave(uid: String) -> void:
	if not _remote_players.has(uid): return
	_remote_players[uid].queue_free()
	_remote_players.erase(uid)
	print("[main] removed remote player ", uid)

func _on_remote_move(uid: String, x: float, y: float, facing: int, dir: int) -> void:
	# Si nunca recibimos el join (llegamos tarde al canal), auto-
	# spawneamos con un meta vacío. Así el juego se recupera solo.
	if not _remote_players.has(uid):
		_on_remote_join(uid, {})
	_remote_players[uid].apply_move(x, y, facing, dir)
