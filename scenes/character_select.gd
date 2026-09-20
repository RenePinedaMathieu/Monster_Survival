extends Control

## Selección de personaje, estilo "versus screen" (Mega Man X5): 3
## recuadros con el retrato grande + un preview animado del sprite
## idle real de cada pack. Al pasar el mouse o mover el foco con
## teclado/mando, el marco se enciende con un brillo que cicla de
## tono; click/Enter confirma, apaga a los otros dos y pasa al
## gameplay.
##
## La elección queda en GameState.selected_character_id. El gameplay
## (player.gd) todavía NO lee ese valor — cada pack en
## assets/main_characters/ tiene su propio set de direcciones/tamaño
## de frame, distinto entre sí y del sprite "Man" que usa el player
## hoy, así que conectar el skin real es trabajo aparte.

const UITheme := preload("res://scenes/ui_theme.gd")

const GAME_SCENE := "res://scenes/main.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"

const DEFAULT_IDLE_FRAME_COUNT := 8   # fallback si el char no override
const IDLE_FPS := 7.0

const CHARACTERS: Array[Dictionary] = [
	{
		"id": "main_char1",
		"name": "AXEL",
		"portrait": "res://assets/main_characters/main_char1_selectwindow.png",
		"idle_sheet": "res://assets/main_characters/main_char1/FREE_Adventurer 2D Pixel Art/Sprites/IDLE/idle_down.png",
		"accent": Color("ff6b57"),
	},
	{
		"id": "main_char2",
		"name": "KAY",
		"portrait": "res://assets/main_characters/main_char2_selectwindow.png",
		"idle_sheet": "res://assets/main_characters/main_char2/The Male adventurer - Free/Idle/idle_down.png",
		"accent": Color("7c8cff"),
	},
	{
		"id": "main_char2_female",
		"name": "LINA",
		"portrait": "res://assets/main_characters/main_char2_female_selectwindow.png",
		"idle_sheet": "res://assets/main_characters/main_char2_female/The Female Adventurer - Free/Idle/Idle_Down.png",
		"accent": Color("ff6cc9"),
	},
	{
		"id": "swordman",
		"name": "GAROTH",
		"portrait": "res://assets/main_characters/swordman_selectwindow.png",
		# Preview con lvl3 — el tier del medio, para que el jugador vea
		# a qué evoluciona (lvl1 se ve muy débil, lvl6 spoilería el
		# clímax visual).
		"idle_sheet": "res://assets/sprites/swordman/Swordsman_lvl3/Swordsman_lvl3_Idle/Swordsman_lvl3_Idle_front.png",
		"idle_frames": 12,
		"accent": Color("d4a648"),
	},
]

@onready var _glow_base: TextureRect = $GlowBase
@onready var _glow_accent_a: TextureRect = $GlowAccentA
@onready var _glow_accent_b: TextureRect = $GlowAccentB
@onready var _title: Label = $Layout/Title
@onready var _hint: Label = $Layout/Hint
@onready var _back_button: Button = $BackButton

@onready var _card_roots: Array[Control] = [
	$Layout/CardsRow/Card1, $Layout/CardsRow/Card2, $Layout/CardsRow/Card3, $Layout/CardsRow/Card4,
]
@onready var _frames: Array[Panel] = [
	$Layout/CardsRow/Card1/Frame, $Layout/CardsRow/Card2/Frame, $Layout/CardsRow/Card3/Frame, $Layout/CardsRow/Card4/Frame,
]
@onready var _glows: Array[Panel] = [
	$Layout/CardsRow/Card1/Glow, $Layout/CardsRow/Card2/Glow, $Layout/CardsRow/Card3/Glow, $Layout/CardsRow/Card4/Glow,
]
@onready var _tunnel_lines: Array[Control] = [
	$Layout/CardsRow/Card1/Frame/PortraitBg/Lines, $Layout/CardsRow/Card2/Frame/PortraitBg/Lines, $Layout/CardsRow/Card3/Frame/PortraitBg/Lines, $Layout/CardsRow/Card4/Frame/PortraitBg/Lines,
]
@onready var _portraits: Array[TextureRect] = [
	$Layout/CardsRow/Card1/Frame/Portrait, $Layout/CardsRow/Card2/Frame/Portrait, $Layout/CardsRow/Card3/Frame/Portrait, $Layout/CardsRow/Card4/Frame/Portrait,
]
@onready var _idle_previews: Array[TextureRect] = [
	$Layout/CardsRow/Card1/Frame/IdlePreview, $Layout/CardsRow/Card2/Frame/IdlePreview, $Layout/CardsRow/Card3/Frame/IdlePreview, $Layout/CardsRow/Card4/Frame/IdlePreview,
]
@onready var _name_labels: Array[Label] = [
	$Layout/CardsRow/Card1/Frame/NameLabel, $Layout/CardsRow/Card2/Frame/NameLabel, $Layout/CardsRow/Card3/Frame/NameLabel, $Layout/CardsRow/Card4/Frame/NameLabel,
]
@onready var _hit_buttons: Array[Button] = [
	$Layout/CardsRow/Card1/HitButton, $Layout/CardsRow/Card2/HitButton, $Layout/CardsRow/Card3/HitButton, $Layout/CardsRow/Card4/HitButton,
]

