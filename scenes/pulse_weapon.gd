extends Node2D

const LEVELS: Array = [
	{"cooldown": 3.2, "radius": 85.0, "damage": 3.0},
	{"cooldown": 3.0, "radius": 95.0, "damage": 3.8},
	{"cooldown": 2.8, "radius": 105.0, "damage": 4.6},
	{"cooldown": 2.6, "radius": 118.0, "damage": 5.4},
	{"cooldown": 2.4, "radius": 132.0, "damage": 6.2},
]
const EXPAND_TIME := 0.38
const WIDTH := 12.0
## Evolución "Terremoto" (pulso + Expansión): más grande, un segundo
## retumbe poco después y aturde a lo que toca.
const QUAKE_RADIUS_MULT := 1.35
const QUAKE_ECHO_DELAY := 0.22
const QUAKE_STUN := 0.6

var player = null
var level: int = 1
var evolved: bool = false
var _echo_t: float = -1.0
var _cd: float = 1.0
var _pulses: Array = []

func setup(p) -> void:
	player = p
	z_index = 430

func set_level(l: int) -> void:
	level = clampi(l, 1, LEVELS.size())

func evolve() -> void:
	evolved = true

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or player.hp <= 0.0:
		return
	_cd -= delta
	if _cd <= 0.0:
		_spawn_pulse()
		_cd = LEVELS[level - 1]["cooldown"] * player.cooldown_mult
		if evolved:
			_echo_t = QUAKE_ECHO_DELAY
	if _echo_t >= 0.0:
		_echo_t -= delta
		if _echo_t < 0.0:
			_spawn_pulse()
	for p in _pulses:
		p["age"] += delta
		_hit_pulse(p)
	_pulses = _pulses.filter(func(p): return p["age"] < EXPAND_TIME)
	queue_redraw()

func _spawn_pulse() -> void:
	var data: Dictionary = LEVELS[level - 1]
	_pulses.append({
		"center": player.global_position,
		"age": 0.0,
		"radius": data["radius"] * player.area_mult * (QUAKE_RADIUS_MULT if evolved else 1.0),
		"damage": data["damage"] * player.damage_mult,
		"hit": [],
	})

func _hit_pulse(p: Dictionary) -> void:
	var current_r: float = p["radius"] * clampf(p["age"] / EXPAND_TIME, 0.0, 1.0)
	for m in get_tree().get_nodes_in_group("monster"):
		if not is_instance_valid(m) or m.get_instance_id() in p["hit"]:
			continue
		var d: float = p["center"].distance_to(m.global_position)
		if d <= current_r and d >= maxf(0.0, current_r - WIDTH):
			var hit: Array = p["hit"]
			hit.append(m.get_instance_id())
			p["hit"] = hit
			m.take_damage(p["damage"], "terremoto" if evolved else "pulso")
			if evolved and m.has_method("apply_stun"):
				m.apply_stun(QUAKE_STUN * player.effect_duration_mult)
			if m.has_method("knockback"):
				m.knockback((m.global_position - p["center"]).normalized(), 160.0)

func _draw() -> void:
	for p in _pulses:
		var t: float = clampf(p["age"] / EXPAND_TIME, 0.0, 1.0)
		var r: float = p["radius"] * t
		var a: float = 1.0 - t
		# Terremoto: anillo ocre de tierra en vez del verde.
		var outer := Color(1.0, 0.78, 0.4) if evolved else Color(0.7, 1.0, 0.85)
		var inner := Color(0.75, 0.45, 0.15) if evolved else Color(0.25, 0.9, 0.7)
		draw_arc(p["center"] - global_position, r, 0.0, TAU, 64, Color(outer, 0.75 * a), 6.0 if evolved else 4.0, false)
		draw_arc(p["center"] - global_position, maxf(0.0, r - WIDTH), 0.0, TAU, 64, Color(inner, 0.28 * a), 2.0, false)
