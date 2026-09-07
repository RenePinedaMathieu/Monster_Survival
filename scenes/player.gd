extends CharacterBody2D

## Local player. WASD/flechas para moverse. El sprite cambia entre
## 8 direcciones (clockwise desde south) según hacia dónde vas. La
## cámara sigue al personaje, y la posición se broadcasta al canal
## `world` para el multiplayer.
##
## Emite `hp_changed(current, max)` cada vez que le pegan o cura —
## la UI del HUD escucha para actualizar la barra.

signal hp_changed(current: float, max_hp: float)
signal died

const SPEED := 200.0
const ATTACK_COOLDOWN := 0.35
const ATTACK_DAMAGE := 2.0

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

@export var max_hp: float = 100.0
var hp: float
var current_dir: int = 0
var _attack_cd: float = 0.0

var _textures: Array[Texture2D] = []

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _attack_area: Area2D = $AttackArea

func _ready() -> void:
	add_to_group("player")   # los monsters detectan por este grupo
	hp = max_hp
	for dir_name in DIR_NAMES:
		var t: Texture2D = load("res://assets/sprites/Man/rotations/" + dir_name + ".png")
		_textures.append(t)
	_apply_direction()
	# Aviso inicial para que el HUD se pinte al arranque
	emit_signal("hp_changed", hp, max_hp)

func _physics_process(delta: float) -> void:
	# Movimiento
	var input := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down"),
	)
	if input != Vector2.ZERO:
		input = input.normalized()
		var new_dir := _vec_to_dir(input)
		if new_dir != current_dir:
			current_dir = new_dir
			_apply_direction()
	velocity = input * SPEED
	move_and_slide()
	if input != Vector2.ZERO:
		Realtime.send_move(position.x, position.y, 1, current_dir)

	# Ataque (SPACE o F). El cooldown evita spamear.
	_attack_cd = max(0.0, _attack_cd - delta)
	if _attack_cd <= 0.0 and Input.is_action_just_pressed("attack"):
		_do_attack()

func _do_attack() -> void:
	_attack_cd = ATTACK_COOLDOWN
	# Pulso visual chiquito para dar feedback
	_sprite.scale = Vector2(1.15, 1.15)
	create_tween().tween_property(_sprite, "scale", Vector2.ONE, 0.15)
	# Daño a todo lo que esté en el AttackArea ahora mismo
	for body in _attack_area.get_overlapping_bodies():
		if body == self: continue
		if body.has_method("take_damage"):
			body.take_damage(ATTACK_DAMAGE)

func take_damage(amount: float) -> void:
	if hp <= 0.0: return
	hp = max(0.0, hp - amount)
	emit_signal("hp_changed", hp, max_hp)
	if hp <= 0.0:
		emit_signal("died")

func heal(amount: float) -> void:
	hp = min(max_hp, hp + amount)
	emit_signal("hp_changed", hp, max_hp)

func _apply_direction() -> void:
	if current_dir < _textures.size():
		_sprite.texture = _textures[current_dir]

func _vec_to_dir(v: Vector2) -> int:
	var angle := v.angle()
	var shifted := -angle + PI / 2.0
	var normalized := fmod(shifted + TAU, TAU)
	return int(round(normalized / (PI / 4.0))) % 8
