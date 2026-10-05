extends Node

## Autoload "Settings" — controles y preferencias del jugador.
##
## 1. CONTROLES: registra por código las acciones de input con teclado
##    Y gamepad (en vez de escribirlas a mano en project.godot, donde el
##    formato serializado es frágil y choca fácil en los merges):
##      move_left/right/up/down  WASD, flechas, stick izquierdo, cruceta
##      active_skill             ESPACIO, botón X/□ (abajo-izq), RB
##      pause                    ESC, START
##      zoom_in / zoom_out       E / Q, gatillos RT / LT
##    Además suma el stick izquierdo a ui_left/right/up/down, así todos
##    los menús se navegan con el stick (la cruceta y A/B para aceptar/
##    volver ya vienen por defecto en las acciones ui_* de Godot).
##
## 2. OPCIONES: volumen general / música / efectos, pantalla completa,
##    VSync e idioma. Se guardan en user://settings.cfg — archivo
##    aparte del progreso (save.cfg de GameState) para que borrar o
##    migrar el progreso nunca resetee las opciones, y viceversa.

signal changed

const SETTINGS_PATH := "user://settings.cfg"
const LANGUAGES: Array[String] = ["es", "en"]
const LANGUAGE_NAMES: Dictionary = {"es": "ESPAÑOL", "en": "ENGLISH"}

## Zona muerta del stick para moverse — la de Godot por defecto (0.5)
## obliga a inclinar el stick hasta la mitad para que el héroe arranque.
const MOVE_DEADZONE := 0.25

## Volúmenes del jugador como multiplicador lineal 0..1 sobre el volumen
## base de cada bus (default_bus_layout.tres: Music ya viene a -4 dB).
## El 1.0 respeta esa mezcla en vez de subir la música a 0 dB.
var volumes: Dictionary = {"Master": 1.0, "Music": 1.0, "SFX": 1.0}
var fullscreen: bool = false
var vsync: bool = true
var language: String = "es"

var _base_db: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_actions()
	for bus in volumes:
		var idx := AudioServer.get_bus_index(bus)
		_base_db[bus] = AudioServer.get_bus_volume_db(idx) if idx >= 0 else 0.0
	language = _default_language()
	_load()
	_apply_all()

# ── Controles ──────────────────────────────────────────────────────

func _register_actions() -> void:
	_action("move_left",  [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0), _btn(JOY_BUTTON_DPAD_LEFT)], MOVE_DEADZONE)
	_action("move_right", [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0), _btn(JOY_BUTTON_DPAD_RIGHT)], MOVE_DEADZONE)
	_action("move_up",    [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0), _btn(JOY_BUTTON_DPAD_UP)], MOVE_DEADZONE)
	_action("move_down",  [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0), _btn(JOY_BUTTON_DPAD_DOWN)], MOVE_DEADZONE)
	_action("active_skill", [_key(KEY_SPACE), _btn(JOY_BUTTON_X), _btn(JOY_BUTTON_RIGHT_SHOULDER)])
	_action("pause", [_key(KEY_ESCAPE), _btn(JOY_BUTTON_START)])
	_action("zoom_in",  [_key(KEY_E), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)])
	_action("zoom_out", [_key(KEY_Q), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)])
	# Menús con el stick izquierdo (ui_* ya trae cruceta + A/B).
	InputMap.action_add_event("ui_left", _axis(JOY_AXIS_LEFT_X, -1.0))
	InputMap.action_add_event("ui_right", _axis(JOY_AXIS_LEFT_X, 1.0))
	InputMap.action_add_event("ui_up", _axis(JOY_AXIS_LEFT_Y, -1.0))
	InputMap.action_add_event("ui_down", _axis(JOY_AXIS_LEFT_Y, 1.0))

func _action(action_name: String, events: Array, deadzone: float = 0.5) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, deadzone)
	for ev in events:
		InputMap.action_add_event(action_name, ev)

## Tecla por posición física (no por layout), así WASD queda en el mismo
## lugar en teclados QWERTY, AZERTY, etc.
func _key(code: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	return ev

func _btn(button: JoyButton) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	return ev

func _axis(axis: JoyAxis, direction: float) -> InputEventJoypadMotion:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = direction
	return ev

## Herramientas nuestras (QA Room, Catálogo, detector F3): visibles en
## el editor y en el build web (donde se prueba desde el teléfono),
## ocultas en el build de Steam — el preset "Windows Desktop" de
## export_presets.cfg lleva la etiqueta "steam" en custom_features.
func dev_tools_enabled() -> bool:
	return not OS.has_feature("steam")

## Último dispositivo usado — para que los textos de ayuda muestren
## "START" o "ESC" según con qué se esté jugando.
var using_gamepad: bool = false

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		using_gamepad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		using_gamepad = false

# ── Opciones ───────────────────────────────────────────────────────

func set_volume(bus: String, value: float) -> void:
	volumes[bus] = clampf(value, 0.0, 1.0)
	_apply_volume(bus)
	_save()

func set_fullscreen(on: bool) -> void:
	fullscreen = on
	_apply_window()
	_save()

func set_vsync(on: bool) -> void:
	vsync = on
	_apply_window()
	_save()

func set_language(code: String) -> void:
	if not code in LANGUAGES:
		return
	language = code
	TranslationServer.set_locale(language)
	_save()
	changed.emit()

## Pasa al idioma siguiente de LANGUAGES (para un botón que cicla).
func cycle_language() -> void:
	var i := LANGUAGES.find(language)
	set_language(LANGUAGES[(i + 1) % LANGUAGES.size()])

## F11 y los toggles de los menús pasan por acá para que la elección
## quede guardada.
func toggle_fullscreen() -> void:
	set_fullscreen(not fullscreen)

func _apply_all() -> void:
	for bus in volumes:
		_apply_volume(bus)
	_apply_window()
	TranslationServer.set_locale(language)

func _apply_volume(bus: String) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	var v: float = volumes[bus]
	AudioServer.set_bus_mute(idx, v <= 0.001)
	if v > 0.001:
		AudioServer.set_bus_volume_db(idx, _base_db.get(bus, 0.0) + linear_to_db(v))

func _apply_window() -> void:
	# En Web el navegador maneja la pantalla completa y el VSync.
	if OS.has_feature("web"):
		return
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	)
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)

## Primer arranque: español si el sistema está en español, si no inglés.
func _default_language() -> String:
	return "es" if OS.get_locale_language() == "es" else "en"

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for bus in volumes:
		volumes[bus] = cfg.get_value("audio", bus, volumes[bus])
	fullscreen = cfg.get_value("video", "fullscreen", fullscreen)
	vsync = cfg.get_value("video", "vsync", vsync)
	var lang: String = cfg.get_value("general", "language", language)
	if lang in LANGUAGES:
		language = lang

func _save() -> void:
	var cfg := ConfigFile.new()
	for bus in volumes:
		cfg.set_value("audio", bus, volumes[bus])
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "vsync", vsync)
	cfg.set_value("general", "language", language)
	cfg.save(SETTINGS_PATH)
