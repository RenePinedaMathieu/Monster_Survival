extends Area2D

const RADIUS := 58.0
const LIFE := 8.0
const BURN_DURATION := 5.0
const BURN_DPS_FRAC := 0.02

var _age: float = 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitorable = false
	z_index = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS * 0.82
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	queue_redraw()

func _on_body_entered(body: Node) -> void:
	if body.has_method("apply_burn"):
		body.apply_burn(BURN_DPS_FRAC, BURN_DURATION)

func _draw() -> void:
	var fade: float = clampf((LIFE - _age) / 1.2, 0.0, 1.0)
	var pulse: float = 1.0 + sin(_age * 8.0) * 0.04
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.58))
	draw_circle(Vector2.ZERO, RADIUS * pulse, Color(0.35, 0.04, 0.01, 0.72 * fade))
	draw_circle(Vector2.ZERO, RADIUS * 0.78, Color(1.0, 0.16, 0.02, 0.38 * fade))
	draw_arc(Vector2.ZERO, RADIUS * 0.9, 0.0, TAU, 36, Color(1.0, 0.65, 0.08, 0.85 * fade), 4.0, false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in range(7):
		var angle: float = TAU * i / 7.0 + _age * (0.3 if i % 2 == 0 else -0.25)
		var pos := Vector2(cos(angle) * 30.0, sin(angle) * 15.0)
		draw_circle(pos, 3.0 + sin(_age * 10.0 + i) * 1.2, Color(1.0, 0.72, 0.12, fade))
