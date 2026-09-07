extends CharacterBody2D

## Local player. WASD/flechas para moverse. El sprite cambia entre
## 8 direcciones (clockwise desde south) según hacia dónde vas. La
## cámara sigue al personaje (agregada como hija en player.tscn), y
## la posición se broadcasta al canal `world` para el multiplayer.

const SPEED := 200.0

# Nombres de las carpetas de sprites, en orden 0..7 clockwise
# desde south. Match con assets/sprites/Man/rotations/<name>.png.
const DIR_NAMES: Array[String] = [
	"south",       # 0
	"south-east",  # 1
	"east",        # 2
	"north-east",  # 3
	"north",       # 4
	"north-west",  # 5
	"west",        # 6
	"south-west",  # 7
]

var _textures: Array[Texture2D] = []
var current_dir: int = 0

@onready var _sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	# Precargamos las 8 direcciones a memoria — así el cambio de
	# textura en cada frame de movimiento no gatilla un disk read.
	for dir_name in DIR_NAMES:
		var t: Texture2D = load("res://assets/sprites/Man/rotations/" + dir_name + ".png")
		_textures.append(t)
	_apply_direction()

func _physics_process(_delta: float) -> void:
	var input := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down"),
	)
	if input != Vector2.ZERO:
		input = input.normalized()
		var new_dir := _vec_to_dir(input)
		if new_dir != current_dir:
			current_dir = new_dir
			_apply_direction()
	velocity = input * SPEED
	move_and_slide()
	# Broadcast solo si estás moviéndote — el Realtime lo throttlea
	# igual a 130ms, pero enviar frames "quieto" es puro ruido.
	if input != Vector2.ZERO:
		Realtime.send_move(position.x, position.y, 1, current_dir)

func _apply_direction() -> void:
	if current_dir < _textures.size():
		_sprite.texture = _textures[current_dir]

## Convierte un vector normalizado a índice 0..7 clockwise desde south.
## Godot 2D: +x = este, +y = sur (screen y-down). angle() da 0=+x,
## PI/2=+y. Rotamos la referencia para que south=0 y clockwise crezca.
func _vec_to_dir(v: Vector2) -> int:
	var angle := v.angle()               # -PI..PI, 0=+x
	var shifted := -angle + PI / 2.0     # ahora south=0, clockwise
	var normalized := fmod(shifted + TAU, TAU)  # 0..TAU
	return int(round(normalized / (PI / 4.0))) % 8
