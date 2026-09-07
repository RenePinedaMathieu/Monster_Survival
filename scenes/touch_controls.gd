extends CanvasLayer

## Joystick táctil dinámico estilo mobile survival:
##   - Cuando el dedo toca la MITAD IZQUIERDA de la pantalla, aparece
##     un joystick centrado en el punto donde tocaste.
##   - Al arrastrar, el knob sigue al dedo hasta MAX_RADIUS.
##   - Al soltar, el joystick se oculta y emite Vector2.ZERO.
##
## Ventaja del dinámico vs fijo: el usuario nunca tiene que "buscar"
## el joystick con el pulgar — aparece donde apoyó el dedo.
##
## No consume el touch de la mitad derecha (queda libre para futuro:
## botón de dash, mira, etc.).

signal move_input(v: Vector2)

const MAX_RADIUS := 90.0
const BASE_ALPHA := 0.35
const KNOB_ALPHA := 0.75
# Sólo capturamos touches en la mitad izquierda (0..0.5 del ancho)
const LEFT_ZONE_FRAC := 0.5

@onready var _base: Control = $Base
@onready var _knob: Control = $Base/Knob

var _active_touch: int = -1
var _origin: Vector2 = Vector2.ZERO

func _ready() -> void:
	# process_mode default → se pausa junto al juego, así el menú de
	# level up no recibe input fantasma.
	_base.visible = false

func _unhandled_input(event: InputEvent) -> void:
	var screen_w := get_viewport().get_visible_rect().size.x
	if event is InputEventScreenTouch:
		if event.pressed:
			# Un dedo a la vez; sólo aceptamos si estamos en la zona izq
			if _active_touch != -1: return
			if event.position.x > screen_w * LEFT_ZONE_FRAC: return
			_active_touch = event.index
			_origin = event.position
			_place_base_at(_origin)
			_place_knob(Vector2.ZERO)
			_base.visible = true
		else:
			if event.index != _active_touch: return
			_active_touch = -1
			_base.visible = false
			move_input.emit(Vector2.ZERO)
	elif event is InputEventScreenDrag:
		if event.index != _active_touch: return
		var delta: Vector2 = event.position - _origin
		var mag := delta.length()
		var clamped := delta
		if mag > MAX_RADIUS:
			clamped = delta.normalized() * MAX_RADIUS
		_place_knob(clamped)
		# Normalizado a -1..1 en cada eje
		move_input.emit(clamped / MAX_RADIUS)

func _place_base_at(pos: Vector2) -> void:
	# Base es un panel circular de 180x180; queremos que su centro
	# quede en pos.
	_base.position = pos - _base.size / 2.0

func _place_knob(offset: Vector2) -> void:
	_knob.position = _base.size / 2.0 - _knob.size / 2.0 + offset
