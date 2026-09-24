extends Node2D

## Dibujo de un rayo del arma "Rayo en cadena": una línea quebrada que
## une los puntos (desde arriba del player y de enemigo en enemigo) y
## se apaga en LIFE segundos. Los quiebres se sortean una vez al crear.

const LIFE := 0.2
const SEGMENT := 14.0
const JITTER := 7.0
const COLOR_CORE := Color(0.95, 0.98, 1.0)
const COLOR_GLOW := Color(0.45, 0.75, 1.0)
const COLOR_GLOW_EVO := Color(1.0, 0.9, 0.35)

var _lines: Array = []   # Array[PackedVector2Array] en coordenadas globales
var _targets: Array = []
var _evolved: bool = false
var _t: float = 0.0

func setup(points: Array, evolved: bool) -> void:
	_evolved = evolved
	z_index = 460
	for i in range(points.size() - 1):
		_lines.append(_zigzag(points[i], points[i + 1]))
		_targets.append(points[i + 1])

func _zigzag(a: Vector2, b: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array([a])
	var steps: int = maxi(2, int(a.distance_to(b) / SEGMENT))
	var normal := (b - a).normalized().orthogonal()
	for s in range(1, steps):
		var p := a.lerp(b, float(s) / steps)
		pts.append(p + normal * randf_range(-JITTER, JITTER))
	pts.append(b)
	return pts

func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var a: float = 1.0 - _t / LIFE
	var glow: Color = COLOR_GLOW_EVO if _evolved else COLOR_GLOW
	for line in _lines:
		var local := PackedVector2Array()
		for p in line:
			local.append(p - global_position)
		draw_polyline(local, Color(glow, 0.6 * a), 5.0)
		draw_polyline(local, Color(COLOR_CORE, a), 2.0)
	for t in _targets:
		draw_circle(t - global_position, 7.0 * a + 2.0, Color(glow, 0.5 * a))
