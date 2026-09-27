extends Control

## Selección de personaje, estilo "versus screen" (Mega Man X5): 3
## recuadros con el retrato grande + un preview animado del sprite
## idle real de cada pack, en ventanas del pack de UI (rpg_theme.gd).
## Al pasar el mouse o mover el foco con teclado/mando, la carta se
## rodea de un aro verde que late; click/Enter confirma, apaga a los
## otros y pasa a la confirmación.
##
## La elección queda en GameState.selected_character_id. El gameplay
## (player.gd) todavía NO lee ese valor — cada pack en
## assets/main_characters/ tiene su propio set de direcciones/tamaño
## de frame, distinto entre sí y del sprite "Man" que usa el player
## hoy, así que conectar el skin real es trabajo aparte.

const UITheme := preload("res://scenes/ui_theme.gd")
const RpgTheme := preload("res://scenes/rpg_theme.gd")
const BACKGROUND_TEXTURE := "res://assets/layouts/background_home.png"
const COLOR_GLOW := Color("6ae356")

const CONFIRM_SCENE := "res://scenes/character_confirm.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"
const SHOP_SCENE := "res://scenes/shop_menu.tscn"

const DEFAULT_IDLE_FRAME_COUNT := 8   # fallback si el char no override
const IDLE_FPS := 7.0

## "role"/"blurb"/"stats" alimentan character_confirm.tscn (pantalla
## "holográfica" previa a arrancar la run) — no se usan en esta
## pantalla. "stats" es un rating manual del 1 al 5, no un valor
## calculado de player.gd — es sólo orientativo para el jugador.
const CHARACTERS: Array[Dictionary] = [
	{
		"id": "swordman",
		"name": "GAROTH",
		"portrait": "res://assets/main_characters/swordman_char.png",
		# Preview con lvl3 — el tier del medio, para que el jugador vea
		# a qué evoluciona (lvl1 se ve muy débil, lvl6 spoilería el
		# clímax visual).
		"idle_sheet": "res://assets/sprites/swordman/Swordsman_lvl3/Swordsman_lvl3_Idle/Swordsman_lvl3_Idle_front.png",
		"idle_frames": 12,
		"accent": Color("d4a648"),
		"role": "CUERPO A CUERPO · EVOLUTIVO",
		"blurb": "Empieza débil pero su sprite y su poder evolucionan con cada nivel — el más difícil al principio, el más gratificante al final.",
		"stats": {"Daño": 3, "Velocidad": 3, "Alcance": 1, "Dificultad": 4},
	},
	{
		"id": "main_char1",
		"name": "AXEL",
		"portrait": "res://assets/main_characters/main_char1_selectwindow.png",
		"idle_sheet": "res://assets/main_characters/main_char1/FREE_Adventurer 2D Pixel Art/Sprites/IDLE/idle_down.png",
		"accent": Color("ff6b57"),
		"role": "CUERPO A CUERPO",
		"blurb": "Espadachín ágil. Pega fuerte de cerca; puede sumar disparos a distancia con la carta correcta.",
		"stats": {"Daño": 4, "Velocidad": 3, "Alcance": 1, "Dificultad": 3},
	},
	{
		"id": "main_char2",
		"name": "KAY",
		"portrait": "res://assets/main_characters/main_char2_selectwindow.png",
		"idle_sheet": "res://assets/main_characters/main_char2/The Male adventurer - Free/Idle/idle_down.png",
		"accent": Color("7c8cff"),
		"role": "A DISTANCIA",
		"blurb": "Aventurero equilibrado. Dispara automáticamente a lo que se ve en pantalla — ideal para empezar.",
		"stats": {"Daño": 2, "Velocidad": 3, "Alcance": 4, "Dificultad": 2},
	},
	{
		"id": "main_char2_female",
		"name": "LINA",
		"portrait": "res://assets/main_characters/main_char2_female_selectwindow.png",
		"idle_sheet": "res://assets/main_characters/main_char2_female/The Female Adventurer - Free/Idle/Idle_Down.png",
		"accent": Color("ff6cc9"),
		"role": "A DISTANCIA",
		"blurb": "Tan letal como KAY pero más ligera de pies — prioriza esquivar por sobre plantarse a pelear.",
		"stats": {"Daño": 2, "Velocidad": 4, "Alcance": 4, "Dificultad": 2},
	},
]

@onready var _title: Label = $Layout/Title
@onready var _hint: Label = $Layout/Hint
@onready var _back_button: Button = $BackButton
@onready var _shop_button: Button = $ShopButton

## Una carta por personaje de CHARACTERS: la escena trae 4 y las que
## falten (el secreto) se clonan de la última en _build_cards().
var _card_roots: Array[Control] = []
var _frames: Array[Panel] = []
var _glows: Array[Panel] = []
var _tunnel_lines: Array[Control] = []
var _portraits: Array[TextureRect] = []
var _idle_previews: Array[TextureRect] = []
var _name_labels: Array[Label] = []
var _hit_buttons: Array[Button] = []
var _lock_hints: Array[Label] = []

