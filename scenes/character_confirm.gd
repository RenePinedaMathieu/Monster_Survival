extends Control

## Pantalla intermedia entre elegir personaje y arrancar la run:
## retrato grande a la izquierda + ventana a la derecha con rol, stats
## orientativas y una descripción corta. Antes se pasaba directo de la
## card al gameplay y se sentía muy brusco.
##
## Lee GameState.pending_character (dict completo de la entry elegida
## en character_select.gd, ver CHARACTERS ahí) — no duplica esos datos.

const UITheme := preload("res://scenes/ui_theme.gd")
const RpgTheme := preload("res://scenes/rpg_theme.gd")
const GAME_SCENE := "res://scenes/main.tscn"
const SELECT_SCENE := "res://scenes/character_select.tscn"
const BACKGROUND_TEXTURE := "res://assets/layouts/background_home.png"

const STAT_COLOR := Color("57c767")
const STAT_MAX := 5

@onready var _portrait_frame: PanelContainer = $Layout/Left/PortraitFrame
@onready var _portrait: TextureRect = $Layout/Left/PortraitFrame/Portrait
@onready var _panel: PanelContainer = $Layout/Right/Panel
@onready var _name_label: Label = $Layout/Right/Panel/VBox/NameLabel
@onready var _role_label: Label = $Layout/Right/Panel/VBox/RoleLabel
@onready var _stats_box: VBoxContainer = $Layout/Right/Panel/VBox/StatsBox
@onready var _blurb_label: Label = $Layout/Right/Panel/VBox/BlurbLabel
@onready var _confirm_button: Button = $Layout/Right/Buttons/ConfirmButton
@onready var _back_button: Button = $Layout/Right/Buttons/BackButton

func _ready() -> void:
	var data: Dictionary = GameState.pending_character
	if data.is_empty():
		# Llegaron acá sin pasar por character_select (F5 directo a
		# esta escena, etc.) — no hay nada que mostrar, así que
		# volvemos a elegir en vez de crashear leyendo un dict vacío.
		get_tree().change_scene_to_file.call_deferred(SELECT_SCENE)
		return

	$Background.texture = load(BACKGROUND_TEXTURE)
	_portrait.texture = load(data["portrait"])
	_portrait_frame.add_theme_stylebox_override("panel", RpgTheme.slot_box(true, 12.0))
	_panel.add_theme_stylebox_override("panel", RpgTheme.window_box_titled(28.0, 24.0))

	_name_label.text = data["name"]
	RpgTheme.style_header_title(_name_label, 26)

	_role_label.text = data.get("role", "")
	RpgTheme.style_ink_label(_role_label, 17, true)

	_blurb_label.text = data.get("blurb", "")
	RpgTheme.style_ink_label(_blurb_label, 15, false, true)

	_build_stats(data.get("stats", {}))

	for b in [_confirm_button, _back_button]:
		RpgTheme.style_button(b, 20)
		b.mouse_entered.connect(UITheme.pulse.bind(b, 1.05, 0.08))
		b.mouse_entered.connect(func(): Audio.play_sfx("ui_hover"))
		b.mouse_exited.connect(UITheme.pulse.bind(b, 1.0, 0.08))
		b.pressed.connect(func(): Audio.play_sfx("ui_click"))
	_confirm_button.pressed.connect(_on_confirm)
	_back_button.pressed.connect(_on_back)
	_confirm_button.grab_focus()
	Screen.layout_changed.connect(_apply_layout)
	_apply_layout(Screen.compact)

## Teléfono: retrato arriba y ficha abajo, todo centrado y del tamaño de
## su contenido — antes la ficha se estiraba a toda la altura de la
## pantalla vertical y el texto quedaba en el décimo de arriba.
func _apply_layout(compact: bool) -> void:
	var vp := Screen.view_size()
	var layout: BoxContainer = $Layout
	var right: VBoxContainer = $Layout/Right
	layout.vertical = compact
	layout.alignment = BoxContainer.ALIGNMENT_CENTER if compact else BoxContainer.ALIGNMENT_BEGIN
	layout.add_theme_constant_override("separation", 16 if compact else 50)
	var margin: float = 14.0 if compact else 60.0
	layout.offset_left = margin
	layout.offset_right = -margin
	layout.offset_top = 16.0 if compact else 40.0
	layout.offset_bottom = -16.0 if compact else -40.0
	if compact:
		var ph: float = clampf(vp.y * 0.34, 200.0, 420.0)
		_portrait.custom_minimum_size = Vector2(ph * 0.68, ph)
		right.custom_minimum_size = Vector2(0, 0)
		right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	else:
		_portrait.custom_minimum_size = Vector2(380, 560)
		right.custom_minimum_size = Vector2(460, 0)
		right.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
		get_viewport().set_input_as_handled()

func _build_stats(stats: Dictionary) -> void:
	for stat_name in stats:
		var value: int = stats[stat_name]

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_stats_box.add_child(row)

		var label := Label.new()
		label.text = stat_name
		label.custom_minimum_size = Vector2(120, 0)
		RpgTheme.style_ink_label(label, 15, true)
		row.add_child(label)

		var bar := ProgressBar.new()
		bar.min_value = 0
		bar.max_value = STAT_MAX
		bar.value = value
		bar.show_percentage = false
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.custom_minimum_size = Vector2(0, 16)
		RpgTheme.style_level_bar(bar, STAT_COLOR)
		row.add_child(bar)

func _on_confirm() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_back() -> void:
	get_tree().change_scene_to_file(SELECT_SCENE)
