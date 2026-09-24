extends RefCounted

## Estilo "pergamino + botones verdes" del pack Craftpix "Free Basic
## Pixel Art UI for RPG" (hojas originales en assets/ui/rpg_pack/).
## Las piezas que usamos están recortadas y escaladas x3 en
## assets/ui/rpg/ — escaladas de antemano porque StyleBoxTexture dibuja
## los bordes del 9-slice 1:1 en píxeles de textura, y a 1x la cabecera
## de la ventana quedaba de 14px. Los márgenes de abajo son los del
## pixel-art original x3 (medidos para que el centro estirado sea de
## un solo color y no se deformen las esquinas).
##
## Se usa vía preload, igual que ui_theme.gd.

const UITheme := preload("res://scenes/ui_theme.gd")
const DIR := "res://assets/ui/rpg/"

const COLOR_INK := Color("4a2a18")          # texto sobre pergamino
const COLOR_INK_SOFT := Color("7a5236")
const COLOR_INK_GOOD := Color("2f7a3e")
const COLOR_BTN_TEXT := Color("1b2e24")     # texto sobre botón verde
const COLOR_LIGHT_TEXT := Color("f4f0d8")   # texto sobre cabecera verde / slot oscuro
const COLOR_LIGHT_OUTLINE := Color("294040")
const COLOR_BAR_BG := Color("70492a")
const COLOR_BAR_BORDER := Color("3e1f1d")

static func _box(file: String, left: int, top: int, right: int, bottom: int) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = load(DIR + file)
	box.texture_margin_left = left
	box.texture_margin_top = top
	box.texture_margin_right = right
	box.texture_margin_bottom = bottom
	return box

## Ventana con cabecera verde (42px de alto a x3) y cuerpo pergamino.
static func window_box() -> StyleBoxTexture:
	return _box("window.png", 18, 48, 18, 15)

## Igual que window_box pero para PanelContainer cuyo primer hijo es un
## título de HEADER_HEIGHT de alto: el contenido arranca arriba de todo
## así ese título cae adentro de la cabecera verde.
const HEADER_HEIGHT := 42.0
static func window_box_titled(side: float = 24.0, bottom: float = 20.0) -> StyleBoxTexture:
	var box := window_box()
	box.content_margin_left = side
	box.content_margin_right = side
	box.content_margin_top = 0.0
	box.content_margin_bottom = bottom
	return box

## Tablón de madera (barra de acciones del pack) — paneles del HUD.
static func wood_box(margin_h: float = 14.0, margin_v: float = 10.0) -> StyleBoxTexture:
	var box := _box("wood.png", 9, 9, 9, 6)
	box.content_margin_left = margin_h
	box.content_margin_right = margin_h
	box.content_margin_top = margin_v
	box.content_margin_bottom = margin_v
	return box

## Placa verde chica (nivel del player en el HUD).
static func badge_box() -> StyleBoxTexture:
	var box := _box("btn_light.png", 9, 9, 9, 9)
	box.content_margin_left = 6.0
	box.content_margin_right = 6.0
	box.content_margin_top = 1.0
	box.content_margin_bottom = 4.0
	return box

## Título que va adentro de la cabecera verde de una ventana.
static func style_header_title(label: Label, font_size: int = 22) -> void:
	style_light_label(label, font_size)
	label.custom_minimum_size.y = HEADER_HEIGHT
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

