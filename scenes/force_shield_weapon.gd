extends Node2D

const LEVELS: Array = [
	{"cooldown": 9.0},
	{"cooldown": 8.0},
	{"cooldown": 7.0},
	{"cooldown": 6.0},
	{"cooldown": 5.0},
]
const RADIUS := 30.0
## Evolución "Bastión" (escudo + Piel de hierro): 3 cargas, se recargan
## el doble de rápido y también paran golpes cuerpo a cuerpo.
const BASTION_CHARGES := 3

var player = null
var level: int = 1
var active: bool = false
var evolved: bool = false
var charges: int = 0
var _cd: float = 0.0
var _flash: float = 0.0

func setup(p) -> void:
	player = p
	show_behind_parent = false
	active = true
	charges = 1

func set_level(l: int) -> void:
	level = clampi(l, 1, LEVELS.size())
	_cd = minf(_cd, LEVELS[level - 1]["cooldown"])

func evolve() -> void:
	evolved = true
	charges = BASTION_CHARGES
	active = true

func _max_charges() -> int:
	return BASTION_CHARGES if evolved else 1

func _recharge_time() -> float:
	return LEVELS[level - 1]["cooldown"] * player.cooldown_mult * (0.5 if evolved else 1.0)

func block_projectile(_from_pos: Vector2) -> bool:
	if not active:
		return false
	charges -= 1
	active = charges > 0
	if _cd <= 0.0:
		_cd = _recharge_time()
	_flash = 0.25
	queue_redraw()
	return true

## Bastión: también para un golpe cuerpo a cuerpo (player.take_damage).
func absorb_hit() -> bool:
	return evolved and block_projectile(global_position)

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or player.hp <= 0.0:
		return
	if charges < _max_charges():
		_cd -= delta
		if _cd <= 0.0:
			charges += 1
			active = true
			if charges < _max_charges():
				_cd = _recharge_time()
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
	queue_redraw()

func _draw() -> void:
	if not active and _flash <= 0.0:
		return
	var a: float = 0.75 if active else _flash / 0.25
	var r: float = RADIUS + (1.0 - a) * 10.0
	# Bastión: dorado, un anillo más por cada carga extra.
	var fill := Color(1.0, 0.8, 0.35) if evolved else Color(0.35, 0.75, 1.0)
	var ring := Color(1.0, 0.92, 0.6) if evolved else Color(0.65, 0.95, 1.0)
	draw_circle(Vector2(0, -8), r, Color(fill, 0.12 * a))
	draw_arc(Vector2(0, -8), r, 0.0, TAU, 44, Color(ring, a), 2.5, false)
	if evolved:
		for i in range(1, charges):
			draw_arc(Vector2(0, -8), r + 5.0 * i, 0.0, TAU, 44, Color(ring, a * 0.7), 1.5, false)
