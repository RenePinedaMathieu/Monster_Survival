extends Node

## Escala de UI según el dispositivo. El proyecto está diseñado a
## 1280x720 con stretch canvas_items + aspect expand; en un teléfono
## vertical eso deja un viewport lógico de 1280x~2800 — todo se ve
## diminuto y los paneles que se expanden quedan gigantes con el texto
## arriba de todo. Acá elegimos el tamaño base según el lado corto de
## la pantalla en píxeles CSS (lo que el ojo ve), así el texto queda
## legible en cualquier dispositivo:
##   teléfono (<600)  lado corto lógico 420
##   tablet   (<900)  lado corto lógico 640
##   PC               1280x720 como siempre
## "compact" = viewport lógico angosto (<700 de ancho): las pantallas
## lo usan para pasar a layouts de una columna (ver _apply_layout en
## cada una) y se re-emite al rotar el teléfono.

signal layout_changed(compact: bool)

const DESKTOP_SIZE := Vector2i(1280, 720)
const PHONE_SHORT := 420
const TABLET_SHORT := 640
const COMPACT_WIDTH := 700.0

var compact: bool = false
var portrait: bool = false
var is_phone: bool = false

func _ready() -> void:
	# Lo que no tapa ninguna escena (bordes en vertical, arriba/abajo del
	# fondo del menú) queda del marrón más oscuro del pack, no gris.
	RenderingServer.set_default_clear_color(Color("140d09"))
	get_tree().root.size_changed.connect(_apply)
	_apply()

func _apply() -> void:
	var win := Vector2(DisplayServer.window_get_size())
	var scale := DisplayServer.screen_get_scale()
	if scale <= 0.0:
		scale = 1.0
	var css := win / scale
	var short_side := minf(css.x, css.y)
	portrait = css.y > css.x
	is_phone = short_side < 600.0

	var size := DESKTOP_SIZE
	if is_phone or short_side < 900.0 or portrait:
		var base_short: int = PHONE_SHORT if is_phone else TABLET_SHORT
		var base_long: int = int(base_short * 16.0 / 9.0)
		size = Vector2i(base_short, base_long) if portrait else Vector2i(base_long, base_short)
	var root := get_tree().root
	if root.content_scale_size != size:
		root.content_scale_size = size

	compact = root.get_visible_rect().size.x < COMPACT_WIDTH
	layout_changed.emit(compact)

## Tamaño lógico actual del viewport (lo que miden los layouts).
func view_size() -> Vector2:
	return get_tree().root.get_visible_rect().size
