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
const MAP_SCENE := "res://scenes/map_select.tscn"
const SELECT_SCENE := "res://scenes/character_select.tscn"
const BACKGROUND_TEXTURE := "res://assets/layouts/background_home.png"

const STAT_COLOR := Color("57c767")
## La habilidad activa de cada héroe vive en player.gd (ACTIVE_SKILLS).
const PLAYER_SCRIPT := preload("res://scenes/player.gd")
const SELECT_SCRIPT := preload("res://scenes/character_select.gd")
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

## Selector de color bajo el retrato (sólo cambia el look). Los colores
## 2 a 4 se ganan ganando la Pradera, el Desierto y el Pantano con ese
## héroe (GameState.COLOR_MAPS); bloqueado se ve en silueta con la pista.
var _color_idx: int = 0
var _color_label: Label
var _color_hint: Label
var _color_dots: HBoxContainer

func _ready() -> void:
	var data: Dictionary = GameState.pending_character
	if data.is_empty():
		# Llegaron acá sin pasar por character_select (F5 directo a
		# esta escena, etc.) — no hay nada que mostrar, así que
		# volvemos a elegir en vez de crashear leyendo un dict vacío.
		get_tree().change_scene_to_file.call_deferred(SELECT_SCENE)
		return

	$Background.texture = load(BACKGROUND_TEXTURE)
	_portrait.texture = SELECT_SCRIPT.portrait_texture(data)
	_portrait_frame.add_theme_stylebox_override("panel", RpgTheme.slot_box(true, 12.0))
	_panel.add_theme_stylebox_override("panel", RpgTheme.window_box_titled(28.0, 24.0))

	_name_label.text = data["name"]
	RpgTheme.style_header_title(_name_label, 26)

	_role_label.text = data.get("role", "")
	RpgTheme.style_ink_label(_role_label, 17, true)

	_blurb_label.text = data.get("blurb", "")
	RpgTheme.style_ink_label(_blurb_label, 15, false, true)
	var skill: Dictionary = PLAYER_SCRIPT.ACTIVE_SKILLS.get(data["id"], {})
	if not skill.is_empty():
		var skill_label := Label.new()
		skill_label.text = tr("HABILIDAD: %s — %s") % [tr(skill["name"]), tr(skill["desc"])]
		skill_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		RpgTheme.style_ink_label(skill_label, 15, true)
		skill_label.add_theme_color_override("font_color", RpgTheme.COLOR_INK_GOOD)
		_blurb_label.add_sibling(skill_label)

	_build_stats(data.get("stats", {}))
	_build_color_picker(data)

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
	# Con el selector de color abajo, el retrato es más bajo para que todo
	# entre en la altura de la pantalla.
	var picker: bool = _color_label != null
	if compact:
		var ph: float = clampf(vp.y * (0.28 if picker else 0.34), 200.0, 420.0)
		_portrait.custom_minimum_size = Vector2(ph * 0.68, ph)
		right.custom_minimum_size = Vector2(0, 0)
		right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	else:
		_portrait.custom_minimum_size = Vector2(330, 470) if picker else Vector2(380, 560)
		right.custom_minimum_size = Vector2(460, 0)
		right.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
		get_viewport().set_input_as_handled()

## Izquierda/derecha cambian de color (antes que la navegación de foco
## entre JUGAR y VOLVER, que no hace falta: Esc vuelve).
func _input(event: InputEvent) -> void:
	if _color_label == null:
		return
	if event.is_action_pressed("ui_left"):
		_step_color(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_step_color(1)
		get_viewport().set_input_as_handled()

func _build_color_picker(data: Dictionary) -> void:
	var colors: Array = data.get("colors", [])
	if colors.size() <= 1:
		return
	_color_idx = int(data.get("color_index", 0))
	# El retrato queda arriba y el selector abajo (Left centraba sólo el marco).
	var left: Control = $Layout/Left
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	left.add_child(col)
	_portrait_frame.reparent(col)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	for step in [-1, 1]:
		var b := Button.new()
		b.text = "<" if step < 0 else ">"
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(44, 40)
		RpgTheme.style_button(b, 18)
		b.pressed.connect(_step_color.bind(step))
		row.add_child(b)
		if step < 0:
			_color_label = Label.new()
			_color_label.custom_minimum_size = Vector2(150, 0)
			_color_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			RpgTheme.style_light_label(_color_label, 20)
			row.add_child(_color_label)
	_color_dots = HBoxContainer.new()
	_color_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_color_dots.add_theme_constant_override("separation", 8)
	col.add_child(_color_dots)
	for i in range(colors.size()):
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(14, 14)
		_color_dots.add_child(dot)
	_color_hint = Label.new()
	_color_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	RpgTheme.style_light_label(_color_hint, 15)
	col.add_child(_color_hint)
	_show_color()

func _step_color(step: int) -> void:
	var n: int = GameState.pending_character.get("colors", []).size()
	if n <= 1:
		return
	_color_idx = (_color_idx + step + n) % n
	Audio.play_sfx("ui_click")
	_show_color()

func _show_color() -> void:
	var hero_id: String = GameState.pending_character["id"]
	var data: Dictionary = SELECT_SCRIPT.colored(GameState.pending_character, _color_idx)
	var unlocked: bool = GameState.is_color_unlocked(hero_id, _color_idx)
	_portrait.texture = SELECT_SCRIPT.portrait_texture(data)
	_portrait.modulate = Color.WHITE if unlocked else Color(0.05, 0.05, 0.08, 0.9)
	_color_label.text = data.get("color", "")
	_color_hint.text = "" if unlocked else "Bloqueado: " + GameState.color_unlock_hint(hero_id, _color_idx)
	for i in range(_color_dots.get_child_count()):
		var dot: ColorRect = _color_dots.get_child(i)
		var have: bool = GameState.is_color_unlocked(hero_id, i)
		dot.color = (Color("f2d16b") if i == _color_idx else Color("e8dcc0")) if have else Color(0.25, 0.22, 0.2)
	_confirm_button.disabled = not unlocked
	if unlocked:
		GameState.set_selected_color(hero_id, _color_idx)
		GameState.pending_character = data

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

## Antes de jugar se elige mapa y dificultad (map_select.tscn).
func _on_confirm() -> void:
	get_tree().change_scene_to_file(MAP_SCENE)

func _on_back() -> void:
	get_tree().change_scene_to_file(SELECT_SCENE)
