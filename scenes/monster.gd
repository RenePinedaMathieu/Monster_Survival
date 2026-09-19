extends CharacterBody2D

## Monstruo con state machine de ataque telegráfico:
##   idle_wander → chase → windup → strike → cooldown → chase → … → dead
##
## El windup es de 400ms con tint rojo — el player tiene tiempo de
## esquivarlo. En strike (200ms) chequeamos si el player está en
## rango — si sí, le pega damage limpio. Cooldown 600ms antes de
## que pueda intentar otro ataque.
##
## Cada instancia recibe su "kind" (rata/murciélago/cangrejo/etc.)
## vía set_kind() después de spawnear — ver KIND_DATA más abajo. Los
## sheets son grillas (tamaño de celda y cantidad de columnas varían
## por pack, ver "frame_size"/"cols" de cada kind), cortados acá con
## AtlasTexture igual que se hace en player.gd.

signal hit_player(damage: float)
signal hp_changed(current: float, max_hp: float)
signal died

enum State { IDLE_WANDER, CHASE, WINDUP, STRIKE, COOLDOWN }

const XP_ORB_SCENE := preload("res://scenes/xp_orb.tscn")

## Bajado de 30/90 (y de nuevo de 20/62) — seguía sintiéndose
## demasiado rápido apenas arranca la wave 1, antes de que el
## speed_mult de main.gd sume nada. CHASE_SPEED ahora es ~21% de la
## velocidad del player (220) para que esquivar sea viable de entrada.
const WANDER_SPEED := 14.0
const CHASE_SPEED  := 46.0
const WANDER_CHANGE_MS := 2000
const ATTACK_RANGE := 30.0   # a esta distancia empieza el windup (x collision_scale del kind)
const DETECT_RANGE := 240.0
const WINDUP_TIME := 0.40
const STRIKE_TIME := 0.20
const COOLDOWN_TIME := 0.60
const HIT_DAMAGE := 12.0

const ANIM_FPS := 9.0     # idle/run — no crítico para el gameplay
const DEATH_FPS := 10.0

## Pool base — sólo los nuevos packs (Rat128, Imp, Lizardman). Los
## Pipoya viejos (rat 64x64, bat, crab, skull, golem) se retiraron.
const KIND_IDS: Array[String] = ["rat", "imp", "lizardman"]
## Pool "avanzado" — mismo pool por ahora. Cuando sumemos más
## variantes (Imp2, Lizardman2, Rat2/3) las agregamos acá.
const KIND_IDS_ADVANCED: Array[String] = ["rat", "imp", "lizardman"]
const BOSS_KIND_ID := "demon1"                # backwards compat (main.gd)
## Bosses ordenados por tier — main.gd los elige según cuántos bosses
## ya cayeron en la run (1er boss → demon1, 2do → demon2, 3ro+ → demon3).
const BOSS_KIND_IDS: Array[String] = ["demon1", "demon2", "demon3"]

