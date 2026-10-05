extends VBoxContainer

## Filas de opciones que comparten el menú principal y el menú de pausa:
## volumen general / música / efectos, pantalla completa, VSync e
## idioma. Todo pasa por el autoload Settings, que lo aplica y lo guarda
## en user://settings.cfg — acá sólo se arman los controles.
##
## Uso: un nodo VBoxContainer con este script dentro del panel de
## opciones; first_control() devuelve el primero para darle el foco.

const RpgTheme := preload("res://scenes/rpg_theme.gd")
const LABEL_WIDTH := 150.0

var _language_button: Button
var _first: Control

func _ready() -> void:
	add_theme_constant_override("separation", 10)
	_add_volume_row("Volumen general", "Master")
	_add_volume_row("Música", "Music")
	_add_volume_row("Efectos", "SFX")
	# En Web el navegador maneja la pantalla completa y el VSync.
	if not OS.has_feature("web"):
		_add_check_row("Pantalla completa", Settings.fullscreen, Settings.set_fullscreen)
		_add_check_row("VSync", Settings.vsync, Settings.set_vsync)
	_add_language_row()
	Settings.changed.connect(_refresh_language)

func first_control() -> Control:
	return _first

func _row(label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	RpgTheme.style_ink_label(label, 16, true)
	row.add_child(label)
	return row

func _add_volume_row(label_text: String, bus: String) -> void:
	var row := _row(label_text)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = Settings.volumes.get(bus, 1.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	RpgTheme.style_slider(slider)
	slider.value_changed.connect(func(v: float): Settings.set_volume(bus, v))
	# Un "tick" al soltar para escuchar cómo quedó el volumen de efectos.
	if bus != "Music":
		slider.drag_ended.connect(func(_changed: bool): Audio.play_sfx("ui_click"))
	row.add_child(slider)
	_remember_first(slider)

func _add_check_row(label_text: String, value: bool, setter: Callable) -> void:
	var row := _row(label_text)
	var check := CheckButton.new()
	check.button_pressed = value
	RpgTheme.style_check(check)
	check.toggled.connect(func(on: bool): setter.call(on))
	row.add_child(check)
	_remember_first(check)

func _add_language_row() -> void:
	var row := _row("Idioma")
	_language_button = Button.new()
	_language_button.custom_minimum_size = Vector2(0, 40)
	_language_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# El nombre de cada idioma va siempre en su propio idioma.
	_language_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	RpgTheme.style_button(_language_button, 15)
	_language_button.pressed.connect(func():
		Audio.play_sfx("ui_click")
		Settings.cycle_language())
	row.add_child(_language_button)
	_refresh_language()
	_remember_first(_language_button)

func _refresh_language() -> void:
	if _language_button != null:
		_language_button.text = Settings.LANGUAGE_NAMES.get(Settings.language, Settings.language)

func _remember_first(c: Control) -> void:
	if _first == null:
		_first = c
