extends CharacterBody2D

## Monstruo con state machine de ataque telegráfico:
##   idle_wander → chase → windup → strike → cooldown → chase
##
## El windup es de 400ms con tint rojo — el player tiene tiempo de
## esquivarlo. En strike (200ms) chequeamos si el player está en
## rango — si sí, le pega damage limpio. Cooldown 600ms antes de
## que pueda intentar otro ataque.

signal hit_player(damage: float)
signal died

enum State { IDLE_WANDER, CHASE, WINDUP, STRIKE, COOLDOWN }

const WANDER_SPEED := 30.0
const CHASE_SPEED  := 90.0
const WANDER_CHANGE_MS := 2000
const ATTACK_RANGE := 30.0   # a esta distancia empieza el windup
const DETECT_RANGE := 240.0
const WINDUP_TIME := 0.40
const STRIKE_TIME := 0.20
const COOLDOWN_TIME := 0.60
const HIT_DAMAGE := 12.0
const BASE_SCALE := 0.18   # match monster.tscn Sprite2D.scale

@export var max_hp: float = 3.0
var hp: float
var state: int = State.IDLE_WANDER

## Referencia directa al player. main.gd la setea después del spawn
## así los monstruos persiguen SIN necesidad de estar en el radio
## de detección — el Area2D queda como fallback si target no está
## seteado.
var target: Node2D = null

var _wander_dir := Vector2.ZERO
var _last_wander_change := 0
var _state_timer := 0.0
var _did_hit_this_strike := false

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _detection: Area2D = $DetectionArea

func _ready() -> void:
	hp = max_hp
	_detection.body_entered.connect(_on_body_entered)
	_detection.body_exited.connect(_on_body_exited)
	_pick_new_wander()
	# Si ya nos pasaron un target antes del _ready, arrancamos chase
	if target and is_instance_valid(target):
		_enter_chase()

func set_sprite(tex: Texture2D) -> void:
	_sprite.texture = tex

func _physics_process(delta: float) -> void:
	# target puede haber sido freed (por reload de escena etc.);
	# validamos antes de usarlo.
	if target and not is_instance_valid(target):
		target = null

	match state:
		State.IDLE_WANDER: _tick_wander(delta)
		State.CHASE:       _tick_chase(delta)
		State.WINDUP:      _tick_windup(delta)
		State.STRIKE:      _tick_strike(delta)
		State.COOLDOWN:    _tick_cooldown(delta)

	move_and_slide()

func _tick_wander(_delta: float) -> void:
	# Con target seteado no deberíamos estar acá — pasamos a chase.
	if target:
		_enter_chase()
		return
	var now := Time.get_ticks_msec()
	if now - _last_wander_change > WANDER_CHANGE_MS:
		_pick_new_wander()
	velocity = _wander_dir * WANDER_SPEED

func _tick_chase(_delta: float) -> void:
	if target == null:
		_enter_wander()
		return
	var to_player: Vector2 = target.global_position - global_position
	var d := to_player.length()
	if d < ATTACK_RANGE:
		_enter_windup()
		return
	# Sin techo de distancia — persigue eternamente al player.
	var dir := to_player.normalized()
	velocity = dir * CHASE_SPEED
	if abs(dir.x) > 0.1:
		_sprite.flip_h = dir.x < 0

func _tick_windup(delta: float) -> void:
	velocity = Vector2.ZERO
	_state_timer += delta
	if _state_timer >= WINDUP_TIME:
		_enter_strike()

func _tick_strike(delta: float) -> void:
	velocity = Vector2.ZERO
	_state_timer += delta
	# Frame de golpe — un solo hit por strike
	if not _did_hit_this_strike and target \
			and global_position.distance_to(target.global_position) < ATTACK_RANGE + 12.0:
		_did_hit_this_strike = true
		emit_signal("hit_player", HIT_DAMAGE)
	if _state_timer >= STRIKE_TIME:
		_enter_cooldown()

func _tick_cooldown(delta: float) -> void:
	velocity = Vector2.ZERO
	_state_timer += delta
	if _state_timer >= COOLDOWN_TIME:
		if target:
			_enter_chase()
		else:
			_enter_wander()

# ── State transitions ────────────────────────────────────────────

func _enter_wander() -> void:
	state = State.IDLE_WANDER
	_sprite.modulate = Color.WHITE
	_pick_new_wander()

func _enter_chase() -> void:
	state = State.CHASE
	_sprite.modulate = Color.WHITE

func _enter_windup() -> void:
	state = State.WINDUP
	_state_timer = 0.0
	_did_hit_this_strike = false
	# Tint rojo para telegrafiar el golpe
	_sprite.modulate = Color(1.4, 0.6, 0.6)

func _enter_strike() -> void:
	state = State.STRIKE
	_state_timer = 0.0
	# Pulso visual
	_sprite.scale = Vector2.ONE * BASE_SCALE * 1.25
	create_tween().tween_property(_sprite, "scale", Vector2.ONE * BASE_SCALE, 0.15)

func _enter_cooldown() -> void:
	state = State.COOLDOWN
	_state_timer = 0.0
	_sprite.modulate = Color.WHITE

# ── Utils ────────────────────────────────────────────────────────

func _pick_new_wander() -> void:
	var ang := randf() * TAU
	_wander_dir = Vector2(cos(ang), sin(ang))
	_last_wander_change = Time.get_ticks_msec()

func _on_body_entered(body: Node) -> void:
	# Fallback si main.gd no seteó target: al detectar al player en
	# el Area2D lo agarramos igual.
	if body.is_in_group("player") and target == null:
		target = body

func _on_body_exited(_body: Node) -> void:
	# Ya no perdemos target al salir del área — persigue siempre.
	pass

func take_damage(amount: float) -> void:
	hp -= amount
	# Flash blanco brevísimo para hitfeedback
	_sprite.modulate = Color(2.0, 2.0, 2.0)
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.12)
	if hp <= 0.0:
		emit_signal("died")
		queue_free()
