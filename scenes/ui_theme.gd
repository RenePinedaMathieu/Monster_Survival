extends RefCounted

## Paleta y helpers de estilo compartidos entre pantallas de UI (menú
## principal, selección de personaje). Look pixel-art: bordes
## cuadrados sin antialiasing + outline grueso en el texto. Se usa
## vía preload, no class_name, para no depender de que el editor
## haya re-escaneado el proyecto todavía.

const COLOR_FILL         := Color("241812")
const COLOR_BORDER       := Color("e0a94c")
const COLOR_FILL_HOVER   := Color("3a2a1d")
const COLOR_BORDER_HOVER := Color("ffd873")
const COLOR_FILL_PRESSED := Color("140d09")
const COLOR_TEXT         := Color("f4e4c1")
const COLOR_TEXT_OUTLINE := Color("140d09")

## Como COLOR_FILL pero translúcido — para paneles de HUD que van
## encima del gameplay (a diferencia de menú/selección, acá no
## conviene tapar del todo lo que pasa detrás).
const COLOR_PANEL_BG := Color(0.141, 0.094, 0.071, 0.82)

static func make_box(fill: Color, border: Color, press_offset: float = 0.0, border_width: int = 3) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(0)
	box.anti_aliasing = false
	box.content_margin_left = 18.0
	box.content_margin_right = 18.0
	box.content_margin_top = 10.0 + press_offset
	box.content_margin_bottom = 10.0 - press_offset
	return box

static func style_button(button: Button, font_size: int = 26) -> void:
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", COLOR_TEXT)
	button.add_theme_color_override("font_pressed_color", COLOR_TEXT)
	button.add_theme_color_override("font_focus_color", COLOR_TEXT)
	button.add_theme_color_override("font_outline_color", COLOR_TEXT_OUTLINE)
	button.add_theme_constant_override("outline_size", 4)
	button.add_theme_stylebox_override("normal", make_box(COLOR_FILL, COLOR_BORDER))
	button.add_theme_stylebox_override("hover", make_box(COLOR_FILL_HOVER, COLOR_BORDER_HOVER))
	button.add_theme_stylebox_override("pressed", make_box(COLOR_FILL_PRESSED, COLOR_BORDER_HOVER, 3.0))
	button.add_theme_stylebox_override("focus", make_box(COLOR_FILL_HOVER, COLOR_BORDER_HOVER))

## Panel HUD estándar: fondo oscuro translúcido + borde dorado
## cuadrado, para PanelContainer (HP, XP, wave, timer, etc).
static func make_panel_box(border_width: int = 2) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = COLOR_PANEL_BG
	box.border_color = COLOR_BORDER
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(0)
	box.anti_aliasing = false
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 6.0
	box.content_margin_bottom = 6.0
	return box

## Estiliza un ProgressBar con bordes cuadrados sin antialiasing.
## Devuelve el StyleBoxFlat del relleno para que el caller pueda
## mutarle el color después (ej: la barra de HP cambia de verde a
## rojo según el % de vida).
static func style_progress_bar(bar: ProgressBar, fill_color: Color) -> StyleBoxFlat:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("140d09")
	bg.border_color = COLOR_BORDER
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(0)
	bg.anti_aliasing = false

	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(0)
	fill.anti_aliasing = false

	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	return fill

static func style_label(label: Label, font_size: int = 20, bold: bool = false) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", COLOR_TEXT)
	label.add_theme_color_override("font_outline_color", COLOR_TEXT_OUTLINE)
	label.add_theme_constant_override("outline_size", 4)
	if bold:
		label.add_theme_font_override("font", make_bold_font())

## No hay una fuente pixel-art dedicada en el proyecto todavía — para
## "negrita" usamos FontVariation.embolden sobre la fuente por
## defecto del engine en vez de sumar un asset de fuente nuevo.
static func make_bold_font(embolden: float = 0.9) -> FontVariation:
	var bold_font := FontVariation.new()
	bold_font.base_font = ThemeDB.fallback_font
	bold_font.variation_embolden = embolden
	return bold_font

## Pequeño "pop" de escala centrado en el propio pivote — usado para
## feedback de hover/focus en botones y cards.
static func pulse(control: Control, target_scale: float, duration: float = 0.08) -> void:
	control.pivot_offset = control.size / 2.0
	control.create_tween().tween_property(control, "scale", Vector2.ONE * target_scale, duration)
