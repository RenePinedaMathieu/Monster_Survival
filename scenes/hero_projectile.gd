extends Area2D

## Ataque de ELARA (bola de fuego que explota en área) y de DOREN (flecha
## que atraviesa), con el arte de sus packs de Craftpix
## (tools/import_class_pack.py). Lo lanza player.gd en el cuadro del
## ataque en que la llama o la flecha sale del sprite.

const FIRE_CYCLE := {1: "res://assets/sprites/elara/fx/fire_cycle_1.png", 4: "res://assets/sprites/elara/fx/fire_cycle_4.png"}
## Explosión: la de las formas 4-6 es más grande (48 px) y con destello.
const FIRE_EXPLOSION := {1: ["res://assets/sprites/elara/fx/fire_explosion_1.png", 32],
	4: ["res://assets/sprites/elara/fx/fire_explosion_4.png", 48]}
const ARROW_TEXTURE := "res://assets/sprites/doren/fx/arrow.png"
const FIRE_FRAME := 32
const FIRE_FPS := 12.0
const EXPLOSION_FPS := 20.0
## Filas de las hojas del pack, igual que las del personaje.
const ROWS := {"front": 0, "side_left": 1, "side_right": 2, "back": 3}

var kind: String = "arrow"      # "fireball" o "arrow"
var damage: float = 1.0
var radius: float = 30.0        # explosión de la bola de fuego
var pierce: int = 1             # flecha: a cuántos atraviesa
var max_dist: float = 260.0
var speed: float = 260.0
var dir: Vector2 = Vector2.RIGHT
var tier: int = 1

var _sprite: Sprite2D
var _frames: Array[Texture2D] = []
var _fps: float = FIRE_FPS
var _t: float = 0.0
var _travel: float = 0.0
var _hit: Array = []
var _exploding: bool = false

func setup(kind_: String, dir_: Vector2, damage_: float, tier_: int) -> void:
	kind = kind_
	dir = dir_.normalized()
	damage = damage_
	tier = tier_

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2   # monstruos
	z_index = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0 if kind == "fireball" else 5.0
	shape.shape = circle
	add_child(shape)
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	if kind == "fireball":
		var sheet: Texture2D = load(FIRE_CYCLE[4 if tier >= 4 else 1])
		_frames = _slice(sheet, ROWS[_dir_key()], FIRE_FRAME, 4)
		_sprite.texture = _frames[0]
	else:
		_sprite.texture = load(ARROW_TEXTURE)
		_sprite.rotation = dir.angle()
	body_entered.connect(_on_body_entered)

func _dir_key() -> String:
	if absf(dir.x) > absf(dir.y):
		return "side_left" if dir.x < 0.0 else "side_right"
	return "back" if dir.y < 0.0 else "front"

func _slice(sheet: Texture2D, row: int, size: int, count: int) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for i in range(count):
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * size, row * size, size, size)
		out.append(atlas)
	return out

func _physics_process(delta: float) -> void:
	_t += delta
	if not _frames.is_empty():
		var i: int = int(_t * _fps)
		if _exploding:
			if i >= _frames.size():
				queue_free()
				return
			_sprite.texture = _frames[i]
			return
		_sprite.texture = _frames[i % _frames.size()]
	var step: float = speed * delta
	position += dir * step
	_travel += step
	if _travel >= max_dist:
		if kind == "fireball":
			_explode()
		else:
			queue_free()

func _on_body_entered(body: Node) -> void:
	if _exploding or not body.has_method("take_damage") or body in _hit:
		return
	if "_dead" in body and body._dead:
		return
	if kind == "fireball":
		_explode()
		return
	_hit.append(body)
	body.take_damage(damage, "ataque")
	pierce -= 1
	if pierce <= 0:
		queue_free()

## La bola revienta: daño a todo lo que esté en el radio y la animación
## de la explosión del pack (fila según hacia dónde iba).
func _explode() -> void:
	if _exploding:
		return
	_exploding = true
	set_deferred("monitoring", false)
	for m in get_tree().get_nodes_in_group("monster"):
		if is_instance_valid(m) and not m._dead and global_position.distance_to(m.global_position) <= radius:
			m.take_damage(damage, "ataque")
	var data: Array = FIRE_EXPLOSION[4 if tier >= 4 else 1]
	_frames = _slice(load(data[0]), ROWS[_dir_key()], int(data[1]), 8)
	_fps = EXPLOSION_FPS
	_t = 0.0
	_sprite.texture = _frames[0]
	# El dibujo de la explosión mide ~radio: lo escalamos al área real.
	_sprite.scale = Vector2.ONE * clampf(radius * 2.0 / float(data[1]), 0.8, 2.5)
	Audio.play_sfx("meteor_impact", global_position, 0.1)
