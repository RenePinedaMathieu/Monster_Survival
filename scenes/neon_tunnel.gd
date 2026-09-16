extends Control

## Líneas de un "túnel de neón": dibuja fugas desde las 4 esquinas
## hacia el centro + marcos concéntricos en el color de acento del
## personaje, encogiéndose en loop desde el borde hasta el centro
## para simular profundidad en movimiento. Blend aditivo para que
## brillen sobre el fondo azul oscuro (nodo hermano "Base") sin
## taparlo — por eso este nodo NO dibuja ningún fondo, sólo líneas.

const RING_COUNT := 5
const CYCLE_SECONDS := 5.5
const LINE_WIDTH := 1.6
const CORNER_LINE_ALPHA := 0.22
const RING_ALPHA := 0.5

var accent_color: Color = Color.CYAN
var _time := 0.0

func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func set_accent(color: Color) -> void:
	accent_color = color
	queue_redraw()

func _draw() -> void:
	var box := size
	var center := box / 2.0
	var neon := accent_color.lightened(0.2)

	var corners := [Vector2.ZERO, Vector2(box.x, 0.0), box, Vector2(0.0, box.y)]
	for corner in corners:
		draw_line(corner, center, Color(neon, CORNER_LINE_ALPHA), LINE_WIDTH, true)

	for i in range(RING_COUNT):
		var phase := fmod(_time / CYCLE_SECONDS + float(i) / RING_COUNT, 1.0)
		var t := 1.0 - phase
		var ring_size := box * t
		var ring_pos := center - ring_size / 2.0
		var alpha := RING_ALPHA * sin(t * PI)
		if alpha > 0.01:
			draw_rect(Rect2(ring_pos, ring_size), Color(neon, alpha), false, LINE_WIDTH, true)
