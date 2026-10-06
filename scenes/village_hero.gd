extends CharacterBody2D

## El héroe elegido caminando por el pueblo (village.gd). Usa las hojas
## de quieto y correr del juego (las mismas que player.gd, en su color
## elegido) en 4 direcciones, a escala x1.
##
## Se mueve con WASD / flechas / control, o siguiendo un camino que le
## da el pueblo (tocar o hacer clic en el suelo o en un lugar).

const PLAYER_SCRIPT := preload("res://scenes/player.gd")
const FRAME := 64
const SPEED := 85.0
## Forma que se ve en el pueblo (la de nivel 1 de cada clase).
const TIER := 1
const DIRS: Array[String] = ["front", "back", "side_left", "side_right"]
const RUN_FPS := 12.0
const IDLE_FPS := 8.0

signal arrived

var hero_id: String = "swordman"
var _sheets: Dictionary = {}       # "Idle"/"Run" -> {dir: Texture2D}
var _sprite: Sprite2D
var _dir: String = "front"
var _anim: String = "Idle"
var _t: float = 0.0
var _path: PackedVector2Array = PackedVector2Array()
var _stuck: float = 0.0
## false mientras hay un panel abierto: no camina ni lee el teclado.
var controllable: bool = true

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	wall_min_slide_angle = 0.0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5.0
	shape.shape = circle
	add_child(shape)
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.offset = Vector2(-FRAME / 2.0, -46)   # los pies (fila 46 del cuadro) en el origen
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	set_hero(hero_id)

## Cambia de héroe (o de color) en el lugar.
func set_hero(id: String) -> void:
	hero_id = id
	if _sprite == null:
		return
	var cls: Dictionary = PLAYER_SCRIPT.HERO_CLASSES.get(id, PLAYER_SCRIPT.HERO_CLASSES["swordman"])
	var color: Dictionary = cls["colors"][GameState.selected_color(id)]
	_sheets.clear()
	for anim in ["Idle", "Run"]:
		_sheets[anim] = {}
		for d in DIRS:
			_sheets[anim][d] = load(sheet_path(color, anim, d))
	_show()

## Ruta de una hoja: los colores con "dir" comparten un formato; el
## GAROTH original tiene las carpetas del pack (ver player.gd
## _swordman_path).
static func sheet_path(color: Dictionary, anim: String, dir: String) -> String:
	if color.has("dir"):
		var n: String = color["name"]
		return "%s%s_lvl%d/%s/%s_lvl%d_%s_%s.png" % [color["dir"], n, TIER, anim, n, TIER, anim, dir]
	return "res://assets/sprites/swordman/Swordsman_lvl%d/Swordsman_lvl%d_%s/Swordsman_lvl%d_%s_%s.png" % [TIER, TIER, anim, TIER, anim, dir]

func walk_path(points: PackedVector2Array) -> void:
	_path = points
	_stuck = 0.0

func stop() -> void:
	_path = PackedVector2Array()
	velocity = Vector2.ZERO

func is_walking_path() -> bool:
	return not _path.is_empty()

func face(dir: String) -> void:
	_dir = dir
	_show()

func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if controllable:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input != Vector2.ZERO:
		_path = PackedVector2Array()   # el teclado manda sobre el camino
		velocity = input * SPEED
	elif not _path.is_empty() and controllable:
		var to := _path[0] - global_position
		if to.length() < 3.0:
			_path.remove_at(0)
			if _path.is_empty():
				velocity = Vector2.ZERO
				arrived.emit()
		else:
			velocity = to.normalized() * SPEED
	else:
		velocity = Vector2.ZERO
	var before := global_position
	move_and_slide()
	# Trabado contra algo siguiendo un camino: se rinde al rato.
	if not _path.is_empty() and global_position.distance_to(before) < SPEED * delta * 0.2:
		_stuck += delta
		if _stuck > 0.5:
			stop()
	else:
		_stuck = 0.0
	if velocity.length() > 1.0:
		_anim = "Run"
		if absf(velocity.x) > absf(velocity.y) * 1.1:
			_dir = "side_left" if velocity.x < 0.0 else "side_right"
		else:
			_dir = "back" if velocity.y < 0.0 else "front"
	else:
		_anim = "Idle"

func _process(delta: float) -> void:
	_t += delta
	_show()

func _show() -> void:
	if _sheets.is_empty():
		return
	var tex: Texture2D = _sheets[_anim][_dir]
	if _sprite.texture != tex:
		_sprite.texture = tex
		_sprite.hframes = maxi(1, tex.get_width() / FRAME)
	_sprite.frame = int(_t * (RUN_FPS if _anim == "Run" else IDLE_FPS)) % _sprite.hframes
