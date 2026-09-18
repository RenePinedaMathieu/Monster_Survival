extends Control

## Menú de inicio. Fondo fijo (background_home.png) + 3 botones
## estilo pixel-art (Jugar / Opciones / Salir) y un panel simple de
## opciones (volumen master + pantalla completa). "Jugar" lleva a la
## selección de personaje, no directo al gameplay.

const UITheme := preload("res://scenes/ui_theme.gd")

const CHARACTER_SELECT_SCENE := "res://scenes/character_select.tscn"
const SHOP_SCENE := "res://scenes/shop_menu.tscn"
const BACKGROUND_TEXTURE := "res://assets/layouts/background_home.png"

@onready var _background: TextureRect = $Background
@onready var _play_button: Button = $MenuButtons/PlayButton
@onready var _shop_button: Button = $MenuButtons/ShopButton
@onready var _options_button: Button = $MenuButtons/OptionsButton
@onready var _quit_button: Button = $MenuButtons/QuitButton
@onready var _options_panel: Panel = $OptionsPanel
@onready var _volume_slider: HSlider = $OptionsPanel/Content/VolumeRow/VolumeSlider
@onready var _fullscreen_check: CheckButton = $OptionsPanel/Content/FullscreenRow/FullscreenCheck
@onready var _back_button: Button = $OptionsPanel/Content/BackButton

func _ready() -> void:
	_background.texture = load(BACKGROUND_TEXTURE)

	for button in [_play_button, _shop_button, _options_button, _quit_button, _back_button]:
		UITheme.style_button(button)
		button.mouse_entered.connect(UITheme.pulse.bind(button, 1.06, 0.08))
		button.mouse_exited.connect(UITheme.pulse.bind(button, 1.0, 0.08))

	_play_button.pressed.connect(_on_play_pressed)
	_shop_button.pressed.connect(_on_shop_pressed)
	_options_button.pressed.connect(_on_options_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_back_button.pressed.connect(_on_back_pressed)

	var master_idx := AudioServer.get_bus_index("Master")
	_volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(master_idx))
	_volume_slider.value_changed.connect(_on_volume_changed)

	_fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)

	# En Web no hay forma confiable de "cerrar" la pestaña del browser
	# desde el juego — el botón no tiene sentido ahí.
	if OS.has_feature("web"):
		_quit_button.hide()

	_play_button.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if _options_panel.visible and event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()

# ── Botones ──────────────────────────────────────────────────────

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)

func _on_shop_pressed() -> void:
	get_tree().change_scene_to_file(SHOP_SCENE)

func _on_options_pressed() -> void:
	_options_panel.visible = true

func _on_back_pressed() -> void:
	_options_panel.visible = false

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(value))

func _on_fullscreen_toggled(pressed: bool) -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if pressed else DisplayServer.WINDOW_MODE_WINDOWED
	)
