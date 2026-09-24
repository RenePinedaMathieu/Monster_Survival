extends Area2D

## Huevo que tira el pollo acompañante (companion.gd). Vuela recto
## girando sobre sí mismo y se rompe al pegarle a un monstruo.

const SPEED := 420.0
const LIFETIME := 1.2
const SPIN := 12.0

const COLOR_SHELL := Color("f4ecd8")
const COLOR_SHADE := Color("d8c9a3")
const COLOR_OUTLINE := Color("5a4632")

var _velocity: Vector2 = Vector2.ZERO
var _damage: float = 2.0
var _age: float = 0.0

func setup(dir: Vector2, damage: float) -> void:
	_velocity = dir * SPEED
	_damage = damage

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	position += _velocity * delta
	rotation += SPIN * delta
	_age += delta
	if _age > LIFETIME:
		queue_free()

func _draw() -> void:
	var pts := PackedVector2Array()
	for i in range(16):
		var a := TAU * i / 16.0
		pts.append(Vector2(cos(a) * 4.0, sin(a) * 5.0 - (1.0 if sin(a) < 0.0 else 0.0)))
	draw_colored_polygon(pts, COLOR_SHELL)
	draw_polyline(pts + PackedVector2Array([pts[0]]), COLOR_OUTLINE, 1.0)
	draw_circle(Vector2(1.2, 1.5), 1.6, COLOR_SHADE)

func _on_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(_damage)
		queue_free()
