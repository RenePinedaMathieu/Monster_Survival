extends Control

## Menú de inicio. Fondo fijo (background_home.png), JUGAR y debajo
## Tienda / Ranking / Logros / Opciones / Salir (una columna en
## vertical, dos acostado), RETO DIARIO arriba a la derecha y el panel
## de opciones (options_controls.gd: volúmenes, pantalla, VSync,
## idioma). "Jugar" lleva a la selección de personaje, no directo al
## gameplay.

const UITheme := preload("res://scenes/ui_theme.gd")
const RpgTheme := preload("res://scenes/rpg_theme.gd")
const BuildInfo := preload("res://scenes/build_info.gd")
const DAILY_TOP_SCRIPT := preload("res://scenes/daily_top_panel.gd")

const CHARACTER_SELECT_SCENE := "res://scenes/character_select.tscn"
const SHOP_SCENE := "res://scenes/shop_menu.tscn"
const ACHIEVEMENTS_SCENE := "res://scenes/achievements_menu.tscn"
const DAILY_SCENE := "res://scenes/daily_menu.tscn"
const RANKING_SCENE := "res://scenes/leaderboard_menu.tscn"
const TRIALS_SCENE := "res://scenes/trials_menu.tscn"
const CREDITS_SCENE := "res://scenes/credits_menu.tscn"
const TUTORIAL_SCENE := preload("res://scenes/tutorial_overlay.tscn")
const BACKGROUND_TEXTURE := "res://assets/layouts/background_home.png"

@onready var _background: TextureRect = $Background
@onready var _menu_buttons: VBoxContainer = $MenuButtons
@onready var _grid: GridContainer = $MenuButtons/Grid
@onready var _record_label: Label = $MenuButtons/RecordLabel
@onready var _play_button: Button = $MenuButtons/PlayButton
@onready var _shop_button: Button = $MenuButtons/Grid/ShopButton
@onready var _ranking_button: Button = $MenuButtons/Grid/RankingButton
@onready var _trials_button: Button = $MenuButtons/Grid/TrialsButton
@onready var _achievements_button: Button = $MenuButtons/Grid/AchievementsButton
@onready var _options_button: Button = $MenuButtons/Grid/OptionsButton
@onready var _quit_button: Button = $MenuButtons/Grid/QuitButton
@onready var _options_panel: Panel = $OptionsPanel
@onready var _options_controls = $OptionsPanel/Content/OptionsControls   # options_controls.gd
@onready var _tutorial_button: Button = $OptionsPanel/Content/ExtraRow/TutorialButton
@onready var _credits_button: Button = $OptionsPanel/Content/ExtraRow/CreditsButton
@onready var _qa_room_button: Button = $OptionsPanel/Content/DevRow/QARoomButton
@onready var _back_button: Button = $OptionsPanel/Content/BackButton

