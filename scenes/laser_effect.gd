extends Node2D

const LIFE := 0.16
const COLOR_CORE := Color(1.0, 0.96, 0.9)
const COLOR_GLOW := Color(1.0, 0.25, 0.18)

const CRIMSON_CORE := Color(1.0, 0.62, 0.68)
const CRIMSON_GLOW := Color(0.7, 0.0, 0.12)

var _points: Array = []
var _t: float = 0.0
var _core: Color = COLOR_CORE
var _glow: Color = COLOR_GLOW
var _width: float = 7.0

## crimson: evolución "Cadena carmesí" — más gruesa y rojo sangre.
func setup(points: Array, crimson: bool = false) -> void:
	_points = points.duplicate()
	z_index = 470
	if crimson:
		_core = CRIMSON_CORE
		_glow = CRIMSON_GLOW
		_width = 10.0

func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	if _points.size() < 2:
		return
	var a: float = 1.0 - _t / LIFE
	for i in range(_points.size() - 1):
		var from: Vector2 = _points[i] - global_position
		var to: Vector2 = _points[i + 1] - global_position
		draw_line(from, to, Color(_glow, 0.55 * a), _width, false)
		draw_line(from, to, Color(_core, a), 2.0, false)
		draw_circle(to, 5.0 + 4.0 * a, Color(_glow, 0.45 * a))
