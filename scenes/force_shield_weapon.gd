extends Node2D

const LEVELS: Array = [
	{"cooldown": 9.0},
	{"cooldown": 8.0},
	{"cooldown": 7.0},
	{"cooldown": 6.0},
	{"cooldown": 5.0},
]
const RADIUS := 30.0

var player = null
var level: int = 1
var active: bool = false
var _cd: float = 0.0
var _flash: float = 0.0

func setup(p) -> void:
	player = p
	show_behind_parent = false
	active = true

func set_level(l: int) -> void:
	level = clampi(l, 1, LEVELS.size())
	_cd = minf(_cd, LEVELS[level - 1]["cooldown"])

func block_projectile(_from_pos: Vector2) -> bool:
	if not active:
		return false
	active = false
	_cd = LEVELS[level - 1]["cooldown"]
	_flash = 0.25
	queue_redraw()
	return true

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or player.hp <= 0.0:
		return
	if not active:
		_cd -= delta
		if _cd <= 0.0:
			active = true
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
	queue_redraw()

func _draw() -> void:
	if not active and _flash <= 0.0:
		return
	var a: float = 0.75 if active else _flash / 0.25
	var r: float = RADIUS + (1.0 - a) * 10.0
	draw_circle(Vector2(0, -8), r, Color(0.35, 0.75, 1.0, 0.12 * a))
	draw_arc(Vector2(0, -8), r, 0.0, TAU, 44, Color(0.65, 0.95, 1.0, a), 2.5, false)
