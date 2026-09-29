extends Node2D

const SHOT_SCENE := preload("res://scenes/shot_projectile.tscn")

const RANGE := 3600.0
const ORBIT_RADIUS := 42.0
const FIRE_COOLDOWN := 1.15
const DAMAGE_BASE := 1.8
const DAMAGE_STEP := 0.55

var player = null
var level: int = 1
var _t: float = 0.0
var _cooldowns: Array[float] = []

func setup(p) -> void:
	player = p
	z_index = 8

func set_level(l: int) -> void:
	level = clampi(l, 1, 8)
	while _cooldowns.size() < level:
		_cooldowns.append(randf_range(0.0, FIRE_COOLDOWN))
	while _cooldowns.size() > level:
		_cooldowns.pop_back()

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or player.hp <= 0.0:
		return
	_t += delta
	for i in range(_cooldowns.size()):
		_cooldowns[i] -= delta
		if _cooldowns[i] <= 0.0:
			var target := _nearest_monster()
			if target == null:
				_cooldowns[i] = 0.25
				continue
			_fire_from(i, target)
			_cooldowns[i] = FIRE_COOLDOWN / player.atk_speed_mult
	queue_redraw()

func _fire_from(idx: int, target: Node2D) -> void:
	var pos := _drone_pos(idx)
	var dir: Vector2 = (target.global_position - pos).normalized()
	var shot = SHOT_SCENE.instantiate()
	get_tree().current_scene.add_child(shot)
	shot.global_position = pos + dir * 10.0
	shot.source = "centinela"
	shot.set_damage((DAMAGE_BASE + DAMAGE_STEP * level) * player.damage_mult)
	shot.setup(dir, false, mini(5, 1 + level / 2))

func _nearest_monster() -> Node2D:
	var best: Node2D = null
	var best_d2 := RANGE * RANGE
	for m in get_tree().get_nodes_in_group("monster"):
		if not is_instance_valid(m):
			continue
		var d2: float = global_position.distance_squared_to(m.global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = m
	return best

func _drone_pos(idx: int) -> Vector2:
	var count := maxi(1, level)
	var angle := _t * 1.8 + TAU * idx / count
	return global_position + Vector2(cos(angle), sin(angle)) * ORBIT_RADIUS

func _draw() -> void:
	for i in range(level):
		var local := to_local(_drone_pos(i))
		draw_circle(local, 6.0, Color(0.45, 0.9, 1.0, 0.95))
		draw_arc(local, 9.0, 0.0, TAU, 18, Color(0.85, 1.0, 1.0, 0.75), 1.5, false)
		draw_line(local + Vector2(-4, 0), local + Vector2(4, 0), Color(0.15, 0.35, 0.55), 1.4)
