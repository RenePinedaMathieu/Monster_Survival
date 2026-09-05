extends Control

func _ready() -> void:
	print("Booting…")
	Supabase.auth_ready.connect(_on_auth_ready)
	Realtime.remote_join.connect(_on_remote_join)
	Realtime.remote_move.connect(_on_remote_move)
	Realtime.remote_leave.connect(_on_remote_leave)
	Supabase.sign_in_anonymous("test_" + str(randi() % 999))

func _on_auth_ready() -> void:
	print("[main] connected as ", Supabase.user_id)

func _on_remote_join(uid: String, meta: Dictionary) -> void:
	print("[main] someone joined: ", uid, " meta=", meta)

func _on_remote_leave(uid: String) -> void:
	print("[main] someone left: ", uid)

func _on_remote_move(uid: String, x: float, y: float, facing: int, dir: int) -> void:
	print("[main] remote move: ", uid, " (", x, ",", y, ")")
