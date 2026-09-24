extends Node2D

## Acompañante comprado en la tienda (GameState.equipped_companion).
## player.gd lo crea al arrancar la run: sigue al player a un costado
## (del lado contrario a donde camina, para no taparle el paso) y cada
## fire_interval le tira un huevo al monstruo más cercano en rango.
##
## Sprites: hojas horizontales de 6 frames 32x32 por dirección,
## exportadas de los .aseprite de assets/sprites/<Nombre>/.

const EGG_SCRIPT := preload("res://scenes/egg_projectile.gd")

const DATA: Dictionary = {
	"chicken": {
		"base": "res://assets/sprites/Chicken/", "prefix": "Chicken",
		"frame": 32, "fps": 10.0, "scale": 1.4,
		"fire_interval": 1.1, "range": 320.0, "damage": 2.0,
	},
}
const DIRS := ["front", "back", "left", "right"]
const FOLLOW_OFFSET := Vector2(30.0, 12.0)
const FOLLOW_LERP := 6.0
const WALK_SPEED_MIN := 12.0
const TELEPORT_DIST := 400.0

var player = null   # sin tipo: mismo motivo que _swords_rig en player.gd
var _data: Dictionary
var _sprite: Sprite2D
var _anims: Dictionary = {}   # "Idle"/"Walk" -> dir -> Array[Texture2D]
var _facing: String = "front"
var _frame: int = 0
var _anim_t: float = 0.0
var _fire_cd: float = 0.6
var _side: float = -1.0
var _last_pos: Vector2

func setup(p, id: String) -> void:
	player = p
	_data = DATA[id]
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2.ONE * float(_data["scale"])
	add_child(_sprite)
	for anim in ["Idle", "Walk"]:
		var per_dir: Dictionary = {}
		for dir in DIRS:
			var path: String = "%s%s/%s_%s_%s.png" % [_data["base"], anim, _data["prefix"], dir, anim]
			per_dir[dir] = _slice(load(path), int(_data["frame"]))
		_anims[anim] = per_dir
	global_position = player.global_position + Vector2(FOLLOW_OFFSET.x * _side, FOLLOW_OFFSET.y)
	_last_pos = global_position
	_sprite.texture = _anims["Idle"][_facing][0]

func _slice(tex: Texture2D, size: int) -> Array:
	var frames: Array = []
	for i in range(floori(float(tex.get_width()) / size)):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * size, 0, size, size)
		frames.append(at)
	return frames

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or player.hp <= 0.0:
		return

	if player.velocity.x > 5.0:
		_side = -1.0
	elif player.velocity.x < -5.0:
		_side = 1.0
	var target: Vector2 = player.global_position + Vector2(FOLLOW_OFFSET.x * _side, FOLLOW_OFFSET.y)
	if global_position.distance_to(target) > TELEPORT_DIST:
		global_position = target
	else:
		global_position = global_position.lerp(target, FOLLOW_LERP * delta)

	var vel: Vector2 = (global_position - _last_pos) / max(delta, 0.0001)
	_last_pos = global_position
	var walking: bool = vel.length() > WALK_SPEED_MIN
	if walking:
		_facing = _dir_key(vel)
	_animate(delta, "Walk" if walking else "Idle")

	_fire_cd -= delta
	if _fire_cd <= 0.0:
		_try_fire()

func _animate(delta: float, anim: String) -> void:
	var frames: Array = _anims[anim][_facing]
	_anim_t += delta
	if _anim_t >= 1.0 / float(_data["fps"]):
		_anim_t = 0.0
		_frame = (_frame + 1) % frames.size()
	_sprite.texture = frames[_frame % frames.size()]

func _dir_key(v: Vector2) -> String:
	if abs(v.x) > abs(v.y):
		return "right" if v.x > 0.0 else "left"
	return "front" if v.y > 0.0 else "back"

func _try_fire() -> void:
	var best: Node2D = null
	var best_d2: float = float(_data["range"]) * float(_data["range"])
	for m in get_tree().get_nodes_in_group("monster"):
		if not is_instance_valid(m):
			continue
		var d2: float = global_position.distance_squared_to(m.global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = m
	if best == null:
		_fire_cd = 0.2
		return
	_fire_cd = float(_data["fire_interval"])
	var dir: Vector2 = (best.global_position - global_position).normalized()
	_facing = _dir_key(dir)

	var egg = Area2D.new()
	egg.set_script(EGG_SCRIPT)
	egg.collision_layer = 0
	egg.collision_mask = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5.0
	shape.shape = circle
	egg.add_child(shape)
	get_tree().current_scene.add_child(egg)
	egg.global_position = global_position + dir * 10.0
	# Escala con las mejoras de daño de la run (cartas + tienda).
	egg.setup(dir, float(_data["damage"]) * player.damage_mult * (2.0 if _golden else 1.0))
	if _golden:
		egg.make_golden()

## Evolución "Gallina dorada" (pollo + regeneración): huevos de oro —
## doble daño, más seguido y +1 moneda por cada golpe.
var _golden: bool = false

func evolve() -> void:
	_golden = true
	_data = _data.duplicate()
	_data["fire_interval"] = float(_data["fire_interval"]) * 0.7
	_sprite.modulate = Color(1.25, 1.1, 0.6)
