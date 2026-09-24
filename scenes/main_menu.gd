extends Control

## Menú de inicio. Fondo fijo (background_home.png) + 3 botones
## estilo pixel-art (Jugar / Opciones / Salir) y un panel simple de
## opciones (volumen master + pantalla completa). "Jugar" lleva a la
## selección de personaje, no directo al gameplay.

const UITheme := preload("res://scenes/ui_theme.gd")
const RpgTheme := preload("res://scenes/rpg_theme.gd")

const CHARACTER_SELECT_SCENE := "res://scenes/character_select.tscn"
const SHOP_SCENE := "res://scenes/shop_menu.tscn"
const ACHIEVEMENTS_SCENE := "res://scenes/achievements_menu.tscn"
const TUTORIAL_SCENE := preload("res://scenes/tutorial_overlay.tscn")
const BACKGROUND_TEXTURE := "res://assets/layouts/background_home.png"

@onready var _background: TextureRect = $Background
@onready var _record_label: Label = $RecordLabel
@onready var _play_button: Button = $MenuButtons/PlayButton
@onready var _shop_button: Button = $MenuButtons/ShopButton
@onready var _achievements_button: Button = $MenuButtons/AchievementsButton
@onready var _options_button: Button = $MenuButtons/OptionsButton
@onready var _quit_button: Button = $MenuButtons/QuitButton
@onready var _options_panel: Panel = $OptionsPanel
@onready var _volume_slider: HSlider = $OptionsPanel/Content/VolumeRow/VolumeSlider
@onready var _fullscreen_check: CheckButton = $OptionsPanel/Content/FullscreenRow/FullscreenCheck
@onready var _tutorial_button: Button = $OptionsPanel/Content/TutorialButton
@onready var _qa_room_button: Button = $OptionsPanel/Content/QARoomButton
@onready var _back_button: Button = $OptionsPanel/Content/BackButton

func _ready() -> void:
	_background.texture = load(BACKGROUND_TEXTURE)
	RpgTheme.style_light_label(_record_label, 16)
	_record_label.modulate.a = 0.9
	if GameState.best_wave > 0:
		var mins := int(GameState.best_time) / 60
		var secs := int(GameState.best_time) % 60
		_record_label.text = "RÉCORD — Oleada %d · %02d:%02d" % [GameState.best_wave, mins, secs]
	else:
		_record_label.text = ""

	for button in [_play_button, _shop_button, _achievements_button, _options_button, _quit_button]:
		RpgTheme.style_button(button, 20)
	for button in [_back_button, _tutorial_button, _qa_room_button]:
		RpgTheme.style_button(button, 16)
	_achievements_button.pressed.connect(func(): get_tree().change_scene_to_file(ACHIEVEMENTS_SCENE))
	for button in [_play_button, _shop_button, _achievements_button, _options_button, _quit_button, _back_button, _tutorial_button, _qa_room_button]:
		button.mouse_entered.connect(UITheme.pulse.bind(button, 1.06, 0.08))
		button.mouse_entered.connect(func(): Audio.play_sfx("ui_hover"))
		button.mouse_exited.connect(UITheme.pulse.bind(button, 1.0, 0.08))
		button.pressed.connect(func(): Audio.play_sfx("ui_click"))
	# Misma música que la pantalla de selección de personaje — arranca
	# acá y sigue sonando sin cortes al pasar a esa pantalla (play_music
	# no reinicia el track si ya está sonando el mismo id).
	Audio.play_music("character_select", 1200)

	_play_button.pressed.connect(_on_play_pressed)
	_shop_button.pressed.connect(_on_shop_pressed)
	_options_button.pressed.connect(_on_options_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_back_button.pressed.connect(_on_back_pressed)

	_options_panel.add_theme_stylebox_override("panel", RpgTheme.window_box())
	RpgTheme.style_header_title($OptionsPanel/Content/Title, 22)
	RpgTheme.style_ink_label($OptionsPanel/Content/VolumeRow/VolumeLabel, 16, true)
	RpgTheme.style_ink_label($OptionsPanel/Content/FullscreenRow/FullscreenLabel, 16, true)
	RpgTheme.style_slider(_volume_slider)
	RpgTheme.style_check(_fullscreen_check)

	var master_idx := AudioServer.get_bus_index("Master")
	_volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(master_idx))
	_volume_slider.value_changed.connect(_on_volume_changed)

	_fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	_tutorial_button.pressed.connect(_on_tutorial_button_pressed)
	_qa_room_button.pressed.connect(_on_qa_room_pressed)

	# En Web no hay forma confiable de "cerrar" la pestaña del browser
	# desde el juego — el botón no tiene sentido ahí.
	if OS.has_feature("web"):
		_quit_button.hide()

	_play_button.grab_focus()
	Screen.layout_changed.connect(_apply_layout)
	_apply_layout(Screen.compact)

## El logo viene horneado al centro-arriba de background_home.png. En
## vertical, "cubrir" la pantalla recortaba el logo por los costados:
## ahí escalamos la imagen para que el logo entre a lo ancho y la
## pegamos arriba (abajo queda el fondo oscuro, donde van los botones).
func _apply_layout(_compact: bool) -> void:
	var vp := Screen.view_size()
	var ow: float = minf(400.0, vp.x - 20.0)
	_options_panel.offset_left = -ow / 2.0
	_options_panel.offset_right = ow / 2.0
	if vp.y > vp.x * 1.2:
		var w: float = vp.x * 1280.0 / 470.0
		_background.anchor_right = 0.0
		_background.anchor_bottom = 0.0
		_background.position = Vector2((vp.x - w) / 2.0, 0.0)
		_background.size = Vector2(w, w * 720.0 / 1280.0)
	else:
		_background.anchor_right = 1.0
		_background.anchor_bottom = 1.0
		_background.offset_left = 0.0
		_background.offset_top = 0.0
		_background.offset_right = 0.0
		_background.offset_bottom = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if _options_panel.visible and event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()

# ── Botones ──────────────────────────────────────────────────────

func _on_play_pressed() -> void:
	if GameState.tutorial_seen:
		get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)
		return
	# Primera vez: tutorial cortito antes de dejar elegir personaje.
	var tutorial = TUTORIAL_SCENE.instantiate()
	add_child(tutorial)
	tutorial.finished.connect(func(): get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE))

## Repasarlo a mano desde Opciones — no depende de tutorial_seen ni
## navega a ningún lado al terminar, sólo se cierra.
func _on_tutorial_button_pressed() -> void:
	_options_panel.visible = false
	var tutorial = TUTORIAL_SCENE.instantiate()
	add_child(tutorial)

## Acceso al sandbox de QA — testing con hotkeys (level-up, spawn de
## monstruos, unlocks). Escondido en Opciones para que no lo vea el
## jugador final por accidente pero rápido de llegar mientras testeamos.
func _on_qa_room_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/qa_room.tscn")

func _on_shop_pressed() -> void:
	GameState.shop_return_scene = "res://scenes/main_menu.tscn"
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
