extends Node2D

const LASER_EFFECT_SCRIPT := preload("res://scenes/laser_effect.gd")

const LEVELS: Array = [
	{"cooldown": 2.4, "damage": 3.0},
	{"cooldown": 2.2, "damage": 3.6},
	{"cooldown": 2.0, "damage": 4.3},
	{"cooldown": 1.8, "damage": 5.2},
	{"cooldown": 1.6, "damage": 6.0},
]
const RANGE := 230.0
const BOUNCE_RANGE := 135.0
const TARGETS := 3
## Evolución "Cadena carmesí" (láser + Sed de sangre).
const CRIMSON_TARGETS := 6
const CRIMSON_HEAL := 0.5   # vida por enemigo golpeado

var player = null
var level: int = 1
var evolved: bool = false
var _cd: float = 0.6

func setup(p) -> void:
	player = p

func set_level(l: int) -> void:
	level = clampi(l, 1, LEVELS.size())

func evolve() -> void:
	evolved = true

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or player.hp <= 0.0:
		return
	_cd -= delta
	if _cd > 0.0:
		return
	if not _fire():
		_cd = 0.2
		return
	_cd = LEVELS[level - 1]["cooldown"] * player.cooldown_mult

func _fire() -> bool:
	var first := _nearest(player.global_position, RANGE, [])
	if first == null:
		return false
	var hit: Array = []
	var points: Array = [player.global_position + Vector2(0, -18)]
	var current: Node2D = first
	var targets: int = CRIMSON_TARGETS if evolved else TARGETS
	while current != null and hit.size() < targets:
		hit.append(current)
		points.append(current.global_position)
		current = _nearest(current.global_position, BOUNCE_RANGE, hit)
	var dmg: float = LEVELS[level - 1]["damage"] * player.damage_mult
	for m in hit:
		if is_instance_valid(m):
			m.take_damage(dmg, "cadena_carmesi" if evolved else "laser_cadena")
	if evolved:
		player.heal(CRIMSON_HEAL * hit.size())
	var fx := Node2D.new()
	fx.set_script(LASER_EFFECT_SCRIPT)
	get_tree().current_scene.add_child(fx)
	fx.setup(points, evolved)
	return true

func _nearest(from: Vector2, max_dist: float, exclude: Array) -> Node2D:
	var best: Node2D = null
	var best_d2 := max_dist * max_dist
	for m in get_tree().get_nodes_in_group("monster"):
		if not is_instance_valid(m) or m in exclude:
			continue
		var d2: float = from.distance_squared_to(m.global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = m
	return best
