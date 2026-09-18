extends Area2D

## Proyectil moneda — se dispara desde el player con SPACE. Vuela
## en línea recta hasta pegarle a un monster o expirar. Detección
## de monsters vía Area2D con collision_mask = 2.

const SPEED := 460.0
const LIFETIME := 1.4
const DAMAGE := 2.0

var velocity: Vector2 = Vector2.ZERO
var _damage: float = DAMAGE
var _age: float = 0.0

func set_damage(d: float) -> void:
	_damage = d

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Spin visual mientras vuela
	create_tween().set_loops().tween_property($Sprite2D, "rotation",
		TAU, 0.5).from(0.0)

func setup(dir: Vector2) -> void:
	velocity = dir.normalized() * SPEED

func _process(delta: float) -> void:
	position += velocity * delta
	_age += delta
	if _age > LIFETIME:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(_damage)
		queue_free()