var _frame_styles: Array[StyleBoxFlat] = []
var _glow_styles: Array[StyleBoxFlat] = []
var _idle_atlases: Array[AtlasTexture] = []
var _idle_frame_widths: Array[float] = []
var _idle_timers: Array[float] = []
var _idle_frame_index: Array[int] = []
var _was_active: Array[bool] = [false, false, false, false]
## Frame count del idle sheet por card. Se usa para animar el preview
## (algunos packs traen 8 frames, otros 12 — swordman).
var _idle_frame_counts: Array[int] = []

var _glow_a_base := Vector2.ZERO
var _glow_b_base := Vector2.ZERO
var _confirmed := false
var _time := 0.0

func _ready() -> void:
	_build_background_glow()
	_glow_a_base = _glow_accent_a.position
	_glow_b_base = _glow_accent_b.position

	UITheme.style_label(_title, 40)
	UITheme.style_label(_hint, 15)
	_hint.modulate.a = 0.75

	UITheme.style_button(_back_button)
	_back_button.mouse_entered.connect(UITheme.pulse.bind(_back_button, 1.05, 0.08))
	_back_button.mouse_exited.connect(UITheme.pulse.bind(_back_button, 1.0, 0.08))
	_back_button.pressed.connect(_on_back_pressed)

	for i in range(CHARACTERS.size()):
		_setup_card(i)

	# Navegación con teclado/mando: izquierda/derecha saltan entre
	# las 3 cards, con wrap-around en los extremos.
	var count := _hit_buttons.size()
	for i in range(count):
		var prev := (i - 1 + count) % count
		var next := (i + 1) % count
		_hit_buttons[i].focus_neighbor_left = _hit_buttons[prev].get_path()
		_hit_buttons[i].focus_neighbor_right = _hit_buttons[next].get_path()

	_hit_buttons[0].grab_focus()

func _process(delta: float) -> void:
	_time += delta
	_animate_background()
	_animate_idle_previews(delta)
	for i in range(_hit_buttons.size()):
		var active := _hit_buttons[i].is_hovered() or _hit_buttons[i].has_focus()
		_update_card_glow(i, active)

func _unhandled_input(event: InputEvent) -> void:
	if not _confirmed and event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()

# ── Setup ────────────────────────────────────────────────────────

func _setup_card(i: int) -> void:
	var data: Dictionary = CHARACTERS[i]
	var accent: Color = data["accent"]

	# Los PNG tienen alpha real alrededor del personaje (no fondo
	# opaco), así que el túnel de neón dibujado detrás se ve completo.
	_tunnel_lines[i].set_accent(accent)
	_portraits[i].texture = load(data["portrait"])
	_name_labels[i].text = data["name"]
	UITheme.style_label(_name_labels[i], 30, true)

	var idle_tex: Texture2D = load(data["idle_sheet"])
	var frame_count: int = data.get("idle_frames", DEFAULT_IDLE_FRAME_COUNT)
	var frame_w := idle_tex.get_width() / float(frame_count)
	var atlas := AtlasTexture.new()
	atlas.atlas = idle_tex
	atlas.region = Rect2(0, 0, frame_w, idle_tex.get_height())
	_idle_previews[i].texture = atlas
	_idle_atlases.append(atlas)
	_idle_frame_widths.append(frame_w)
	_idle_frame_counts.append(frame_count)
	_idle_timers.append(randf() * 0.5)
	_idle_frame_index.append(0)

	var idle_style := UITheme.make_box(UITheme.COLOR_FILL, accent.darkened(0.4))
	_frames[i].add_theme_stylebox_override("panel", idle_style)
	_frame_styles.append(idle_style)

	var glow_style := StyleBoxFlat.new()
	glow_style.bg_color = Color(accent, 0.0)
	glow_style.border_color = Color(accent, 0.0)
	glow_style.set_border_width_all(6)
	glow_style.set_corner_radius_all(0)
	glow_style.anti_aliasing = false
	_glows[i].add_theme_stylebox_override("panel", glow_style)
	_glows[i].material = _shared_additive_material()
	_glow_styles.append(glow_style)

	_hit_buttons[i].mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_hit_buttons[i].pressed.connect(_on_card_selected.bind(i))
	# El botón sólo existe para capturar input; su propio stylebox no
	# se ve (el look lo dan Frame/Glow detrás).
	var invisible := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus"]:
		_hit_buttons[i].add_theme_stylebox_override(state, invisible)

