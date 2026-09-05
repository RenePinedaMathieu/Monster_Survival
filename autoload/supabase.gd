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

func _ready() -> void:
	# Uncomment when you want to auto-signin on boot. Otherwise call
	# sign_in_anonymous(name) yourself from a login scene.
	# sign_in_anonymous("player_" + str(randi() % 10000))
	pass

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
	http.queue_free()
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
	print("[supabase] auth ok, uid=", user_id)
	emit_signal("auth_ready")

## Fire-and-forget Postgres SELECT via PostgREST. Callback gets
## (result_code, body_string) so you can parse per-request.
func rest_get(path: String, on_done: Callable) -> void:
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		http.queue_free()
		on_done.call(code, body.get_string_from_utf8()))
	http.request(URL + "/rest/v1" + path, [
		"apikey: " + ANON_KEY,
		"Authorization: Bearer " + access_token,
		"Accept: application/json",
	], HTTPClient.METHOD_GET)

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
