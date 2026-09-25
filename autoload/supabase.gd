extends Node

## Supabase client — auth (anonymous only during alpha) + REST helper.
## Add as Autoload in Project Settings with name "Supabase".
##
## Env: put your Project URL + anon public key from the Supabase
## dashboard (Settings → API). NEVER put the service_role key here.

const URL      := "https://vrgqqwxsbnhxupxocczg.supabase.co"
const ANON_KEY := "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZyZ3Fxd3hzYm5oeHVweG9jY3pnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU0MDUxNDIsImV4cCI6MjA5MDk4MTE0Mn0.DRsN6zQLI3mEG6-UPGTt1BzlXRxRm0_prq78TmK1bM8"

var access_token: String = ""
var refresh_token: String = ""
var user_id: String = ""
var username: String = ""

signal auth_ready

## La sesión anónima se guarda aparte del save del juego y se renueva
## con el refresh_token — antes cada partida creaba un usuario anónimo
## nuevo (y el ranking no tenía cómo saber que eras el mismo).
const SESSION_PATH := "user://session.cfg"
var _authing: bool = false

## El access_token de Supabase dura 1 hora (expires_in). Una pestaña
## abierta más que eso seguía mandando el token vencido: PostgREST
## respondía 401 y el ranking salía vacío y las partidas no se subían.
## Se renueva un minuto antes de que venza.
var expires_at: float = 0.0
const TOKEN_MARGIN := 60.0

func _ready() -> void:
	pass

func is_signed_in() -> bool:
	return access_token != ""

## Hay token y todavía no está por vencer.
func has_fresh_token() -> bool:
	return access_token != "" and Time.get_unix_time_from_system() < expires_at - TOKEN_MARGIN

## Deja una sesión lista: la ya abierta (si no venció), la renueva con
## el refresh_token (el de memoria o el guardado) o abre una anónima
## nueva si no hay ninguna.
func ensure_session(name: String) -> void:
	if name != "":
		username = name
	if has_fresh_token():
		auth_ready.emit()
		return
	if _authing:
		return
	_authing = true
	if refresh_token != "":
		_refresh(refresh_token, name)
		return
	var cfg := ConfigFile.new()
	if cfg.load(SESSION_PATH) == OK:
		var saved: String = cfg.get_value("session", "refresh_token", "")
		if saved != "":
			_refresh(saved, name)
			return
	sign_in_anonymous(name)

func _refresh(token: String, name: String) -> void:
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		http.queue_free()
		if code >= 200 and code < 300:
			_on_auth(0, code, [], body, null)
		elif code == 0 or code >= 500:
			# Sin conexión o Supabase caído: se reintenta la próxima vez
			# (abrir otra sesión acá crearía un usuario nuevo por nada).
			_authing = false
		else:
			# Refresh token vencido o borrado: se arranca una sesión nueva.
			sign_in_anonymous(name))
	http.request(URL + "/auth/v1/token?grant_type=refresh_token", [
		"apikey: " + ANON_KEY, "Content-Type: application/json",
	], HTTPClient.METHOD_POST, JSON.stringify({"refresh_token": token}))

func _save_session() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("session", "refresh_token", refresh_token)
	cfg.save(SESSION_PATH)

## Bearer para escribir: el token de la sesión o, sin sesión, la anon key.
func _bearer() -> String:
	return access_token if access_token != "" else ANON_KEY

## Corre fn con un token vigente: si venció, primero lo renueva.
func _with_fresh_token(fn: Callable) -> void:
	if has_fresh_token():
		fn.call()
		return
	auth_ready.connect(fn, CONNECT_ONE_SHOT)
	ensure_session(username)

## Anonymous signin with a display name stored in user_metadata.
## Requires anonymous auth enabled in dashboard → Authentication →
## Providers → Anonymous.
func sign_in_anonymous(name: String) -> void:
	username = name
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_auth.bind(http))
	var body = JSON.stringify({ "data": { "username": name } })
	var headers = [
		"apikey: " + ANON_KEY,
		"Content-Type: application/json",
	]
	# The /auth/v1/signup endpoint doubles as anonymous when no
	# email/password is provided.
	var err = http.request(URL + "/auth/v1/signup", headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		push_error("Supabase HTTPRequest error: " + str(err))

func _on_auth(_r, code, _h, body, http) -> void:
	if http != null:
		http.queue_free()
	_authing = false
	var text = body.get_string_from_utf8()
	if code < 200 or code >= 300:
		push_error("Supabase auth %d: %s" % [code, text])
		return
	var data = JSON.parse_string(text)
	if data == null or not data.has("access_token"):
		push_error("Supabase auth: bad response %s" % text)
		return
	access_token  = data.access_token
	refresh_token = data.get("refresh_token", "")
	user_id       = data.user.id
	expires_at    = Time.get_unix_time_from_system() + float(data.get("expires_in", 3600))
	_save_session()
	print("[supabase] auth ok, uid=", user_id)
	emit_signal("auth_ready")

## Fire-and-forget Postgres SELECT via PostgREST. Callback gets
## (result_code, body_string) so you can parse per-request.
## Sólo se usa para tablas públicas (el ranking), así que va siempre con
## la anon key: no depende de que la sesión esté vigente.
func rest_get(path: String, on_done: Callable) -> void:
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		http.queue_free()
		on_done.call(code, body.get_string_from_utf8()))
	http.request(URL + "/rest/v1" + path, [
		"apikey: " + ANON_KEY,
		"Authorization: Bearer " + ANON_KEY,
		"Accept: application/json",
	], HTTPClient.METHOD_GET)

## INSERT simple (sin upsert). Necesita sesión: las políticas de la
## tabla exigen que user_id sea el del token (se renueva si venció).
func rest_insert(path: String, body_json: Dictionary, on_done := Callable()) -> void:
	_with_fresh_token(_insert_now.bind(path, body_json, on_done))

func _insert_now(path: String, body_json: Dictionary, on_done: Callable) -> void:
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		http.queue_free()
		if on_done.is_valid():
			on_done.call(code, body.get_string_from_utf8()))
	http.request(URL + "/rest/v1" + path, [
		"apikey: " + ANON_KEY,
		"Authorization: Bearer " + _bearer(),
		"Content-Type: application/json",
		"Prefer: return=minimal",
	], HTTPClient.METHOD_POST, JSON.stringify(body_json))

## Postgres upsert (or insert with `Prefer: return=representation`).
func rest_upsert(path: String, body_json: Dictionary, on_done := Callable()) -> void:
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		http.queue_free()
		if on_done.is_valid():
			on_done.call(code, body.get_string_from_utf8()))
	http.request(URL + "/rest/v1" + path, [
		"apikey: " + ANON_KEY,
		"Authorization: Bearer " + access_token,
		"Content-Type: application/json",
		"Prefer: resolution=merge-duplicates,return=representation",
	], HTTPClient.METHOD_POST, JSON.stringify(body_json))