## Carta de pergamino clickeable (level-up): aro verde en hover/foco.
static func style_card_button(button: Button, font_size: int = 17) -> void:
	var normal := _box("slot.png", 9, 9, 9, 9)
	var hover := _box("slot_hover.png", 9, 9, 9, 9)
	var pressed := _box("slot_hover.png", 9, 9, 9, 9)
	pressed.modulate_color = Color(0.9, 0.9, 0.9)
	for box in [normal, hover, pressed]:
		box.set_content_margin_all(16.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_font_override("font", UITheme.make_bold_font(0.5))
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(key, COLOR_INK)
	button.add_theme_constant_override("outline_size", 0)

static func style_slider(slider: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = COLOR_BAR_BG
	track.border_color = COLOR_BAR_BORDER
	track.set_border_width_all(2)
	track.content_margin_top = 5.0
	track.content_margin_bottom = 5.0
	track.anti_aliasing = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("57c767")
	fill.border_color = COLOR_BAR_BORDER
	fill.set_border_width_all(2)
	fill.anti_aliasing = false
	var grabber: Texture2D = load(DIR + "grabber.png")
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	slider.add_theme_icon_override("grabber", grabber)
	slider.add_theme_icon_override("grabber_highlight", grabber)
	slider.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

## CheckButton con las casillas del pack: verde = activado.
static func style_check(check: CheckButton, font_size: int = 16) -> void:
	var on: Texture2D = load(DIR + "check_on.png")
	var off: Texture2D = load(DIR + "check_off.png")
	for key in ["checked", "checked_mirrored", "checked_disabled", "checked_disabled_mirrored"]:
		check.add_theme_icon_override(key, on)
	for key in ["unchecked", "unchecked_mirrored", "unchecked_disabled", "unchecked_disabled_mirrored"]:
		check.add_theme_icon_override(key, off)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		check.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	check.add_theme_font_size_override("font_size", font_size)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		check.add_theme_color_override(key, COLOR_INK)

## Barra de 2 tonos como las llenas del pack (arriba claro, abajo
## oscuro). Sin fondo: la pista vacía la dibuja la textura de atrás.
static func style_track_bar(bar: ProgressBar, top: Color, bottom: Color) -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = top
	fill.border_color = bottom
	fill.border_width_bottom = 3
	fill.anti_aliasing = false
	bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	bar.add_theme_stylebox_override("fill", fill)
	bar.show_percentage = false

## Slot tan (tarjetas) o marrón oscuro (insignias de ícono, contadores).
static func slot_box(dark: bool = false, content_margin: float = 12.0) -> StyleBoxTexture:
	var box := _box("slot_dark.png" if dark else "slot.png", 9, 9, 9, 9)
	box.set_content_margin_all(content_margin)
	return box

static func _button_box(file: String, modulate: Color = Color.WHITE) -> StyleBoxTexture:
	var box := _box(file, 9, 9, 9, 9)
	box.modulate_color = modulate
	box.content_margin_left = 14.0
	box.content_margin_right = 14.0
	box.content_margin_top = 6.0
	box.content_margin_bottom = 10.0
	return box

static func style_button(button: Button, font_size: int = 16) -> void:
	button.add_theme_stylebox_override("normal", _button_box("btn_normal.png"))
	button.add_theme_stylebox_override("hover", _button_box("btn_hover.png"))
	button.add_theme_stylebox_override("pressed", _button_box("btn_pressed.png"))
	button.add_theme_stylebox_override("disabled", _button_box("btn_pressed.png", Color(0.62, 0.6, 0.56)))
	# El focus se dibuja ENCIMA del estado actual — vacío para que no
	# tape la textura (el hover ya marca dónde está el foco con mouse).
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_button_text(button, font_size)

## Pestaña: la seleccionada queda en verde claro "apretada".
static func style_tab(button: Button, selected: bool, font_size: int = 16) -> void:
	var normal := "btn_light.png" if selected else "btn_normal.png"
	button.add_theme_stylebox_override("normal", _button_box(normal))
	button.add_theme_stylebox_override("hover", _button_box("btn_light.png" if selected else "btn_hover.png"))
	button.add_theme_stylebox_override("pressed", _button_box("btn_light.png"))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_button_text(button, font_size)

static func _button_text(button: Button, font_size: int) -> void:
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_font_override("font", UITheme.make_bold_font(0.6))
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(key, COLOR_BTN_TEXT)
	button.add_theme_color_override("font_disabled_color", Color(COLOR_BTN_TEXT, 0.55))
	button.add_theme_constant_override("outline_size", 0)

static func style_ink_label(label: Label, font_size: int = 16, bold: bool = false, soft: bool = false) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", COLOR_INK_SOFT if soft else COLOR_INK)
	label.add_theme_constant_override("outline_size", 0)
	if bold:
		label.add_theme_font_override("font", UITheme.make_bold_font(0.6))

static func style_light_label(label: Label, font_size: int = 20) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", COLOR_LIGHT_TEXT)
	label.add_theme_color_override("font_outline_color", COLOR_LIGHT_OUTLINE)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_font_override("font", UITheme.make_bold_font(0.6))

static func style_level_bar(bar: ProgressBar, fill_color: Color) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = COLOR_BAR_BG
	bg.border_color = COLOR_BAR_BORDER
	bg.set_border_width_all(2)
	bg.anti_aliasing = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.border_color = COLOR_BAR_BORDER
	fill.set_border_width_all(2)
	fill.anti_aliasing = false
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
