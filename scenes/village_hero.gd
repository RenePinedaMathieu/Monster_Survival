extends CharacterBody2D

## El héroe elegido caminando por el pueblo (village.gd). Usa las hojas
## de quieto y correr del juego (las mismas que player.gd, en su color
## elegido) en 4 direcciones, a escala x1.
##
## Se mueve igual que en la partida (player.gd): WASD / flechas /
## control o el joystick táctil de la mitad izquierda (touch_controls),
## con la misma velocidad de su clase y la misma aceleración.

const PLAYER_SCRIPT := preload("res://scenes/player.gd")
const FRAME := 64
## Forma que se ve en el pueblo (la de nivel 1 de cada clase).
const TIER := 1
const DIRS: Array[String] = ["front", "back", "side_left", "side_right"]
const RUN_FPS := 12.0
const IDLE_FPS := 8.0

var hero_id: String = "swordman"
var _sheets: Dictionary = {}       # "Idle"/"Run" -> {dir: Texture2D}
var _sprite: Sprite2D
var _dir: String = "front"
var _anim: String = "Idle"
var _t: float = 0.0
var _speed: float = PLAYER_SCRIPT.BASE_SPEED
var _touch_input := Vector2.ZERO
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
	_speed = PLAYER_SCRIPT.BASE_SPEED * float(cls.get("speed", 1.0))
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

## Lo manda el joystick táctil (touch_controls.gd), como en la partida.
func set_touch_input(v: Vector2) -> void:
	_touch_input = v

func stop() -> void:
	velocity = Vector2.ZERO

func face(dir: String) -> void:
	_dir = dir
	_show()

## Igual que player.gd: el teclado manda sobre el toque, la dirección se
## normaliza y se llega a la velocidad tope con la misma aceleración.
func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if controllable:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if input == Vector2.ZERO:
			input = _touch_input
	var moving := input != Vector2.ZERO
	if moving:
		input = input.normalized()
		# Misma regla que player.gd _swordman_dir_from_vec.
		if absf(input.x) > absf(input.y):
			_dir = "side_left" if input.x < 0.0 else "side_right"
		else:
			_dir = "back" if input.y < 0.0 else "front"
	velocity = velocity.move_toward(input * _speed, PLAYER_SCRIPT.ACCELERATION * delta)
	move_and_slide()
	_anim = "Run" if moving else "Idle"

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