## "scale" está calibrado a mano para cada pack — cada uno trae
## distinto padding dentro de su celda (ver bbox medidos al armar
## esto), así que un mismo factor los dejaría todos de tamaños
## distintos entre sí. "collision_scale" sólo se usa para el Golem
## (boss) — agranda su hitbox y el radio de ataque acorde al sprite
## gigante en vez de dejarlo con la misma hitbox que una rata.
##
## Cada animación es {file, frames, start} — "start" es el índice
## (fila*cols + columna) del primer frame dentro de la hoja. Todos
## los kinds actuales usan un archivo separado por animación (start
## siempre 0); "start" != 0 sirve para un pack que comparta una
## única hoja grande con varias animaciones en filas distintas, si
## se suma alguno más adelante.
## Cada kind trae paths a sheets pre-cortados (una fila horizontal
## por animación). "cols" por anim = frame_count. "scale" y opcional
## "collision_scale" están calibrados a ojo para cada pack.
const KIND_DATA: Dictionary = {

	# ── Packs nuevos (sprites 128x128 y 64x64, animaciones en filas
	# horizontales de un frame cada una, generadas al batch-exportar
	# los .aseprite a PNG con py-aseprite). Cada anim tiene su propio
	# "cols" = frame_count porque las hojas son de una fila.
	# ────────────────────────────────────────────────────────────────

	# Demons — bosses. Cada tier es visualmente más agresivo. Se
	# elige el demon_i según el i-ésimo boss del run (main.gd).
	"demon1": {
		"base": "res://assets/sprites/Demon/Demon1/",
		"frame_size": Vector2(128, 128),
		"idle":   {"file": "Idle/Demon1_Idle_front.png",     "frames": 4,  "cols": 4},
		"run":    {"file": "Run/Demon1_Run_front.png",       "frames": 8,  "cols": 8},
		"attack": {"file": "Attack/Demon1_Attack_front.png", "frames": 10, "cols": 10},
		"death":  {"file": "Death/Demon1_Death_front.png",   "frames": 13, "cols": 13},
		"scale": 0.55,
		"collision_scale": 1.6,
	},
	"demon2": {
		"base": "res://assets/sprites/Demon/Demon2/",
		"frame_size": Vector2(128, 128),
		"idle":   {"file": "Idle/Demon2_Idle_front.png",     "frames": 4,  "cols": 4},
		"run":    {"file": "Run/Demon2_Run_front.png",       "frames": 8,  "cols": 8},
		"attack": {"file": "Attack/Demon2_Attack_front.png", "frames": 10, "cols": 10},
		"death":  {"file": "Death/Demon2_Death_front.png",   "frames": 13, "cols": 13},
		"scale": 0.62,
		"collision_scale": 1.8,
	},
	"demon3": {
		"base": "res://assets/sprites/Demon/Demon3/",
		"frame_size": Vector2(128, 128),
		"idle":   {"file": "Idle/Demon3_Idle_front.png",     "frames": 4,  "cols": 4},
		"run":    {"file": "Run/Demon3_Run_front.png",       "frames": 8,  "cols": 8},
		"attack": {"file": "Attack/Demon3_Attack_front.png", "frames": 10, "cols": 10},
		"death":  {"file": "Death/Demon3_Death_front.png",   "frames": 13, "cols": 13},
		"scale": 0.7,
		"collision_scale": 2.0,
	},

	# Imp — enemigo chico y rápido. Ideal como filler de waves llenas.
	"imp": {
		"base": "res://assets/sprites/IMP/Imp1/",
		"frame_size": Vector2(64, 64),
		"idle":   {"file": "Idle/Imp1_Idle_front.png",     "frames": 4, "cols": 4},
		"run":    {"file": "Run/Imp1_Run_front.png",       "frames": 8, "cols": 8},
		"attack": {"file": "Attack/Imp1_Attack_front.png", "frames": 6, "cols": 6},
		"death":  {"file": "Death/Imp1_Death_front.png",   "frames": 10, "cols": 10},
		"scale": 0.7,
	},

	# Lizardman — enemigo mediano equilibrado. Aparece en el mid-game.
	"lizardman": {
		"base": "res://assets/sprites/Lizardman/Lizardman1/",
		"frame_size": Vector2(64, 64),
		"idle":   {"file": "Idle/Lizardman1_Idle_front.png",     "frames": 4, "cols": 4},
		"run":    {"file": "Run/Lizardman1_Run_front.png",       "frames": 8, "cols": 8},
		"attack": {"file": "Attack/Lizardman1_Attack_front.png", "frames": 7, "cols": 7},
		"death":  {"file": "Death/Lizardman1_Death_front.png",   "frames": 7, "cols": 7},
		"scale": 0.7,
	},

	# Rat — 128x128 sprite del pack Rat1. Detallado y animado.
	"rat": {
		"base": "res://assets/sprites/Rat/Rat1/",
		"frame_size": Vector2(128, 128),
		"idle":   {"file": "Idle/Rat1_Idle_front.png",     "frames": 6, "cols": 6},
		"run":    {"file": "Run/Rat1_Run_front.png",       "frames": 6, "cols": 6},
		"attack": {"file": "Attack/Rat1_Attack_front.png", "frames": 8, "cols": 8},
		"death":  {"file": "Death/Rat1_Death_front.png",   "frames": 5, "cols": 5},
		"scale": 0.4,
	},
}

@export var max_hp: float = 3.0
@export var xp_reward: int = 1
@export var coin_reward: int = 1
## Multiplicador de velocidad — main.gd lo sube con cada oleada para
## que el juego se sienta progresivamente más intenso, no sólo con
## más cantidad de bichos sino también más rápidos.
@export var speed_mult: float = 1.0
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
var _dead := false

