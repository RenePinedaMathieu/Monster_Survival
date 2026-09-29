extends Node2D

## Lobo de SIRA (habilidad "Llamado del lobo", player.gd): aparece junto
## a ella, caza al enemigo más cercano durante LIFETIME segundos y se
## va. Sprites de 8 direcciones en assets/sprites/wolf (un PNG por
## frame, mismo formato que los de EDRIC y SIRA).

const BASE := "res://assets/sprites/wolf/"
const DIRS: Array[String] = ["south", "south-east", "east", "north-east", "north", "north-west", "west", "south-west"]
const LIFETIME := 10.0
const SPEED := 230.0
const HUNT_RADIUS := 420.0   # busca presas cerca de SIRA, no en todo el mapa
const BITE_RANGE := 24.0
const BITE_DAMAGE := 7.0
const BITE_EVERY := 0.55
const RUN_FPS := 12.0
const FADE := 0.35

var player = null
var _sprite: Sprite2D
var _run: Dictionary = {}
var _atk: Dictionary = {}
var _rest: Dictionary = {}
var _facing: String = "south"
var _t: float = 0.0
var _anim_t: float = 0.0
var _bite_cd: float = 0.0
var _biting: float = 0.0

func setup(p) -> void:
	player = p
	global_position = p.global_position + Vector2(-18, 6)
	for d in DIRS:
		_run[d] = _frames("animations/run/%s/frame_%03d.png", d)
		_atk[d] = _frames("animations/atk/%s/frame_%03d.png", d)
		_rest[d] = load(BASE + "rotations/%s.png" % d)
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Misma escala que EDRIC y SIRA (el Sprite2D del player en 0.5).
	_sprite.scale = Vector2.ONE * 0.5
	_sprite.texture = _rest["south"]
	add_child(_sprite)
	modulate.a = 0.0
	z_index = p.z_index

func _frames(pattern: String, dir: String) -> Array:
	var out: Array = []
	for i in range(16):
		var path: String = BASE + pattern % [dir, i]
		if not ResourceLoader.exists(path):
			break
		out.append(load(path))
	return out

func _process(delta: float) -> void:
	_t += delta
	modulate.a = clampf(minf(_t, LIFETIME - _t) / FADE, 0.0, 1.0)
	if _t >= LIFETIME or player == null or not is_instance_valid(player):
		queue_free()
		return
	_bite_cd -= delta
	_biting = maxf(0.0, _biting - delta)
	var target := _prey()
	var goal: Vector2 = target.global_position if target != null else player.global_position + Vector2(-26, 10)
	var to_goal: Vector2 = goal - global_position
	var dist: float = to_goal.length()
	if target != null and dist <= BITE_RANGE:
		if _bite_cd <= 0.0:
			_bite_cd = BITE_EVERY
			_biting = BITE_EVERY * 0.9
			target.take_damage(BITE_DAMAGE * player.damage_mult, "lobo")
		_face(to_goal)
	elif dist > 6.0 and (target != null or dist > 30.0):
		global_position += to_goal / dist * minf(SPEED * delta, dist)
		_face(to_goal)
	_animate(delta, dist > 6.0 and _biting <= 0.0 and (target != null or dist > 30.0))

func _prey() -> Node2D:
	var best: Node2D = null
	var best_d2 := HUNT_RADIUS * HUNT_RADIUS
	for m in get_tree().get_nodes_in_group("monster"):
		if not is_instance_valid(m) or m.is_queued_for_deletion():
			continue
		var d2: float = player.global_position.distance_squared_to(m.global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = m
	return best

func _face(v: Vector2) -> void:
	if v.length_squared() < 0.01:
		return
	var idx := int(round(fmod(-v.angle() + PI / 2.0 + TAU, TAU) / (PI / 4.0))) % 8
	_facing = DIRS[idx]

func _animate(delta: float, running: bool) -> void:
	_anim_t += delta
	var frames: Array = _atk[_facing] if _biting > 0.0 else (_run[_facing] if running else [])
	if frames.is_empty():
		_sprite.texture = _rest[_facing]
		return
	_sprite.texture = frames[int(_anim_t * RUN_FPS) % frames.size()]