var _glow_styles: Array[StyleBoxFlat] = []
var _idle_atlases: Array[AtlasTexture] = []
var _idle_frame_widths: Array[float] = []
var _idle_timers: Array[float] = []
var _idle_frame_index: Array[int] = []
var _was_active: Array[bool] = []
## Frame count del idle sheet por card. Se usa para animar el preview
## (algunos packs traen 8 frames, otros 12 — swordman).
var _idle_frame_counts: Array[int] = []

var _confirmed := false
var _time := 0.0

func _ready() -> void:
	Audio.play_music("character_select", 1000)
	$Background.texture = load(BACKGROUND_TEXTURE)

	RpgTheme.style_light_label(_title, 40)
	RpgTheme.style_light_label(_hint, 15)
	_hint.modulate.a = 0.85

	RpgTheme.style_button(_back_button, 20)
	_back_button.mouse_entered.connect(UITheme.pulse.bind(_back_button, 1.05, 0.08))
	_back_button.mouse_exited.connect(UITheme.pulse.bind(_back_button, 1.0, 0.08))
	_back_button.pressed.connect(_on_back_pressed)

	# La tienda también es accesible desde acá (antes sólo desde el
	# menú principal) — "para que se entienda bien" dónde conseguir
	# mejoras permanentes sin tener que volver atrás primero.
	RpgTheme.style_button(_shop_button, 20)
	_shop_button.mouse_entered.connect(UITheme.pulse.bind(_shop_button, 1.05, 0.08))
	_shop_button.mouse_exited.connect(UITheme.pulse.bind(_shop_button, 1.0, 0.08))
	_shop_button.pressed.connect(_on_shop_pressed)

	_build_cards()
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
	Screen.layout_changed.connect(_apply_layout)
	_apply_layout(Screen.compact)

func _build_cards() -> void:
	var row: GridContainer = $Layout/CardsRow
	while row.get_child_count() < CHARACTERS.size():
		row.add_child(row.get_child(row.get_child_count() - 1).duplicate())
	for card in row.get_children():
		_card_roots.append(card)
		_frames.append(card.get_node("Frame"))
		_glows.append(card.get_node("Glow"))
		_tunnel_lines.append(card.get_node("Frame/PortraitBg/Lines"))
		_portraits.append(card.get_node("Frame/Portrait"))
		_idle_previews.append(card.get_node("Frame/IdlePreview"))
		_name_labels.append(card.get_node("Frame/NameLabel"))
		_hit_buttons.append(card.get_node("HitButton"))
		_was_active.append(false)
		# Texto del candado: qué logro desbloquea al personaje.
		var hint := Label.new()
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hint.anchor_right = 1.0
		hint.visible = false
		card.get_node("Frame").add_child(hint)
		_lock_hints.append(hint)

## Teléfono: grilla de 2x2 con cartas más angostas, título más chico y
## más abajo (arriba van VOLVER/TIENDA) y la ayuda de teclado se cambia
## por una de toque. PC: 4 en fila como siempre. Teléfono horizontal
## ("short": poca altura): fila de PC pero con cartas más bajas y el
## título a la altura de los botones.
func _apply_layout(compact: bool) -> void:
	var grid: GridContainer = $Layout/CardsRow
	var n: int = _card_roots.size()
	var short: bool = not compact and Screen.view_size().y < 640.0
	# PC: todas en una fila. Teléfono: 2 columnas con 4 cartas, 3 con 5.
	grid.columns = (2 if n <= 4 else 3) if compact else n
	grid.add_theme_constant_override("h_separation", 16 if compact else (46 if n <= 4 else 16))
	var card_w: float = 250.0 if n <= 4 else 210.0
	if compact:
		card_w = 186.0 if n <= 4 else 148.0
	elif short:
		card_w = 200.0
	var card_h: float = 330.0 if compact else (370.0 if short else 400.0)
	# Retrato arriba y abajo la franja del preview / candado.
	var portrait_bottom: float = 236.0 if compact else card_h - 124.0
	# En vertical 2 filas de 400 no entran en la altura: cartas más bajas
	# y el retrato/preview reubicados adentro (sus offsets son absolutos).
	for i in range(_card_roots.size()):
		_card_roots[i].custom_minimum_size = Vector2(card_w, card_h)
		_name_labels[i].add_theme_font_size_override("font_size", 18 if compact and n > 4 else 24)
		_lock_hints[i].offset_left = 10.0
		_lock_hints[i].offset_right = -10.0
		_lock_hints[i].offset_top = portrait_bottom + 4.0
		_lock_hints[i].offset_bottom = card_h - 18.0
		_frames[i].get_node("PortraitBg").offset_bottom = portrait_bottom
		_portraits[i].offset_bottom = portrait_bottom
		_idle_previews[i].offset_top = portrait_bottom + 4.0
		_idle_previews[i].offset_bottom = card_h - 18.0
	var small: bool = compact or short
	var layout: VBoxContainer = $Layout
	layout.offset_left = 12.0 if compact else (24.0 if short else 48.0)
	layout.offset_right = -layout.offset_left
	layout.offset_top = 84.0 if compact else (14.0 if short else 32.0)
	layout.add_theme_constant_override("separation", 8 if small else 14)
	RpgTheme.style_light_label(_title, 28 if small else 40)
	_hint.text = "Toca un héroe para elegirlo" if Screen.is_phone \
		else "Flechas para elegir  ·  Enter / click para confirmar  ·  Esc para volver"
	for b in [_back_button, _shop_button]:
		RpgTheme.style_button(b, 16 if small else 20)
		b.offset_top = 14.0 if short else 26.0
		b.offset_bottom = b.offset_top + (42.0 if short else 50.0)
	_back_button.offset_right = _back_button.offset_left + (110.0 if small else 140.0)
	_shop_button.offset_left = _shop_button.offset_right - (110.0 if small else 140.0)

