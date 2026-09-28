extends Node2D

const SHOT_SCENE := preload("res://scenes/shot_projectile.tscn")

const LEVELS: Array = [
	{"cooldown": 1.7, "damage": 2.0},
	{"cooldown": 1.55, "damage": 2.5},
	{"cooldown": 1.4, "damage": 3.0},
	{"cooldown": 1.25, "damage": 3.5},
	{"cooldown": 1.1, "damage": 4.0},
]
const RANGE := 3600.0
const FIRE_DPS_FRAC := 0.03
const FIRE_DURATION := 3.0
const ELECTRIC_STUN := 0.75
const ELECTRIC_RADIUS := 85.0
const ELECTRIC_CHANCE := 0.35
const FREEZE_DURATION := 1.1
## Evoluciones: Infierno (el fuego se contagia en este radio), Cero
## absoluto (congela el doble; el +50% de daño lo aplica monster.gd con
## GameState.run_shatter) y Sobrecarga (2 disparos, aturde siempre).
const INFERNO_RADIUS := 70.0
const OVERLOAD_SPREAD := 0.18

var player = null
var level: int = 1
var element: String = "fire"
var evolved: bool = false
var _cd: float = 0.5

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
	var target := _nearest_monster()
	if target == null:
		_cd = 0.2
		return
	var dir: Vector2 = (target.global_position - player.global_position).normalized()
	if evolved and element == "electric":
		_fire(dir.rotated(-OVERLOAD_SPREAD * 0.5))
		_fire(dir.rotated(OVERLOAD_SPREAD * 0.5))
	else:
		_fire(dir)
	_cd = LEVELS[level - 1]["cooldown"] / player.atk_speed_mult * player.cooldown_mult

func _fire(dir: Vector2) -> void:
	var data: Dictionary = LEVELS[level - 1]
	var shot = SHOT_SCENE.instantiate()
	get_tree().current_scene.add_child(shot)
	shot.global_position = player.global_position + dir * 24.0
	shot.set_damage(data["damage"] * player.damage_mult)
	var dur: float = player.effect_duration_mult
	match element:
		"fire":
			shot.source = "infierno" if evolved else "disparo_fuego"
			shot.set_effect("fire", FIRE_DURATION * dur, FIRE_DPS_FRAC, INFERNO_RADIUS * player.area_mult if evolved else 0.0)
			shot.setup(dir, false, 5)
		"electric":
			shot.source = "sobrecarga" if evolved else "disparo_electrico"
			shot.set_effect("electric", ELECTRIC_STUN * dur, 0.0, ELECTRIC_RADIUS * player.area_mult * (2.0 if evolved else 1.0),
				1.0 if evolved else ELECTRIC_CHANCE)
			shot.setup(dir, false, 2)
		"freeze":
			shot.source = "cero_absoluto" if evolved else "disparo_congelante"
			shot.set_effect("freeze", FREEZE_DURATION * dur * (2.0 if evolved else 1.0))
			shot.setup(dir, false, 0)

func _nearest_monster() -> Node2D:
	var best: Node2D = null
	var best_d2 := RANGE * RANGE
	for m in get_tree().get_nodes_in_group("monster"):
		if not is_instance_valid(m):
			continue
		var d2: float = player.global_position.distance_squared_to(m.global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = m
	return best
