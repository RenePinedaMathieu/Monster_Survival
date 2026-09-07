extends CharacterBody2D

## Local player.
##   Movimiento: WASD/flechas, 8-direcciones clockwise desde south
##   Sprite:     rotations/ para idle, run_v4/<dir>/ para correr
##   Attack:     F (melee, área alrededor del player)
##   Shoot:      SPACE (proyectil coin hacia el rumbo actual)
##
## Emite hp_changed(current, max) y died para que el HUD/main
## puedan escucharlos.

signal hp_changed(current: float, max_hp: float)
signal died

const SPEED := 200.0
const ATTACK_COOLDOWN := 0.35
const ATTACK_DAMAGE := 2.0
const SHOOT_COOLDOWN := 0.20
const RUN_FPS := 12.0
const BASE_SCALE := 0.5   # sprite scale — match player.tscn Sprite2D.scale

const COIN_SCENE := preload("res://scenes/coin_projectile.tscn")

const DIR_NAMES: Array[String] = [
	"south",       # 0
	"south-east",  # 1
	"east",        # 2
	"north-east",  # 3
	"north",       # 4
	"north-west",  # 5
	"west",        # 6
	"south-west",  # 7
]

# Vectores unit por dirección — usados para disparar el coin.
const DIR_VECTORS: Array[Vector2] = [
	Vector2( 0,  1),  # south
	Vector2( 1,  1),  # SE
	Vector2( 1,  0),  # east
	Vector2( 1, -1),  # NE
	Vector2( 0, -1),  # north
	Vector2(-1, -1),  # NW
	Vector2(-1,  0),  # west
	Vector2(-1,  1),  # SW
]

@export var max_hp: float = 100.0
var hp: float
var current_dir: int = 0
var _attack_cd: float = 0.0
var _shoot_cd: float = 0.0
var _run_time: float = 0.0
var _run_frame: int = 0

# _idle_textures[dir]           = Texture2D (1 por dirección)
# _run_textures[dir][frame_idx] = Texture2D (8 dir × 8 frames)
var _idle_textures: Array[Texture2D] = []
var _run_textures: Array = []

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _attack_area: Area2D = $AttackArea

func _ready() -> void:
	add_to_group("player")
	hp = max_hp
	# Precarga: 8 idles + 8×8 = 72 texturas
	for dir_name in DIR_NAMES:
		_idle_textures.append(load("res://assets/sprites/Man/rotations/" + dir_name + ".png"))
		var frames: Array[Texture2D] = []
		for i in range(8):
			var path := "res://assets/sprites/Man/animations/run_v4/%s/frame_%03d.png" % [dir_name, i]
			frames.append(load(path))
		_run_textures.append(frames)
	_apply_idle()
	emit_signal("hp_changed", hp, max_hp)

func _physics_process(delta: float) -> void:
	var input := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down"),
	)
	var moving := input != Vector2.ZERO
	if moving:
		input = input.normalized()
		var new_dir := _vec_to_dir(input)
		if new_dir != current_dir:
			current_dir = new_dir
			# Al girar reseteamos frame para que se sienta responsivo
			_run_frame = 0
			_run_time = 0.0
	velocity = input * SPEED
	move_and_slide()

	# Sprite: correr (animado) o idle (estático)
	if moving:
		_run_time += delta
		if _run_time >= 1.0 / RUN_FPS:
			_run_time = 0.0
			_run_frame = (_run_frame + 1) % 8
		_sprite.texture = _run_textures[current_dir][_run_frame]
		Realtime.send_move(position.x, position.y, 1, current_dir)
	else:
		_apply_idle()

	# Cooldowns + inputs
	_attack_cd = max(0.0, _attack_cd - delta)
	_shoot_cd  = max(0.0, _shoot_cd  - delta)
	if _attack_cd <= 0.0 and Input.is_action_just_pressed("attack"):
		_do_attack()
	if _shoot_cd <= 0.0 and Input.is_action_just_pressed("shoot"):
		_do_shoot()

func _apply_idle() -> void:
	if current_dir < _idle_textures.size():
		_sprite.texture = _idle_textures[current_dir]

func _do_attack() -> void:
	_attack_cd = ATTACK_COOLDOWN
	_sprite.scale = Vector2.ONE * BASE_SCALE * 1.15
	create_tween().tween_property(_sprite, "scale", Vector2.ONE * BASE_SCALE, 0.15)
	for body in _attack_area.get_overlapping_bodies():
		if body == self: continue
		if body.has_method("take_damage"):
			body.take_damage(ATTACK_DAMAGE)

func _do_shoot() -> void:
	_shoot_cd = SHOOT_COOLDOWN
	var coin = COIN_SCENE.instantiate()
	# Lo emitimos como hijo del árbol raíz para que no se mueva con
	# la cámara del player si algún día la separamos.
	get_tree().current_scene.add_child(coin)
	coin.global_position = global_position + DIR_VECTORS[current_dir].normalized() * 30.0
	coin.setup(DIR_VECTORS[current_dir])

func take_damage(amount: float) -> void:
	if hp <= 0.0: return
	hp = max(0.0, hp - amount)
	emit_signal("hp_changed", hp, max_hp)
	if hp <= 0.0:
		emit_signal("died")

func heal(amount: float) -> void:
	hp = min(max_hp, hp + amount)
	emit_signal("hp_changed", hp, max_hp)

func _vec_to_dir(v: Vector2) -> int:
	var angle := v.angle()
	var shifted := -angle + PI / 2.0
	var normalized := fmod(shifted + TAU, TAU)
	return int(round(normalized / (PI / 4.0))) % 8
