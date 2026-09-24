extends Node2D

## Arma "Hacha giratoria": cada tanto lanza hachas hacia los enemigos
## más cercanos; salen, frenan y vuelven al player atravesando todo lo
## que tocan (ver axe_projectile.gd). Evolución "Torbellino" (hacha +
## daño): deja de lanzar y pasa a tener 4 hachas girando sin parar
## alrededor del player.

const AXE_SCRIPT := preload("res://scenes/axe_projectile.gd")

## Por nivel: segundos entre tandas, hachas por tanda, daño por golpe.
const LEVELS: Array = [
	{"cooldown": 2.2, "count": 1, "damage": 5.0},
	{"cooldown": 2.0, "count": 1, "damage": 6.0},
	{"cooldown": 1.8, "count": 2, "damage": 7.0},
	{"cooldown": 1.6, "count": 2, "damage": 8.5},
	{"cooldown": 1.4, "count": 3, "damage": 10.0},
]
const THROW_RANGE := 260.0
const ORBIT_COUNT := 4
const ORBIT_DAMAGE := 9.0

var player = null
var level: int = 1
var evolved: bool = false
var _cd: float = 0.8
var _orbiters: Array = []

func setup(p) -> void:
	player = p

func set_level(l: int) -> void:
	level = clampi(l, 1, LEVELS.size())

func evolve() -> void:
	evolved = true
	for i in range(ORBIT_COUNT):
		var axe := _make_axe()
		axe.start_orbit(player, TAU * i / ORBIT_COUNT, ORBIT_DAMAGE * player.damage_mult)
		_orbiters.append(axe)

func _process(delta: float) -> void:
	if evolved or player == null or not is_instance_valid(player) or player.hp <= 0.0:
		return
	_cd -= delta
	if _cd > 0.0:
		return
	var data: Dictionary = LEVELS[level - 1]
	var targets := _nearest_monsters(data["count"])
	if targets.is_empty():
		_cd = 0.2
		return
	_cd = data["cooldown"]
	for i in range(data["count"]):
		var target: Node2D = targets[i % targets.size()]
		var dir: Vector2 = (target.global_position - player.global_position).normalized()
		# Si hay menos blancos que hachas, abrimos el ángulo para que no
		# salgan todas superpuestas.
		if i >= targets.size():
			dir = dir.rotated(0.35 * (1 if i % 2 == 0 else -1))
		var axe := _make_axe()
		axe.start_throw(player, dir, data["damage"] * player.damage_mult)

func _make_axe() -> Area2D:
	var axe := Area2D.new()
	axe.set_script(AXE_SCRIPT)
	axe.collision_layer = 0
	axe.collision_mask = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 11.0
	shape.shape = circle
	axe.add_child(shape)
	get_tree().current_scene.add_child(axe)
	return axe

func _nearest_monsters(n: int) -> Array:
	var list: Array = []
	for m in get_tree().get_nodes_in_group("monster"):
		if is_instance_valid(m):
			var d: float = player.global_position.distance_to(m.global_position)
			if d <= THROW_RANGE:
				list.append([d, m])
	list.sort_custom(func(a, b): return a[0] < b[0])
	var out: Array = []
	for i in range(mini(n, list.size())):
		out.append(list[i][1])
	return out

func _exit_tree() -> void:
	for axe in _orbiters:
		if is_instance_valid(axe):
			axe.queue_free()