var _base_sprite_scale := Vector2.ONE
var _kind_id := ""
var _attack_range := ATTACK_RANGE
var _anim_frames: Dictionary = {}   # "idle"/"run"/"attack"/"death" -> Array[Texture2D]
var _anim_name := ""
var _anim_fps := ANIM_FPS
var _anim_time := 0.0
var _anim_frame := 0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _detection: Area2D = $DetectionArea

func _ready() -> void:
	add_to_group("monster")
	hp = max_hp
	_detection.body_entered.connect(_on_body_entered)
	_detection.body_exited.connect(_on_body_exited)
	_pick_new_wander()
	if target and is_instance_valid(target):
		_enter_chase()

## Configura sprite/animaciones/escala para uno de KIND_IDS o
## BOSS_KIND_ID. Se llama después de add_child (necesita @onready
## resuelto). Sin esto el monstruo queda con el sprite en blanco.
func set_kind(kind_id: String) -> void:
	_kind_id = kind_id
	var data: Dictionary = KIND_DATA.get(kind_id, KIND_DATA[KIND_IDS[0]])
	var frame_size: Vector2 = data.get("frame_size", Vector2(64, 64))
	var cols: int = data.get("cols", 4)
	_anim_frames.clear()
	for anim_name in ["idle", "run", "attack", "death"]:
		if data.has(anim_name):
			var info: Dictionary = data[anim_name]
			# Los packs nuevos (Demon/Sword/Imp/Lizard/Rat_new) traen
			# hojas de una sola fila con "cols" = frames de esa anim.
			# Los viejos (Pipoya) usan el "cols" del kind. info.cols
			# gana si está.
			var anim_cols: int = info.get("cols", cols)
			_anim_frames[anim_name] = _slice_frames(
				data["base"] + info["file"], frame_size, anim_cols, info["frames"], info.get("start", 0)
			)

	_base_sprite_scale = Vector2.ONE * float(data.get("scale", 1.0))
	_sprite.scale = _base_sprite_scale
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var collision_scale: float = data.get("collision_scale", 1.0)
	_attack_range = ATTACK_RANGE * collision_scale
	if collision_scale != 1.0:
		# El shape es un SubResource compartido por todas las
		# instancias de monster.tscn — hay que duplicarlo antes de
		# mutarlo o agrandaríamos la hitbox de TODOS los monstruos.
		var shape: CircleShape2D = _collision.shape.duplicate()
		shape.radius *= collision_scale
		_collision.shape = shape

	_set_animation("idle")

## "start" es el índice (fila*cols + columna) del primer frame — 0
## para los packs de un archivo por animación (todos los actuales);
## sirve para un pack que comparta una única hoja grande con varias
## animaciones en filas distintas, si se suma alguno más adelante.
func _slice_frames(path: String, frame_size: Vector2, cols: int, frame_count: int, start: int = 0) -> Array[Texture2D]:
	var sheet: Texture2D = load(path)
	var frames: Array[Texture2D] = []
	for i in range(frame_count):
		var idx := start + i
		var col := idx % cols
		var row := idx / cols
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(col * frame_size.x, row * frame_size.y, frame_size.x, frame_size.y)
		frames.append(atlas)
	return frames

func _physics_process(delta: float) -> void:
	# target puede haber sido freed (por reload de escena etc.);
	# validamos antes de usarlo.
	if target and not is_instance_valid(target):
		target = null

	if _dead:
		_update_animation(delta)
		return

	match state:
		State.IDLE_WANDER: _tick_wander(delta)
		State.CHASE:       _tick_chase(delta)
		State.WINDUP:      _tick_windup(delta)
		State.STRIKE:      _tick_strike(delta)
		State.COOLDOWN:    _tick_cooldown(delta)

	move_and_slide()
	_update_animation(delta)

func _tick_wander(_delta: float) -> void:
	# Con target seteado no deberíamos estar acá — pasamos a chase.
	if target:
		_enter_chase()
		return
	var now := Time.get_ticks_msec()
	if now - _last_wander_change > WANDER_CHANGE_MS:
		_pick_new_wander()
	velocity = _wander_dir * WANDER_SPEED * speed_mult

func _tick_chase(_delta: float) -> void:
	if target == null:
		_enter_wander()
		return
	var to_player: Vector2 = target.global_position - global_position
	var d := to_player.length()
	if d < _attack_range:
		_enter_windup()
		return
	# Sin techo de distancia — persigue eternamente al player.
	var dir := to_player.normalized()
	velocity = dir * CHASE_SPEED * speed_mult
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
			and global_position.distance_to(target.global_position) < _attack_range + 12.0:
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
	_set_animation("idle")