func _process(delta: float) -> void:
	_time += delta
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

	# El túnel de neón no va con el estilo pergamino del resto de la UI
	# — el retrato va sobre el fondo azul de los retratos del pack.
	_tunnel_lines[i].visible = false
	_portraits[i].texture = portrait_texture(data)
	_name_labels[i].text = data["name"]
	RpgTheme.style_light_label(_name_labels[i], 24)
	# Bloqueado: silueta oscura + qué logro lo desbloquea.
	if not GameState.is_character_unlocked(data["id"]):
		_portraits[i].modulate = Color(0.05, 0.05, 0.08, 0.9)
		_idle_previews[i].visible = false
		var hint: Label = _lock_hints[i]
		hint.text = "BLOQUEADO\n" + GameState.unlock_hint_for_character(data["id"])
		RpgTheme.style_ink_label(hint, 13, true)
		hint.visible = true

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

	_frames[i].add_theme_stylebox_override("panel", RpgTheme.window_box())

	var glow_style := StyleBoxFlat.new()
	glow_style.bg_color = Color(COLOR_GLOW, 0.0)
	glow_style.border_color = Color(COLOR_GLOW, 0.0)
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

var _cached_glow_material: CanvasItemMaterial

func _shared_additive_material() -> CanvasItemMaterial:
	if _cached_glow_material == null:
		_cached_glow_material = CanvasItemMaterial.new()
		_cached_glow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _cached_glow_material

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

## Aro verde que late alrededor de la carta activa (hover o foco).
func _update_card_glow(i: int, active: bool) -> void:
	var glow_style := _glow_styles[i]
	var alpha: float = 0.55 + 0.3 * sin(_time * 5.0) if active else 0.0
	glow_style.border_color = Color(COLOR_GLOW, alpha)

	if active != _was_active[i]:
		_was_active[i] = active
		UITheme.pulse(_card_roots[i], 1.04 if active else 1.0, 0.12)

# ── Selección ────────────────────────────────────────────────────

## Textura del retrato (con recorte si "portrait_region" lo pide).
static func portrait_texture(data: Dictionary) -> Texture2D:
	var tex: Texture2D = load(data["portrait"])
	if data.has("portrait_region"):
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = data["portrait_region"]
		return atlas
	return tex

func _on_card_selected(i: int) -> void:
	if _confirmed:
		return
	if not GameState.is_character_unlocked(CHARACTERS[i]["id"]):
		# Bloqueado: sacudón y nada más.
		Audio.play_sfx("player_hurt")
		var card := _card_roots[i]
		var x0: float = card.position.x
		var tw := create_tween()
		for dx in [8.0, -8.0, 5.0, -5.0, 0.0]:
			tw.tween_property(card, "position:x", x0 + dx, 0.04)
		return
	_confirmed = true
	GameState.selected_character_id = CHARACTERS[i]["id"]
	GameState.pending_character = CHARACTERS[i]

	for j in range(_card_roots.size()):
		_hit_buttons[j].disabled = true
		if j == i:
			create_tween().tween_property(_card_roots[j], "scale", Vector2.ONE * 1.1, 0.2)
		else:
			create_tween().tween_property(_card_roots[j], "modulate:a", 0.25, 0.2)

	# No arranca la partida directo — pasa por una pantalla de
	# confirmación con el retrato grande y las stats antes de meterse
	# de lleno a la horda (se sentía muy brusco elegir y arrancar).
	get_tree().create_timer(0.45).timeout.connect(
		func(): get_tree().change_scene_to_file(CONFIRM_SCENE)
	)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)

func _on_shop_pressed() -> void:
	GameState.shop_return_scene = "res://scenes/character_select.tscn"
	get_tree().change_scene_to_file(SHOP_SCENE)
