extends CharacterBody2D

## Vampire-Survivors-style player.
##
## Movimiento: WASD/flechas — foco 100% en dodgear.
## Ataques: AUTOMÁTICOS. El coin dispara solo al monster más
##   cercano cada AUTO_FIRE_INTERVAL segundos (modificable por
##   upgrades). Nada de space/F manual.
## XP: los monsters droppean orbs. El player tiene un magnet que
##   las absorbe cuando entran en radio. Al levelearse aparece
##   el modal de upgrade.

signal hp_changed(current: float, max_hp: float)
signal xp_changed(current: int, needed: int, level: int)
signal leveled_up(new_level: int)
signal died

const COIN_SCENE := preload("res://scenes/coin_projectile.tscn")

const BASE_SCALE := 0.5
const BASE_SPEED := 220.0
const RUN_FPS := 12.0

# Auto-attack
const AUTO_FIRE_INTERVAL := 0.65      # segundos entre disparos base
const AUTO_FIRE_RANGE := 550.0        # rango de auto-target
const AUTO_FIRE_SPREAD := 0.13        # radianes entre proyectiles extra

# XP y level
const XP_TO_NEXT_BASE := 4
const XP_TO_NEXT_MULT := 1.35         # cada nivel cuesta 35% más
const XP_MAGNET_RADIUS := 90.0

# Regen
const REGEN_TICK := 0.5               # se aplica cada medio segundo

const DIR_NAMES: Array[String] = [
	"south", "south-east", "east", "north-east",
	"north", "north-west", "west", "south-west",
]
const DIR_VECTORS: Array[Vector2] = [
	Vector2( 0,  1), Vector2( 1,  1), Vector2( 1,  0), Vector2( 1, -1),
	Vector2( 0, -1), Vector2(-1, -1), Vector2(-1,  0), Vector2(-1,  1),
]

# Stats — se modifican con upgrades
var max_hp: float = 100.0
var hp: float
var move_speed: float = BASE_SPEED
var damage_mult: float = 1.0
var atk_speed_mult: float = 1.0
var magnet_radius: float = XP_MAGNET_RADIUS
var hp_regen_per_sec: float = 0.0
var projectiles_per_shot: int = 1

# XP / level
var level: int = 1
var xp: int = 0
var xp_to_next: int = XP_TO_NEXT_BASE

# Runtime state
var current_dir: int = 0
var _fire_cd: float = 0.0
var _regen_accum: float = 0.0
var _run_time: float = 0.0
var _run_frame: int = 0

var _idle_textures: Array[Texture2D] = []
var _run_textures: Array = []

@onready var _sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("player")
	hp = max_hp
	for dir_name in DIR_NAMES:
		_idle_textures.append(load("res://assets/sprites/Man/rotations/" + dir_name + ".png"))
		var frames: Array[Texture2D] = []
		for i in range(8):
			frames.append(load("res://assets/sprites/Man/animations/run_v4/%s/frame_%03d.png" % [dir_name, i]))
		_run_textures.append(frames)
	_apply_idle()
	emit_signal("hp_changed", hp, max_hp)
	emit_signal("xp_changed", xp, xp_to_next, level)

func _physics_process(delta: float) -> void:
	# Movement
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
			_run_frame = 0
			_run_time = 0.0
	velocity = input * move_speed
	move_and_slide()

	# Sprite: correr o idle
	if moving:
		_run_time += delta
		if _run_time >= 1.0 / RUN_FPS:
			_run_time = 0.0
			_run_frame = (_run_frame + 1) % 8
		_sprite.texture = _run_textures[current_dir][_run_frame]
		Realtime.send_move(position.x, position.y, 1, current_dir)
	else:
		_apply_idle()

	# Regen pasivo
	if hp_regen_per_sec > 0.0 and hp < max_hp:
		_regen_accum += delta
		if _regen_accum >= REGEN_TICK:
			heal(hp_regen_per_sec * REGEN_TICK)
			_regen_accum = 0.0

	# Auto-fire coin
	_fire_cd -= delta
	if _fire_cd <= 0.0:
		_auto_fire()

	# Magnetismo XP
	_magnet_orbs()

func _auto_fire() -> void:
	var target := _nearest_monster()
	if target == null:
		# Sin blanco cerca — reintentamos rápido, no gastamos el CD
		_fire_cd = 0.15
		return
	_fire_cd = AUTO_FIRE_INTERVAL / atk_speed_mult
	var to_target: Vector2 = (target.global_position - global_position).normalized()
	# Face hacia el target así el sprite gira acorde
	current_dir = _vec_to_dir(to_target)
	# Multishot: proyectiles con un ligero spread
	var n := projectiles_per_shot
	for i in range(n):
		var offset := (i - (n - 1) / 2.0) * AUTO_FIRE_SPREAD
		var dir := to_target.rotated(offset)
		var coin = COIN_SCENE.instantiate()
		get_tree().current_scene.add_child(coin)
		coin.global_position = global_position + dir * 24.0
		coin.setup(dir)
		if coin.has_method("set_damage"):
			coin.set_damage(coin.DAMAGE * damage_mult)

func _nearest_monster() -> Node2D:
	var monsters := get_tree().get_nodes_in_group("monster")
	var best: Node2D = null
	var best_d2 := AUTO_FIRE_RANGE * AUTO_FIRE_RANGE
	for m in monsters:
		if not is_instance_valid(m): continue
		var d2 := global_position.distance_squared_to(m.global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = m
	return best

func _magnet_orbs() -> void:
	var mr2 := magnet_radius * magnet_radius
	for orb in get_tree().get_nodes_in_group("xp_orb"):
		if not is_instance_valid(orb): continue
		if global_position.distance_squared_to(orb.global_position) < mr2:
			orb.start_magnet(self)

# ── XP + Level ──────────────────────────────────────────────────

func gain_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next:
		xp -= xp_to_next
		_level_up()
	emit_signal("xp_changed", xp, xp_to_next, level)

func _level_up() -> void:
	level += 1
	xp_to_next = int(round(xp_to_next * XP_TO_NEXT_MULT))
	emit_signal("leveled_up", level)

func apply_upgrade(id: String) -> void:
	match id:
		"damage":     damage_mult *= 1.25
		"atk_speed":  atk_speed_mult *= 1.20
		"move_speed": move_speed *= 1.12
		"max_hp":
			max_hp *= 1.25
			hp = min(max_hp, hp + max_hp * 0.20)
			emit_signal("hp_changed", hp, max_hp)
		"hp_regen":   hp_regen_per_sec += 1.0
		"magnet":     magnet_radius *= 1.40
		"multishot":  projectiles_per_shot = min(5, projectiles_per_shot + 1)

# ── HP ──────────────────────────────────────────────────────────

func take_damage(amount: float) -> void:
	if hp <= 0.0: return
	hp = max(0.0, hp - amount)
	emit_signal("hp_changed", hp, max_hp)
	# Flash rojo brevísimo
	_sprite.modulate = Color(1.6, 0.5, 0.5)
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.2)
	if hp <= 0.0:
		emit_signal("died")

func heal(amount: float) -> void:
	hp = min(max_hp, hp + amount)
	emit_signal("hp_changed", hp, max_hp)

# ── Utils ───────────────────────────────────────────────────────

func _apply_idle() -> void:
	if current_dir < _idle_textures.size():
		_sprite.texture = _idle_textures[current_dir]

func _vec_to_dir(v: Vector2) -> int:
	var angle := v.angle()
	var shifted := -angle + PI / 2.0
	var normalized := fmod(shifted + TAU, TAU)
	return int(round(normalized / (PI / 4.0))) % 8