func _ready() -> void:
	# Volver al menú corta el reto diario y los desafíos (los prenden
	# daily_menu y trials_menu).
	GameState.daily_active = false
	GameState.trial_active = ""
	var daily: Button = $DailyButton
	RpgTheme.style_button(daily, 17)
	daily.pressed.connect(func():
		Audio.play_sfx("ui_click")
		get_tree().change_scene_to_file(DAILY_SCENE))
	_background.texture = load(BACKGROUND_TEXTURE)
	RpgTheme.style_light_label(_record_label, 16)
	_record_label.modulate.a = 0.9
	_add_version_label()
	_add_daily_top()
	_refresh_record()
	# Los textos fijos se re-traducen solos al cambiar el idioma; los
	# armados con números (el récord) hay que rearmarlos.
	Settings.changed.connect(_refresh_record)

	for button in [_play_button, _shop_button, _trials_button, _ranking_button, _achievements_button, _options_button, _quit_button]:
		RpgTheme.style_button(button, 20)
	for button in [_back_button, _tutorial_button, _credits_button, _qa_room_button]:
		RpgTheme.style_button(button, 16)
	_achievements_button.pressed.connect(func(): get_tree().change_scene_to_file(ACHIEVEMENTS_SCENE))
	_ranking_button.pressed.connect(func(): get_tree().change_scene_to_file(RANKING_SCENE))
	_trials_button.pressed.connect(func(): get_tree().change_scene_to_file(TRIALS_SCENE))
	for button in [_play_button, _shop_button, _trials_button, _ranking_button, _achievements_button, _options_button, _quit_button, _back_button, _tutorial_button, _credits_button, _qa_room_button]:
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

	_tutorial_button.pressed.connect(_on_tutorial_button_pressed)
	_credits_button.pressed.connect(func(): get_tree().change_scene_to_file(CREDITS_SCENE))
	_qa_room_button.pressed.connect(_on_qa_room_pressed)
	var catalog_button: Button = $OptionsPanel/Content/DevRow/CatalogButton
	RpgTheme.style_button(catalog_button, 16)
	catalog_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/catalog.tscn"))
	# QA Room y Catálogo son herramientas nuestras: no van en el build
	# de Steam (ver Settings.dev_tools_enabled).
	$OptionsPanel/Content/DevRow.visible = Settings.dev_tools_enabled()

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
##
## Botones: una columna en vertical; acostado (o PC) JUGAR ancho arriba
## y el resto en 2 columnas, así quedan debajo del logo. El bloque crece
## hacia arriba desde el borde inferior (grow_vertical = begin).
func _apply_layout(_compact: bool) -> void:
	var vp := Screen.view_size()
	var ow: float = minf(460.0, vp.x - 20.0)
	_options_panel.offset_left = -ow / 2.0
	_options_panel.offset_right = ow / 2.0
	var oh: float = minf(540.0 if Settings.dev_tools_enabled() else 486.0, vp.y - 16.0)
	_options_panel.offset_top = -oh / 2.0
	_options_panel.offset_bottom = oh / 2.0
	var tall: bool = vp.y > vp.x * 1.2
	var short: bool = vp.y < 640.0
	if _daily_top != null:
		_daily_top.visible = not tall
	var bw: float = 240.0 if tall else (190.0 if short else 220.0)
	var bh: float = 48.0 if not short else 42.0
	_grid.columns = 1 if tall else 2
	for b in _grid.get_children():
		b.custom_minimum_size = Vector2(bw, bh)
	_play_button.custom_minimum_size = Vector2(bw if tall else bw * 2.0 + 10.0, bh + (0.0 if tall else 4.0))
	_menu_buttons.add_theme_constant_override("separation", 7 if short else 9)
	_grid.add_theme_constant_override("v_separation", 7 if short else 9)
	_menu_buttons.offset_bottom = -16.0 if short else -34.0
	_menu_buttons.offset_top = _menu_buttons.offset_bottom
	if tall:
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

## "TOP DE HOY" del reto diario, bajo el botón RETO DIARIO (arriba a la
## derecha). Clic: abre el ranking. En vertical no entra junto al logo.
var _daily_top: PanelContainer

func _add_daily_top() -> void:
	_daily_top = PanelContainer.new()
	_daily_top.set_script(DAILY_TOP_SCRIPT)
	_daily_top.anchor_left = 1.0
	_daily_top.anchor_right = 1.0
	_daily_top.offset_right = -16.0
	_daily_top.offset_left = -16.0 - DAILY_TOP_SCRIPT.WIDTH
	_daily_top.offset_top = 76.0
	_daily_top.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(_daily_top)
	# Debajo del panel de opciones (que se abre encima de todo).
	move_child(_daily_top, _options_panel.get_index())
	_daily_top.open_ranking.connect(func(): get_tree().change_scene_to_file(RANKING_SCENE))

func _refresh_record() -> void:
	if GameState.best_wave <= 0:
		_record_label.hide()
		return
	var mins := int(GameState.best_time) / 60
	var secs := int(GameState.best_time) % 60
	_record_label.text = tr("RÉCORD — Oleada %d · %02d:%02d") % [GameState.best_wave, mins, secs]

## Versión chica abajo a la izquierda (ver build_info.gd).
func _add_version_label() -> void:
	var v := Label.new()
	v.text = "v " + BuildInfo.COMMIT
	RpgTheme.style_light_label(v, 12)
	v.modulate.a = 0.55
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.anchor_top = 1.0
	v.anchor_bottom = 1.0
	v.offset_left = 8.0
	v.offset_top = -22.0
	v.offset_bottom = -4.0
	v.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(v)

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
	# Con control/teclado, el foco tiene que entrar al panel — si no,
	# queda en un botón del menú de atrás y no hay forma de llegar.
	var first: Control = _options_controls.first_control()
	if first != null:
		first.grab_focus()

func _on_back_pressed() -> void:
	_options_panel.visible = false
	_options_button.grab_focus()

func _on_quit_pressed() -> void:
	get_tree().quit()