func _enter_chase() -> void:
	state = State.CHASE
	_sprite.modulate = Color.WHITE
	_set_animation("run")

func _enter_windup() -> void:
	state = State.WINDUP
	_state_timer = 0.0
	_did_hit_this_strike = false
	# Tint rojo para telegrafiar el golpe — se mantiene SIEMPRE, tenga
	# o no el kind una animación de ataque propia (algunos packs no
	# traen una, ver KIND_DATA["skull"]).
	_sprite.modulate = Color(1.4, 0.6, 0.6)
	var attack_frames: Array = _anim_frames.get("attack", [])
	if attack_frames.is_empty():
		_set_animation("idle")
	else:
		# La animación de ataque se estira/comprime para que dure
		# EXACTAMENTE windup+strike, sea cual sea su frame count —
		# así el timing de combate (el valor importante) no cambia
		# por kind, sólo la velocidad de reproducción del dibujo.
		_set_animation("attack", attack_frames.size() / (WINDUP_TIME + STRIKE_TIME))

func _enter_strike() -> void:
	state = State.STRIKE
	_state_timer = 0.0
	# Si no hay animación de ataque dedicada, el viejo "pulso" de
	# escala sigue vendiendo el golpe. Si la hay, duplicar el efecto
	# se ve raro encima del swing ya animado.
	if not _anim_frames.has("attack"):
		_sprite.scale = _base_sprite_scale * 1.25
		create_tween().tween_property(_sprite, "scale", _base_sprite_scale, 0.15)

func _enter_cooldown() -> void:
	state = State.COOLDOWN
	_state_timer = 0.0
	_sprite.modulate = Color.WHITE
	_set_animation("idle")

# ── Animación ────────────────────────────────────────────────────

func _set_animation(name: String, fps: float = ANIM_FPS) -> void:
	var target_name := name
	if not _anim_frames.has(target_name):
		target_name = "idle"
		fps = ANIM_FPS
	if target_name == _anim_name:
		return
	_anim_name = target_name
	_anim_fps = fps
	_anim_frame = 0
	_anim_time = 0.0

func _update_animation(delta: float) -> void:
	var frames: Array = _anim_frames.get(_anim_name, [])
	if frames.is_empty():
		return
	_anim_time += delta
	if _anim_time >= 1.0 / _anim_fps:
		_anim_time = 0.0
		_anim_frame += 1
		if _anim_frame >= frames.size():
			if _anim_name == "death":
				queue_free()
				return
			_anim_frame = 0
	_sprite.texture = frames[_anim_frame]

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
	if _dead: return
	hp -= amount
	emit_signal("hp_changed", max(0.0, hp), max_hp)
	_sprite.modulate = Color(2.0, 2.0, 2.0)
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.12)
	Audio.play_sfx("monster_hit", global_position, 0.15)
	if hp <= 0.0:
		_die()

## A diferencia de antes (queue_free inmediato), ahora deja correr la
## animación de death antes de desaparecer — pero el signal/XP/wave
## count se resuelven al toque, no hay delay en la progresión de wave.
func _die() -> void:
	_dead = true
	velocity = Vector2.ZERO
	remove_from_group("monster")   # que no lo sigan targeteando mientras agoniza
	_collision.set_deferred("disabled", true)
	_detection.set_deferred("monitoring", false)
	_drop_xp_orb()
	GameState.add_run_currency(coin_reward)
	# Boss suena distinto — más grave y grande. Cualquier demon (tier)
	# cuenta como boss.
	if _kind_id in BOSS_KIND_IDS:
		Audio.play_sfx("boss_death", global_position, 0.05)
	else:
		Audio.play_sfx("monster_death", global_position, 0.15)
	emit_signal("died")

	var death_frames: Array = _anim_frames.get("death", [])
	if death_frames.is_empty():
		queue_free()
		return
	_sprite.modulate = Color.WHITE
	_set_animation("death", DEATH_FPS)

func _drop_xp_orb() -> void:
	var orb = XP_ORB_SCENE.instantiate()
	orb.add_to_group("xp_orb")
	get_tree().current_scene.add_child(orb)
	orb.global_position = global_position
	orb.set_xp(xp_reward)
