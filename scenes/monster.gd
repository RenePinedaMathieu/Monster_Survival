extends CharacterBody2D

## Monstruo simple con IA de wander + chase. Sin sprite pre-asignado:
## main.gd le hace `set_sprite(<texture>)` al spawnear para poder
## reusar la misma escena con distintos monstruos.
##
## Estados:
##   idle_wander  → deambula sin rumbo por ~2s
##   chase        → persigue al player si está dentro del radio de
##                  detección (Area2D hija)
##
## En contacto con el player: le drena 1 HP/s vía la señal `hit_player`
## que main.gd escucha para actualizar la barra.

signal hit_player(damage: float)

const WANDER_SPEED := 30.0
const CHASE_SPEED  := 80.0
const WANDER_CHANGE_MS := 2000
const DAMAGE_PER_SEC := 10.0

@export var max_hp: float = 3.0
var hp: float
var _target_player: Node2D = null
var _wander_dir := Vector2.ZERO
var _last_wander_change := 0
var _damage_accum := 0.0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _detection: Area2D = $DetectionArea

func _ready() -> void:
	hp = max_hp
	_detection.body_entered.connect(_on_body_entered)
	_detection.body_exited.connect(_on_body_exited)
	_pick_new_wander()

func set_sprite(tex: Texture2D) -> void:
	_sprite.texture = tex

func _physics_process(delta: float) -> void:
	if _target_player != null and is_instance_valid(_target_player):
		# Chase
		var to_player := _target_player.global_position - global_position
		var dir := to_player.normalized() if to_player.length() > 1.0 else Vector2.ZERO
		velocity = dir * CHASE_SPEED
		# Flip sprite horizontal según hacia dónde miramos
		if abs(dir.x) > 0.1:
			_sprite.flip_h = dir.x < 0
		# Damage on close contact
		if to_player.length() < 32.0:
			_damage_accum += delta
			if _damage_accum >= 1.0 / DAMAGE_PER_SEC:
				emit_signal("hit_player", DAMAGE_PER_SEC * _damage_accum)
				_damage_accum = 0.0
	else:
		# Wander idle
		var now := Time.get_ticks_msec()
		if now - _last_wander_change > WANDER_CHANGE_MS:
			_pick_new_wander()
		velocity = _wander_dir * WANDER_SPEED
	move_and_slide()

func _pick_new_wander() -> void:
	var ang := randf() * TAU
	_wander_dir = Vector2(cos(ang), sin(ang))
	_last_wander_change = Time.get_ticks_msec()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_target_player = body

func _on_body_exited(body: Node) -> void:
	if body == _target_player:
		_target_player = null

func take_damage(amount: float) -> void:
	hp -= amount
	if hp <= 0.0:
		queue_free()
