extends Node2D

const LEVELS: Array = [
	{"radius": 68.0, "factor": 0.72},
	{"radius": 76.0, "factor": 0.66},
	{"radius": 84.0, "factor": 0.60},
	{"radius": 92.0, "factor": 0.55},
	{"radius": 102.0, "factor": 0.50},
]
const APPLY_INTERVAL := 0.25
const SLOW_DURATION := 0.55

var player = null
var level: int = 1
var _cd: float = 0.0
var _t: float = 0.0
var _pulse: float = 0.0

func setup(p) -> void:
	player = p
	show_behind_parent = true

func set_level(l: int) -> void:
	level = clampi(l, 1, LEVELS.size())

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or player.hp <= 0.0:
		return
	_t += delta
	_pulse = maxf(0.0, _pulse - delta * 2.8)
	_cd -= delta
	if _cd <= 0.0:
		_cd = APPLY_INTERVAL
		var data: Dictionary = LEVELS[level - 1]
		var r2: float = data["radius"] * data["radius"]
		var touched := false
		for m in get_tree().get_nodes_in_group("monster"):
			if is_instance_valid(m) and global_position.distance_squared_to(m.global_position) <= r2:
				if m.has_method("apply_slow"):
					m.apply_slow(data["factor"], SLOW_DURATION)
					touched = true
		if touched:
			_pulse = 1.0
	queue_redraw()

func _draw() -> void:
	var data: Dictionary = LEVELS[level - 1]
	var r: float = data["radius"] * (1.0 + 0.025 * sin(_t * 3.0))
	draw_circle(Vector2.ZERO, r, Color(0.35, 0.75, 1.0, 0.10 + 0.05 * _pulse))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(0.58, 0.9, 1.0, 0.42 + 0.25 * _pulse), 2.0, false)
	draw_arc(Vector2.ZERO, r * 0.72, -_t, -_t + TAU * 0.72, 36, Color(0.9, 1.0, 1.0, 0.28), 1.4, false)
