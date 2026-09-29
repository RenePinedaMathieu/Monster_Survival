extends Node2D

const ORBIT_RADIUS := 62.0
const HIT_RADIUS := 18.0
const DAMAGE_BASE := 2.8
const DAMAGE_STEP := 0.45
const HIT_COOLDOWN := 0.38

var player = null
var level: int = 1
var _t: float = 0.0
var _hit_cd: Dictionary = {}

func setup(p) -> void:
	player = p
	z_index = 9

func set_level(l: int) -> void:
	level = clampi(l, 1, 8)

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or player.hp <= 0.0:
		return
	_t += delta
	for id in _hit_cd.keys():
		_hit_cd[id] -= delta
		if _hit_cd[id] <= 0.0:
			_hit_cd.erase(id)
	var dmg: float = (DAMAGE_BASE + DAMAGE_STEP * level) * player.damage_mult
	var r2 := HIT_RADIUS * HIT_RADIUS
	for m in get_tree().get_nodes_in_group("monster"):
		if not is_instance_valid(m):
			continue
		var id := m.get_instance_id()
		if _hit_cd.has(id):
			continue
		for i in range(level):
			if _saw_pos(i).distance_squared_to(m.global_position) <= r2:
				m.take_damage(dmg, "sierras")
				if m.has_method("knockback"):
					m.knockback((m.global_position - global_position).normalized(), 120.0)
				_hit_cd[id] = HIT_COOLDOWN
				break
	queue_redraw()

func _saw_pos(idx: int) -> Vector2:
	var count := maxi(1, level)
	var angle := -_t * 2.8 + TAU * idx / count
	return global_position + Vector2(cos(angle), sin(angle)) * ORBIT_RADIUS

func _draw() -> void:
	for i in range(level):
		var local := to_local(_saw_pos(i))
		draw_circle(local, HIT_RADIUS, Color(0.72, 0.76, 0.8, 0.85))
		draw_circle(local, 7.0, Color(0.18, 0.2, 0.24, 0.9))
		for tooth in range(8):
			var a := _t * 8.0 + TAU * tooth / 8.0
			var p1 := local + Vector2(cos(a), sin(a)) * 12.0
			var p2 := local + Vector2(cos(a + 0.18), sin(a + 0.18)) * 20.0
			draw_line(p1, p2, Color(0.95, 0.98, 1.0, 0.9), 2.0)
