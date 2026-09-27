extends Node2D

const BURNING_GROUND_SCRIPT := preload("res://scenes/burning_ground.gd")
const SPEED := 210.0

var _target: Vector2 = Vector2.ZERO
var _age: float = 0.0

func setup(from: Vector2, target_pos: Vector2) -> void:
	global_position = from
	_target = target_pos
	z_index = 8
	queue_redraw()

func _process(delta: float) -> void:
	_age += delta
	var to_target: Vector2 = _target - global_position
	var step: float = SPEED * delta
	if to_target.length() <= step:
		global_position = _target
		_impact()
		return
	global_position += to_target.normalized() * step
	queue_redraw()

func _impact() -> void:
	var ground := Area2D.new()
	ground.set_script(BURNING_GROUND_SCRIPT)
	get_tree().current_scene.add_child(ground)
	ground.global_position = _target
	queue_free()

func _draw() -> void:
	var target_local: Vector2 = to_local(_target)
	var telegraph: float = 0.55 + sin(_age * 9.0) * 0.2
	draw_set_transform(target_local, 0.0, Vector2(1.0, 0.58))
	draw_circle(Vector2.ZERO, 58.0, Color(1.0, 0.15, 0.02, 0.12))
	draw_arc(Vector2.ZERO, 58.0, 0.0, TAU, 36, Color(1.0, 0.45, 0.05, telegraph), 2.0, false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2.ZERO, 10.0, Color(1.0, 0.16, 0.02, 0.35))
	draw_circle(Vector2.ZERO, 6.0, Color(1.0, 0.55, 0.06))
	draw_circle(Vector2(-2, -2), 2.5, Color(1.0, 0.95, 0.65))
