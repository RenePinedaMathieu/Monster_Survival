extends Node2D

## Sandbox de exploración del mapa. Sólo World + Player, sin waves,
## sin monsters, sin auth, sin HUD. La cámara del player se abre para
## que veas más del mapa mientras caminás (0.7× en vez del 1.5×/2.4×
## de gameplay).
##
## Corré con F6 sobre scenes/sandbox.tscn. Ideal para iterar el mapa
## sin la presión de las oleadas.
##
## Movimiento: WASD/flechas. Q/E para zoomear si querés ver más chico
## o más grande. R para volver al centro del mundo.

const SANDBOX_ZOOM := Vector2(2.0, 2.0)   # cerca del personaje por default
const ZOOM_MIN := Vector2(0.3, 0.3)       # alejar hasta ver ~medio mundo
const ZOOM_MAX := Vector2(4.0, 4.0)
const ZOOM_STEP := 0.06

@onready var _player: CharacterBody2D = $Player
@onready var _camera: Camera2D = $Player/Camera2D

func _ready() -> void:
	# Se corre DESPUÉS del _ready del Player, así el override del zoom
	# le gana a _apply_camera_zoom_for_device().
	_camera.zoom = SANDBOX_ZOOM
	# CRÍTICO: forzar que la cámara del player sea la current — sino la
	# PreviewCamera del world.tscn (zoom 0.35 para vista completa)
	# le gana y ves todo chiquito.
	_camera.make_current()
	print("[sandbox] WASD para mover · Q/E zoom · R centrar")

func _process(_delta: float) -> void:
	if Input.is_key_pressed(KEY_Q):
		_camera.zoom = _camera.zoom.max(ZOOM_MIN) - Vector2(ZOOM_STEP, ZOOM_STEP)
		_camera.zoom = _camera.zoom.max(ZOOM_MIN)
	if Input.is_key_pressed(KEY_E):
		_camera.zoom = _camera.zoom + Vector2(ZOOM_STEP, ZOOM_STEP)
		_camera.zoom = _camera.zoom.min(ZOOM_MAX)
	if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_R):
		_player.position = Vector2.ZERO
