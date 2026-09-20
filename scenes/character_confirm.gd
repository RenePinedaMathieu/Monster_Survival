extends Control

## Pantalla intermedia entre elegir personaje y arrancar la run:
## retrato grande a la izquierda + panel "holográfico" a la derecha
## con rol, stats orientativas y una descripción corta. Antes se
## pasaba directo de la card al gameplay y se sentía muy brusco.
##
## Lee GameState.pending_character (dict completo de la entry elegida
## en character_select.gd, ver CHARACTERS ahí) — no duplica esos datos.

const UITheme := preload("res://scenes/ui_theme.gd")
const GAME_SCENE := "res://scenes/main.tscn"
const SELECT_SCENE := "res://scenes/character_select.tscn"

const HOLO_COLOR := Color("4fc3e0")
const STAT_MAX := 5

@onready var _portrait: TextureRect = $Layout/Left/Portrait
@onready var _holo_panel: PanelContainer = $Layout/Right/HoloWrap/HoloPanel
@onready var _name_label: Label = $Layout/Right/HoloWrap/HoloPanel/Margin/VBox/NameLabel
@onready var _role_label: Label = $Layout/Right/HoloWrap/HoloPanel/Margin/VBox/RoleLabel
@onready var _stats_box: VBoxContainer = $Layout/Right/HoloWrap/HoloPanel/Margin/VBox/StatsBox
@onready var _blurb_label: Label = $Layout/Right/HoloWrap/HoloPanel/Margin/VBox/BlurbLabel
@onready var _scanline: ColorRect = $Layout/Right/HoloWrap/Scanline
@onready var _confirm_button: Button = $Layout/Right/Buttons/ConfirmButton
@onready var _back_button: Button = $Layout/Right/Buttons/BackButton

func _ready() -> void:
	var data: Dictionary = GameState.pending_character
	if data.is_empty():
		# Llegaron acá sin pasar por character_select (F5 directo a
		# esta escena, etc.) — no hay nada que mostrar, así que
		# volvemos a elegir en vez de crashear leyendo un dict vacío.
		get_tree().change_scene_to_file(SELECT_SCENE)
		return

	_portrait.texture = load(data["portrait"])

	var holo_style := UITheme.make_box(Color(0.03, 0.08, 0.1, 0.75), HOLO_COLOR, 0.0, 2)
	_holo_panel.add_theme_stylebox_override("panel", holo_style)
	_scanline.color = Color(HOLO_COLOR, 0.35)
	var scan_mat := CanvasItemMaterial.new()
	scan_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_scanline.material = scan_mat
	_animate_scanline()

	_name_label.text = data["name"]
	UITheme.style_label(_name_label, 40, true)
	_name_label.add_theme_color_override("font_color", HOLO_COLOR)

	_role_label.text = data.get("role", "")
	UITheme.style_label(_role_label, 16)
	_role_label.modulate.a = 0.85

	_blurb_label.text = data.get("blurb", "")
	UITheme.style_label(_blurb_label, 15)
	_blurb_label.modulate.a = 0.9

	_build_stats(data.get("stats", {}))

	for b in [_confirm_button, _back_button]:
		UITheme.style_button(b, 20)
		b.mouse_entered.connect(UITheme.pulse.bind(b, 1.05, 0.08))
		b.mouse_entered.connect(func(): Audio.play_sfx("ui_hover"))
		b.mouse_exited.connect(UITheme.pulse.bind(b, 1.0, 0.08))
		b.pressed.connect(func(): Audio.play_sfx("ui_click"))
	_confirm_button.pressed.connect(_on_confirm)
	_back_button.pressed.connect(_on_back)
	_confirm_button.grab_focus()

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
		label.custom_minimum_size = Vector2(110, 0)
		UITheme.style_label(label, 14)
		row.add_child(label)

		var bar := ProgressBar.new()
		bar.min_value = 0
		bar.max_value = STAT_MAX
		bar.value = value
		bar.show_percentage = false
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.custom_minimum_size = Vector2(0, 18)
		UITheme.style_progress_bar(bar, HOLO_COLOR)
		row.add_child(bar)

## Línea horizontal que baja en loop dentro del panel — el único
## toque "en vivo" del holograma, sin sumar un shader nuevo al proyecto.
## Espera un frame a que el layout de containers termine de calcular
## tamaños reales antes de medir _holo_panel.size.
func _animate_scanline() -> void:
	await get_tree().process_frame
	var h: float = maxf(_holo_panel.size.y, 200.0)
	_scanline.position.y = 0.0
	var tw := create_tween().set_loops()
	tw.tween_property(_scanline, "position:y", h, 2.2).from(0.0)

func _on_confirm() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_back() -> void:
	get_tree().change_scene_to_file(SELECT_SCENE)
