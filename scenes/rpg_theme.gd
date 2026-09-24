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
