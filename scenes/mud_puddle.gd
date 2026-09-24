extends Area2D

## Charco de lodo del Pantano (painted_world.gd): mientras el player
## está adentro camina a 60% (ver player._terrain_mult). Se dibuja como
## una mancha oscura con burbujas que suben.

var radius: float = 50.0
var _t: float = 0.0
var _bubbles: Array = []

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1   # el player
	monitorable = false
	z_index = -1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius * 0.8
	shape.shape = circle
	add_child(shape)
	body_entered.connect(func(b): if b.has_method("enter_mud"): b.enter_mud())
	body_exited.connect(func(b): if b.has_method("exit_mud"): b.exit_mud())
	_t = randf() * 5.0

func _process(delta: float) -> void:
	_t += delta
	if randf() < delta * 1.5:
		_bubbles.append({"pos": Vector2(randf_range(-radius, radius) * 0.6, randf_range(-radius, radius) * 0.3), "age": 0.0})
	for b in _bubbles:
		b["age"] += delta
	_bubbles = _bubbles.filter(func(b): return b["age"] < 0.8)
	queue_redraw()

func _draw() -> void:
	# Elipse aplanada (perspectiva top-down) con borde más claro.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
	draw_circle(Vector2.ZERO, radius, Color(0.2, 0.17, 0.1, 0.72))
	draw_circle(Vector2.ZERO, radius * 0.72, Color(0.14, 0.12, 0.07, 0.78))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0.38, 0.33, 0.2, 0.7), 3.0, false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for b in _bubbles:
		var a: float = 1.0 - b["age"] / 0.8
		draw_arc(b["pos"] + Vector2(0, -b["age"] * 6.0), 2.0 + b["age"] * 3.0, 0.0, TAU, 10, Color(0.5, 0.45, 0.3, a), 1.0, false)
