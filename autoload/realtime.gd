extends Node

## Supabase Realtime client — presence + broadcast over WebSocket.
## Add as Autoload in Project Settings with name "Realtime".
##
## LESSON from the previous React project: NEVER call track() at
## broadcast frequency (position updates). ACKs pile up and the
## channel dies at ~7Hz. Use track() ONCE for identity, and use
## send_broadcast() for anything sent every frame.
##
## Auto-connects when Supabase.auth_ready fires. Emits high-level
## signals for the game to consume; you never touch the raw WS.

const CHANNEL := "world"
const HEARTBEAT_MS := 25_000
const MOVE_THROTTLE_MS := 130

var _ws := WebSocketPeer.new()
var _ref := 0
var _joined := false
var _last_move := 0
var _last_heartbeat := 0
var _last_state := -1

## Emitted for each remote player broadcast.
signal remote_move(uid: String, x: float, y: float, facing: int, dir: int)
signal remote_attack(uid: String, facing: int, dir: int)
signal remote_lobby(uid: String, ready: bool, gender: String)
signal remote_join(uid: String, meta: Dictionary)
signal remote_leave(uid: String)

func _ready() -> void:
	Supabase.auth_ready.connect(_connect)
	set_process(false)

func _connect() -> void:
	var url = Supabase.URL.replace("https://", "wss://") \
		+ "/realtime/v1/websocket?apikey=" + Supabase.ANON_KEY + "&vsn=1.0.0"
	var err = _ws.connect_to_url(url)
	if err != OK:
		push_error("Realtime WS connect error: " + str(err))
		return
	set_process(true)

func _process(_dt: float) -> void:
	_ws.poll()
	var state = _ws.get_ready_state()
	if state != _last_state:
		print("[rt] state changed: ", state)
		_last_state = state
	if state == WebSocketPeer.STATE_OPEN:
		if not _joined:
			print("[rt] joining channel world")
			_join_channel()
			_joined = true
		var now = Time.get_ticks_msec()
		if now - _last_heartbeat > HEARTBEAT_MS:
			_send_heartbeat()
			_last_heartbeat = now
		while _ws.get_available_packet_count() > 0:
			_handle(_ws.get_packet().get_string_from_utf8())
	elif state == WebSocketPeer.STATE_CLOSED:
		set_process(false)
		_joined = false
		push_warning("[realtime] socket closed")

## Send position for the local player. Throttled to MOVE_THROTTLE_MS
## because Supabase drops broadcasts sent faster than ~10Hz.
func send_move(x: float, y: float, facing: int, dir: int) -> void:
	var now = Time.get_ticks_msec()
	if now - _last_move < MOVE_THROTTLE_MS: return
	_last_move = now
	_send_broadcast("move", {
		"uid": Supabase.user_id,
		"x": x, "y": y,
		"facing": facing, "dir": dir,
	})

func send_attack(facing: int, dir: int) -> void:
	_send_broadcast("attack", {
		"uid": Supabase.user_id,
		"facing": facing, "dir": dir,
	})

func send_lobby(ready: bool, gender: String) -> void:
	_send_broadcast("lobby", {
		"uid": Supabase.user_id,
		"ready": ready,
		"gender": gender,
	})

# ── internals ─────────────────────────────────────────────────────

func _join_channel() -> void:
	_send({
		"topic": "realtime:" + CHANNEL,
		"event": "phx_join",
		"payload": {
			"config": {
				"presence": { "key": Supabase.user_id },
				"broadcast": { "self": false, "ack": false },
			},
			"access_token": Supabase.access_token,
		},
	})
	# Identity: tracked once. Update again ONLY when name/outfit
	# changes — NEVER on every frame.
	_send({
		"topic": "realtime:" + CHANNEL,
		"event": "presence",
		"payload": {
			"type": "presence",
			"event": "track",
			"payload": { "name": Supabase.username },
		},
	})

func _send_broadcast(event_name: String, payload: Dictionary) -> void:
	_send({
		"topic": "realtime:" + CHANNEL,
		"event": "broadcast",
		"payload": {
			"type": "broadcast",
			"event": event_name,
			"payload": payload,
		},
	})

func _send_heartbeat() -> void:
	_send({ "topic": "phoenix", "event": "heartbeat", "payload": {} })

func _send(msg: Dictionary) -> void:
	_ref += 1
	msg["ref"] = str(_ref)
	_ws.send_text(JSON.stringify(msg))

func _handle(raw: String) -> void:
	print("[rt] << ", raw)
	var msg = JSON.parse_string(raw)
	if typeof(msg) != TYPE_DICTIONARY: return
	var event = msg.get("event", "")
	var payload = msg.get("payload", {})

	if event == "broadcast":
		var p = payload.get("payload", {})
		var ev = payload.get("event", "")
		var uid = p.get("uid", "")
		if uid == Supabase.user_id: return
		match ev:
			"move":    emit_signal("remote_move",   uid, p.x, p.y, p.get("facing", 1), p.get("dir", 0))
			"attack":  emit_signal("remote_attack", uid, p.get("facing", 1), p.get("dir", 0))
			"lobby":   emit_signal("remote_lobby",  uid, p.get("ready", false), p.get("gender", "man"))
	elif event == "presence_state":
		# First snapshot on join — dict of {uid: [{meta}]}
		for uid in payload.keys():
			if uid == Supabase.user_id: continue
			var entry = payload[uid]
			if entry is Dictionary:
				var metas = payload[uid]
				if metas is Array and metas.size() > 0:
					emit_signal("remote_join", uid, metas[0])
	elif event == "presence_diff":
		for uid in payload.get("joins", {}).keys():
			if uid == Supabase.user_id: continue
			var entry = payload.joins[uid]
			if entry is Dictionary:
				var metas = entry.get("metas", [])
				if metas is Array and metas.size() > 0:
					emit_signal("remote_join", uid, metas[0])
		for uid in payload.get("leaves", {}).keys():
			if uid == Supabase.user_id: continue
			emit_signal("remote_leave", uid)
