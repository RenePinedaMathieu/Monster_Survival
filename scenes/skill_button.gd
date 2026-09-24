extends Button

## Botón redondo de la habilidad activa (HUD). Muestra el ícono, y en
## recarga un abanico oscuro que se va abriendo con los segundos que
## faltan; lista = aro verde. Se toca en el teléfono o se usa ESPACIO.

const COLOR_RING := Color("3e1f1d")
const COLOR_WOOD := Color("70492a")
const COLOR_READY := Color("6ae356")
const COLOR_SHADE := Color(0, 0, 0, 0.62)

var _icon: Texture2D
var _ratio: float = 0.0       # 0 = lista, 1 = recién usada
var _remaining: float = 0.0
var _pulse: float = 0.0

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE   # si no, ESPACIO también lo "aprieta"
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())

func setup(icon_tex: Texture2D, hint: String) -> void:
	_icon = icon_tex
	tooltip_text = hint
	queue_redraw()

func set_cooldown(remaining: float, total: float) -> void:
	var was_ready: bool = _ratio <= 0.0
	_remaining = remaining
	_ratio = clampf(remaining / total, 0.0, 1.0) if total > 0.0 else 0.0
	if _ratio <= 0.0 and not was_ready:
		_pulse = 1.0   # destello al volver a estar lista
	queue_redraw()

func _process(delta: float) -> void:
	if _pulse > 0.0:
		_pulse = maxf(0.0, _pulse - delta * 2.5)
		queue_redraw()

func _draw() -> void:
	var c := size / 2.0
	var r: float = minf(size.x, size.y) / 2.0
	draw_circle(c, r, COLOR_RING)
	draw_circle(c, r - 3.0, COLOR_WOOD)
	if _icon != null:
		var side: float = (r - 6.0) * 1.42
		draw_texture_rect(_icon, Rect2(c - Vector2(side, side) / 2.0, Vector2(side, side)), false)
	if _ratio > 0.0:
		var pts := PackedVector2Array([c])
		var steps := 32
		for i in range(steps + 1):
			var a: float = -PI / 2.0 + TAU * _ratio * i / steps
			pts.append(c + Vector2(cos(a), sin(a)) * (r - 3.0))
		draw_colored_polygon(pts, COLOR_SHADE)
		var font := ThemeDB.fallback_font
		var txt := str(ceili(_remaining))
		var fs := int(r * 0.7)
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p := c + Vector2(-w / 2.0, fs * 0.35)
		draw_string_outline(font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, COLOR_RING)
		draw_string(font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	else:
		draw_arc(c, r - 1.5, 0.0, TAU, 40, Color(COLOR_READY, 0.9), 3.0, false)
		if _pulse > 0.0:
			draw_arc(c, r + 4.0 * (1.0 - _pulse), 0.0, TAU, 40, Color(COLOR_READY, _pulse), 3.0, false)
