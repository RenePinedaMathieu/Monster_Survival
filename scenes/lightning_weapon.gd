extends Node2D

## Arma "Rayo en cadena": cada tanto cae un rayo sobre el enemigo más
## cercano y salta a los que estén cerca de él. Evolución "Tormenta
## eléctrica" (rayo + velocidad): salta a 8 enemigos y cae dos veces.
## El dibujo del rayo es un nodo aparte que vive un instante en el
## mundo (bolt_effect.gd).

const BOLT_SCRIPT := preload("res://scenes/bolt_effect.gd")

## Por nivel: segundos entre rayos, cuántos enemigos toca, daño.
const LEVELS: Array = [
	{"cooldown": 2.0, "chain": 2, "damage": 6.0},
	{"cooldown": 1.8, "chain": 3, "damage": 7.0},
	{"cooldown": 1.6, "chain": 3, "damage": 8.5},
	{"cooldown": 1.4, "chain": 4, "damage": 10.0},
	{"cooldown": 1.2, "chain": 5, "damage": 12.0},
]
const RANGE := 300.0
const JUMP_RANGE := 110.0
const EVOLVED_CHAIN := 8
const SECOND_STRIKE_DELAY := 0.18

var player = null
var level: int = 1
var evolved: bool = false
var _cd: float = 1.0

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
	if not _strike():
		_cd = 0.2
		return
	_cd = LEVELS[level - 1]["cooldown"]
	if evolved:
		get_tree().create_timer(SECOND_STRIKE_DELAY).timeout.connect(_strike)

## Un rayo: arranca en el enemigo más cercano y salta al más cercano
## todavía no tocado. Devuelve false si no había a quién pegarle.
func _strike() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var data: Dictionary = LEVELS[level - 1]
	var chain: int = EVOLVED_CHAIN if evolved else data["chain"]
	var first := _nearest(player.global_position, RANGE, [])
	if first == null:
		return false
	var points: Array = [player.global_position + Vector2(0, -60)]
	var hit: Array = []
	var current: Node2D = first
	while current != null and hit.size() < chain:
		hit.append(current)
		points.append(current.global_position)
		current = _nearest(current.global_position, JUMP_RANGE, hit)
	var dmg: float = data["damage"] * player.damage_mult
	for m in hit:
		if is_instance_valid(m):
			m.take_damage(dmg, "tormenta_electrica" if evolved else "rayo")
	var bolt := Node2D.new()
	bolt.set_script(BOLT_SCRIPT)
	get_tree().current_scene.add_child(bolt)
	bolt.setup(points, evolved)
	return true

func _nearest(from: Vector2, max_dist: float, exclude: Array) -> Node2D:
	var best: Node2D = null
	var best_d2 := max_dist * max_dist
	for m in get_tree().get_nodes_in_group("monster"):
		if not is_instance_valid(m) or m in exclude:
			continue
		var d2 := from.distance_squared_to(m.global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = m
	return best
