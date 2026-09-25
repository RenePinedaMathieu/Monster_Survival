extends Area2D

## Proyectil que disparan los monstruos a distancia (imps, beholders y
## el anillo de fuego de los jefes, ver monster.gd). Vuela recto y le
## pega al player una vez; no atraviesa. Esquivable: velocidad baja y
## bien visible (núcleo claro + halo del color del que lo tiró).

## 3.2 → 4.4: las velocidades de disparo bajaron x0.72 junto con el
## héroe (ver BASE_SPEED en player.gd); se alarga la vida en la misma
## proporción para que el alcance quede igual (~540 caster, ~475
## beholder, ~400 anillo del jefe) y la dificultad no baje.
const LIFE := 4.4
const RADIUS := 5.0

var _velocity: Vector2 = Vector2.ZERO
var _damage: float = 8.0
var _color: Color = Color("ff7a2e")
var _age: float = 0.0

func setup(pos: Vector2, dir: Vector2, speed: float, damage: float, color: Color) -> void:
	global_position = pos
	_velocity = dir * speed
	_damage = damage
	_color = color

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1   # el player
	monitorable = false
	z_index = 6
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	position += _velocity * delta
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var fade: float = 1.0 if _age < LIFE - 0.3 else (LIFE - _age) / 0.3
	var wobble: float = 1.0 + 0.15 * sin(_age * 18.0)
	draw_circle(Vector2.ZERO, RADIUS * 1.9 * wobble, Color(_color, 0.3 * fade))
	draw_circle(Vector2.ZERO, RADIUS * 1.1, Color(_color, fade))
	draw_circle(Vector2.ZERO, RADIUS * 0.5, Color(1.0, 0.95, 0.8, fade))

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(_damage)
		queue_free()