# ── Fondo ────────────────────────────────────────────────────────

var _cached_glow_material: CanvasItemMaterial

func _shared_additive_material() -> CanvasItemMaterial:
	if _cached_glow_material == null:
		_cached_glow_material = CanvasItemMaterial.new()
		_cached_glow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _cached_glow_material

func _build_background_glow() -> void:
	_glow_base.texture = _make_radial_gradient(Color(0.35, 0.28, 0.55, 0.55))
	_glow_accent_a.texture = _make_radial_gradient(Color(1.0, 0.55, 0.25, 0.35))
	_glow_accent_b.texture = _make_radial_gradient(Color(0.3, 0.55, 1.0, 0.35))
	var mat := _shared_additive_material()
	_glow_base.material = mat
	_glow_accent_a.material = mat
	_glow_accent_b.material = mat

func _make_radial_gradient(center_color: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, center_color)
	gradient.set_color(1, Color(center_color, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 512
	tex.height = 512
	return tex

func _animate_background() -> void:
	_glow_accent_a.position = _glow_a_base + Vector2(sin(_time * 0.25) * 60.0, cos(_time * 0.2) * 30.0)
	_glow_accent_b.position = _glow_b_base + Vector2(cos(_time * 0.22) * 70.0, sin(_time * 0.18) * 40.0)
	_glow_base.modulate.a = 0.85 + 0.15 * sin(_time * 0.5)

# ── Idle preview ─────────────────────────────────────────────────

func _animate_idle_previews(delta: float) -> void:
	for i in range(_idle_atlases.size()):
		_idle_timers[i] += delta
		if _idle_timers[i] >= 1.0 / IDLE_FPS:
			_idle_timers[i] = 0.0
			_idle_frame_index[i] = (_idle_frame_index[i] + 1) % _idle_frame_counts[i]
			var atlas := _idle_atlases[i]
			var r := atlas.region
			r.position.x = _idle_frame_index[i] * _idle_frame_widths[i]
			atlas.region = r

# ── Marco brillante ──────────────────────────────────────────────

func _update_card_glow(i: int, active: bool) -> void:
	var frame_style := _frame_styles[i]
	var glow_style := _glow_styles[i]
	var accent: Color = CHARACTERS[i]["accent"]

	if active:
		var hue := fmod(_time * 0.35, 1.0)
		var glow_color := Color.from_hsv(hue, 0.75, 1.0)
		frame_style.border_color = glow_color
		frame_style.set_border_width_all(4)
		glow_style.border_color = Color(glow_color, 0.5 + 0.25 * sin(_time * 5.0))
	else:
		frame_style.border_color = accent.darkened(0.4)
		frame_style.set_border_width_all(3)
		glow_style.border_color = Color(accent, 0.0)

	if active != _was_active[i]:
		_was_active[i] = active
		UITheme.pulse(_card_roots[i], 1.04 if active else 1.0, 0.12)

# ── Selección ────────────────────────────────────────────────────

func _on_card_selected(i: int) -> void:
	if _confirmed:
		return
	_confirmed = true
	GameState.selected_character_id = CHARACTERS[i]["id"]

	for j in range(_card_roots.size()):
		_hit_buttons[j].disabled = true
		if j == i:
			create_tween().tween_property(_card_roots[j], "scale", Vector2.ONE * 1.1, 0.2)
		else:
			create_tween().tween_property(_card_roots[j], "modulate:a", 0.25, 0.2)

	get_tree().create_timer(0.45).timeout.connect(
		func(): get_tree().change_scene_to_file(GAME_SCENE)
	)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
