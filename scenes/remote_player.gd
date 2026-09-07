extends Node2D

## Un jugador remoto — se instancia en main.gd cada vez que llega
## un remote_join de Realtime. La posición viene interpolada desde
## el último remote_move para que no salte cuando llega el paquete
## a 130ms de intervalo.

const DIR_NAMES: Array[String] = [
	"south", "south-east", "east", "north-east",
	"north", "north-west", "west", "south-west",
]

var uid: String = ""
var target_position: Vector2 = Vector2.ZERO
var current_dir: int = 0

var _textures: Array[Texture2D] = []

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _label: Label = $Label

func _ready() -> void:
	for dir_name in DIR_NAMES:
		var t: Texture2D = load("res://assets/sprites/Man/rotations/" + dir_name + ".png")
		_textures.append(t)

func setup(remote_uid: String, meta: Dictionary) -> void:
	uid = remote_uid
	_label.text = meta.get("name", "player")
	target_position = position

func apply_move(x: float, y: float, _facing: int, dir: int) -> void:
	target_position = Vector2(x, y)
	if dir != current_dir and dir >= 0 and dir < _textures.size():
		current_dir = dir
		_sprite.texture = _textures[dir]

func _process(delta: float) -> void:
	# Lerp suave hacia la última posición conocida — evita el
	# efecto "teleport" cada 130ms cuando llega un broadcast.
	position = position.lerp(target_position, min(1.0, delta * 12.0))
