extends CharacterBody2D

## Vampire-Survivors-style player.
##
## Movimiento: WASD/flechas — foco 100% en dodgear.
## Ataques: AUTOMÁTICOS. El disparo apunta solo al monster más
##   cercano cada AUTO_FIRE_INTERVAL segundos (modificable por
##   upgrades). Nada de space/F manual.
## XP: los monsters droppean orbs. El player tiene un magnet que
##   las absorbe cuando entran en radio. Al levelearse aparece
##   el modal de upgrade.

signal hp_changed(current: float, max_hp: float)
signal defense_changed(current: float, max_defense: float)
signal xp_changed(current: int, needed: int, level: int)
signal leveled_up(new_level: int)
signal died
## Cada vez que cambia la build (carta o evolución) — lleva
## build_summary(), con lo que el HUD arma la barra de mejoras activas.
signal upgrades_changed(summary: Array)
## Cooldown de la habilidad activa — el HUD lo muestra en su botón.
signal skill_cooldown_changed(remaining: float, total: float)

# ── Habilidad activa (una por personaje) ─────────────────────────
## Se usa con ESPACIO o con el botón redondo del HUD (táctil en el
## teléfono). Le da identidad a cada héroe más allá del ataque base.
const SKILL_ICON := "res://assets/ui/skill_icons/"
const ACTIVE_SKILLS: Dictionary = {
	"main_char1": {"id": "dash", "name": "Embestida", "cooldown": 4.0, "icon": SKILL_ICON + "skill_62.png",
		"desc": "Te lanzas hacia adelante golpeando todo a tu paso"},
	"main_char2": {"id": "volley", "name": "Ráfaga", "cooldown": 6.0, "icon": SKILL_ICON + "skill_61.png",
		"desc": "Disparas 12 flechas en círculo"},
	"main_char2_female": {"id": "roll", "name": "Voltereta", "cooldown": 3.5, "icon": SKILL_ICON + "skill_77.png",
		"desc": "Ruedas lejos y eres invulnerable un instante"},
	"swordman": {"id": "shield", "name": "Escudo divino", "cooldown": 8.0, "icon": SKILL_ICON + "skill_76.png",
		"desc": "2 s invulnerable y empujas a los enemigos cercanos"},
}
const DASH_SPEED := 900.0
const DASH_DAMAGE := 8.0
const SHIELD_RADIUS := 110.0
const SHIELD_DAMAGE := 10.0
const VOLLEY_ARROWS := 12

const SHOT_SCENE := preload("res://scenes/shot_projectile.tscn")
const METEOR_SCRIPT := preload("res://scenes/meteor.gd")
const FLYING_SWORDS_RIG_SCRIPT := preload("res://scenes/flying_swords_rig.gd")
const COMPANION_SCRIPT := preload("res://scenes/companion.gd")
const Upgrades := preload("res://scenes/upgrades.gd")
const AURA_SCRIPT := preload("res://scenes/aura_weapon.gd")
const AXE_SCRIPT := preload("res://scenes/axe_weapon.gd")
const LIGHTNING_SCRIPT := preload("res://scenes/lightning_weapon.gd")

const BASE_SCALE := 0.5
const BASE_SPEED := 175.0             # bajado de 220 — se sentía muy rápido/patinoso
const ACCELERATION := 1600.0          # px/s² — llega a top speed en ~0.11s, no instantáneo
const RUN_FPS := 12.0

# Auto-attack
const AUTO_FIRE_INTERVAL := 0.65      # segundos entre disparos base
# Subido de 550→750→900→1800→3600 (el doble otra vez). OJO: el mapa
# (world.gd WORLD_BOUND=950) mide 1900 de punta a punta, así que a
# 3600 CUALQUIER monstruo vivo entra en rango — el disparo deja de
# tener un "límite" real, dispara a lo que sea que esté más cerca en
# todo el mapa. Investigando Vampire Survivors: sus armas auto-target
# (Magic Wand, etc.) en la práctica sólo alcanzan enemigos cerca de
# lo que se ve en cámara, no todo el mapa — si en algún momento se
# siente "raro" que dispare a algo que ni se ve en pantalla, este es
# el valor a bajar. El proyectil (shot_projectile.gd) tiene
# SPEED*LIFETIME > esto para que de verdad pueda llegar tan lejos.
const AUTO_FIRE_RANGE := 3600.0       # rango de auto-target
const AUTO_FIRE_SPREAD := 0.13        # radianes entre proyectiles extra

# XP y level
const XP_TO_NEXT_BASE := 4
const XP_TO_NEXT_MULT := 1.35         # cada nivel cuesta 35% más
const XP_MAGNET_RADIUS := 90.0

# Regen
const REGEN_TICK := 0.5               # se aplica cada medio segundo

# Carta "meteoritos"
const METEOR_BASE_INTERVAL := 5.0
const METEOR_DAMAGE := 16.0

const DIR_NAMES: Array[String] = [
	"south", "south-east", "east", "north-east",
	"north", "north-west", "west", "south-west",
]
const DIR_VECTORS: Array[Vector2] = [
	Vector2( 0,  1), Vector2( 1,  1), Vector2( 1,  0), Vector2( 1, -1),
	Vector2( 0, -1), Vector2(-1, -1), Vector2(-1,  0), Vector2(-1,  1),
]

# AXEL (main_char1): el pack sólo trae 4 direcciones (no diagonales),
# así que el facing se resuelve por eje dominante del vector de
# movimiento/objetivo en vez de los 8 pasos de DIR_NAMES. Sheets de
# 8 frames a 96x80 por dirección (idle/run/attack1).
const AXEL_BASE_PATH := "res://assets/main_characters/main_char1/FREE_Adventurer 2D Pixel Art/Sprites/"
const AXEL_DIRS: Array[String] = ["down", "up", "left", "right"]
const AXEL_FRAME_SIZE := Vector2(96, 80)
const AXEL_FRAME_COUNT := 8
# Frame donde aparece el tajo (swoosh) en attack1 — ahí se aplica el
# daño, no al terminar toda la animación.
const AXEL_ATTACK_HIT_FRAME := 2
# El pack de AXEL viene más "vacío" en su frame que el sprite Man
# (bbox real ~19x34 en un frame de 96x80 vs ~30x54 en uno de 112x112)
# — este factor lo deja del mismo alto en pantalla que el resto.
const AXEL_SCALE := 0.8
const AXEL_MELEE_DAMAGE := 4.0
# Radio de "hay algo cerca, ataco" — a propósito más chico que
# AUTO_FIRE_RANGE (que es para el disparo a distancia). Sin este filtro,
# el nearest_monster casi siempre encuentra algo dentro de 550px en
# una wave llena y AXEL queda trabado en la animación de ataque en
# vez de correr. Un poco más grande que el radio real de AttackArea
# (42) para tolerar que el objetivo se mueva durante el windup.
const AXEL_ATTACK_RANGE := 70.0

const IDLE_ANIM_FPS := 6.0

# KAY (main_char2) y LINA (main_char2_female): packs a distancia sin
# animación de ataque propia — igual que "Man", disparan sin
# pose especial, sólo encarando al objetivo. Usan un esquema de 6
# direcciones (sin izquierda/derecha puras, sólo diagonales + arriba/
# abajo) en vez de las 8 de DIR_NAMES o las 4 de AXEL. Los nombres de
# archivo entre el pack male y female no son consistentes en
# mayúsculas, por eso van hardcodeados acá en vez de armarse con %s.
const RANGED_FRAME_SIZE := Vector2(48, 64)
const RANGED_FRAME_COUNT := 8
const RANGED_SCALE := 1.05
const RANGED_SKINS := {
	"main_char2": {
		"base_path": "res://assets/main_characters/main_char2/The Male adventurer - Free/",
		"idle_files": {
			"down": "Idle/idle_down.png", "up": "Idle/idle_up.png",
			"left_down": "Idle/idle_left_down.png", "left_up": "Idle/idle_left_up.png",
			"right_down": "Idle/idle_right_down.png", "right_up": "Idle/idle_right_up.png",
		},
		"run_files": {
			"down": "Walk/walk_down.png", "up": "Walk/walk_up.png",
			"left_down": "Walk/walk_left_down.png", "left_up": "Walk/walk_left_up.png",
			"right_down": "Walk/walk_right_down.png", "right_up": "Walk/walk_right_up.png",
		},
	},
	"main_char2_female": {
		"base_path": "res://assets/main_characters/main_char2_female/The Female Adventurer - Free/",
		"idle_files": {
			"down": "Idle/Idle_Down.png", "up": "Idle/Idle_Up.png",
			"left_down": "Idle/Idle_Left_Down.png", "left_up": "Idle/Idle_Left_Up.png",
			"right_down": "Idle/Idle_Right_Down.png", "right_up": "Idle/Idle_Right_Up.png",
		},
		"run_files": {
			"down": "Walk/walk_Down.png", "up": "Walk/walk_Up.png",
			"left_down": "Walk/walk_Left_Down.png", "left_up": "Walk/walk_Left_Up.png",
			"right_down": "Walk/walk_Right_Down.png", "right_up": "Walk/walk_Right_Up.png",
		},
	},
}

# Stats — se modifican con upgrades
var max_hp: float = 100.0
var hp: float
var move_speed: float = BASE_SPEED
var damage_mult: float = 1.0
var atk_speed_mult: float = 1.0
var magnet_radius: float = XP_MAGNET_RADIUS
var hp_regen_per_sec: float = 0.0
var projectiles_per_shot: int = 1
## "Disparo a distancia" — UNA sola carta que después se ramifica en
## dos caminos separados, el jugador elige cuál priorizar en cada
## level-up:
##   - ranged_power_level (id "ranged_power"): sube el daño y el
##     color del disparo, hasta rosado con más partículas en el nivel
##     máximo (ver shot_projectile.gd LEVEL_BODY).
##   - ranged_bonus_shots (id "ranged_count"): más disparos por ráfaga.
## En AXEL, esta carta es lo que le da algo de alcance a un build
## 100% melee; en un personaje ranged es simplemente más/mejores disparos.
const RANGED_MAX_POWER_LEVEL := 5
const RANGED_MAX_BONUS_SHOTS := 4
var ranged_power_level: int = 0
var ranged_bonus_shots: int = 0
## Carta "instinto asesino" — +10% daño automático en cada level up
## futuro (además de lo que ya sumen las cartas de daño normales).
var _damage_scales_with_level: bool = false
## Carta "meteoritos"
var _has_meteors: bool = false
var _meteor_interval: float = METEOR_BASE_INTERVAL
var _meteor_cd: float = 3.0
## Carta "espadas voladoras" — el rig se crea una sola vez; picks
## repetidos lo potencian en vez de crear un segundo rig. Sin tipo
## explícito a propósito: el script real se le pega en runtime con
## set_script(), y el chequeo estático de GDScript no sabe de eso —
## tiparlo como Node2D rompería la build (warnings-as-errors) al
## llamar .setup()/.buff(), que no existen en la clase base.
var _swords_rig = null
## Acompañante equipado en la tienda (companion.gd) — sin tipo por el
## mismo motivo que _swords_rig.
var _companion = null
var _companion_id: String = ""
## Armas nuevas (aura/hacha/rayo) — mismo patrón que _swords_rig.
var _aura = null
var _axes = null
var _lightning = null

## Build de la run (ver upgrades.gd): nivel de cada arma y pasiva que
## se tiene, y evoluciones conseguidas. Las casillas (máximo de armas/
## pasivas) y las evoluciones se calculan a partir de esto.
var weapon_levels: Dictionary = {}
var passive_levels: Dictionary = {}
var evolutions: Array[String] = []
## Evolución "lluvia de flechas": cuántos enemigos atraviesa cada flecha.
var _arrow_pierce: int = 0
var _meteors_evolved: bool = false

var active_skill: Dictionary = {}
var _skill_cd: float = 0.0
var _invuln_t: float = 0.0
var _dash_t: float = 0.0
var _dash_dir: Vector2 = Vector2.DOWN
var _dash_hit: Array = []
var _last_move_dir: Vector2 = Vector2.DOWN
var _shield_fx_t: float = 0.0

# Armadura (compra permanente en la tienda) — una barra de defensa
# que absorbe daño ANTES que la vida. No regenera durante la run.
var max_defense: float = 0.0
var defense: float = 0.0

## Historial de ids de cartas elegidas esta run, en orden — lo lee
## pause_menu.gd para la pestaña "Potenciadores" (qué se fue
## agarrando + stats actuales).
var upgrade_log: Array[String] = []

# XP / level
var level: int = 1
var xp: int = 0
var xp_to_next: int = XP_TO_NEXT_BASE

# Runtime state
var current_dir: int = 0
var _fire_cd: float = 0.0
## Al subir de nivel, el próximo disparo sale "cargado" (más grande,
## más brillante, más daño) — estilo buster cargado de Mega Man.
var _charged_shot_pending: bool = false
var _regen_accum: float = 0.0
var _run_time: float = 0.0
var _run_frame: int = 0
# Input táctil normalizado a -1..1. Lo setea TouchControls vía signal.
var _touch_input: Vector2 = Vector2.ZERO

var _idle_textures: Array[Texture2D] = []
var _run_textures: Array = []

# AXEL
var _is_axel: bool = false
# ── SWORDMAN (main_char_swordman): melee que EVOLUCIONA visualmente
# durante la run. Cada 5 niveles del player la tier del sprite sube
# (lvl1 → lvl2 → … → lvl6 al llegar a level 26+). Las tiers superiores
# tienen armadura/armas más pesadas — se siente que crecés físicamente.
const SWORDMAN_DIRS: Array[String] = ["front", "back", "side_left", "side_right"]
const SWORDMAN_FRAME_SIZE := Vector2(64, 64)
## Los sheets de idle NO son consistentes en frame count entre
## direcciones: front/side_left/side_right traen 12 frames, back
## sólo 4. Ahora _slice_sheet auto-detecta el count real por sheet
## y _apply_idle usa el size del array por dirección — así cada
## dir anima con sus frames reales sin off-by-one.
## Este valor es el MÁXIMO tolerado (upper bound) que le pedimos
## a _slice_sheet — el auto-detect lo cortará por debajo si el
## sheet tiene menos.
const SWORDMAN_IDLE_FRAMES := 12
const SWORDMAN_RUN_FRAMES := 8
# Attack: lvl 1-5 tienen 8f, lvl 6 tiene 7f. Usamos 7 como mínimo seguro.
const SWORDMAN_ATTACK_FRAMES := 7
const SWORDMAN_ATTACK_HIT_FRAME := 3
const SWORDMAN_SCALE := 1.0
const SWORDMAN_ATTACK_RANGE := 70.0
const SWORDMAN_MELEE_DAMAGE := 5.0
const SWORDMAN_MAX_TIER := 6
var _is_swordman: bool = false
var _swordman_tier: int = 1
var _swordman_facing: String = "front"
var _swordman_idle: Dictionary = {}
var _swordman_run: Dictionary = {}
var _swordman_attack: Dictionary = {}
var _swordman_attacking: bool = false
var _swordman_attack_elapsed: float = 0.0
var _swordman_hit_applied: bool = false
var _axel_idle: Dictionary = {}
var _axel_run: Dictionary = {}
var _axel_attack: Dictionary = {}
var _axel_facing: String = "down"
var _axel_attacking: bool = false
var _axel_attack_elapsed: float = 0.0
var _axel_hit_applied: bool = false
var _idle_time: float = 0.0
var _idle_frame: int = 0

# KAY / LINA
var _is_ranged_skin: bool = false
var _ranged_idle: Dictionary = {}
var _ranged_run: Dictionary = {}
var _ranged_facing: String = "down"

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _attack_area: Area2D = $AttackArea

func _ready() -> void:
	add_to_group("player")
	# Mejoras permanentes compradas en la tienda (persisten entre
	# runs) — se aplican ANTES de hp = max_hp para que la vida inicial
	# ya cuente el bonus.
	max_hp += GameState.get_bonus_max_hp()
	damage_mult += GameState.get_bonus_damage_mult()
	hp_regen_per_sec += GameState.get_bonus_regen()
	max_defense = GameState.get_bonus_max_defense()
	defense = max_defense
	hp = max_hp
	_apply_camera_zoom_for_device()
	Screen.layout_changed.connect(_on_layout_changed)
	var skin_id: String = GameState.selected_character_id
	active_skill = ACTIVE_SKILLS.get(skin_id, ACTIVE_SKILLS["main_char1"])
	_is_axel = skin_id == "main_char1"
	_is_swordman = skin_id == "swordman"
	_is_ranged_skin = RANGED_SKINS.has(skin_id)
	if _is_swordman:
		_sprite.scale = Vector2.ONE * SWORDMAN_SCALE
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_load_swordman_textures()
	elif _is_axel:
		_sprite.scale = Vector2.ONE * AXEL_SCALE
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_load_axel_textures()
	elif _is_ranged_skin:
		_sprite.scale = Vector2.ONE * RANGED_SCALE
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_load_ranged_textures(skin_id)
	else:
		for dir_name in DIR_NAMES:
			_idle_textures.append(load("res://assets/sprites/Man/rotations/" + dir_name + ".png"))
			var frames: Array[Texture2D] = []
			for i in range(8):
				frames.append(load("res://assets/sprites/Man/animations/run_v4/%s/frame_%03d.png" % [dir_name, i]))
			_run_textures.append(frames)
	_apply_idle()
	emit_signal("hp_changed", hp, max_hp)
	emit_signal("defense_changed", defense, max_defense)
	emit_signal("xp_changed", xp, xp_to_next, level)
	# Deferred: durante el _ready del player la escena nueva todavía no
	# es current_scene, y el acompañante se cuelga de ahí.
	if GameState.equipped_companion != "":
		spawn_companion.call_deferred(GameState.equipped_companion)

func spawn_companion(id: String) -> void:
	if _companion != null and is_instance_valid(_companion):
		_companion.queue_free()
	_companion = Node2D.new()
	_companion.set_script(COMPANION_SCRIPT)
	get_tree().current_scene.add_child(_companion)
	_companion.setup(self, id)
	_companion_id = id

## Los sheets son un archivo por dirección con N frames en fila, a
## diferencia del sprite "Man" que trae un archivo por frame. Se
## cortan acá con AtlasTexture en vez de bakear nada nuevo en disco.
func _slice_sheet(path: String, frame_size: Vector2, frame_count: int) -> Array[Texture2D]:
	var sheet: Texture2D = load(path)
	var frames: Array[Texture2D] = []
	if sheet == null:
		return frames
	# Defensivo: si el sheet trae MENOS frames que los pedidos (algunos
	# packs tienen 4 back vs 12 front), sólo devolvemos los reales.
	# Sino, frames "extras" quedan fuera del sheet → AtlasTexture con
	# region inválida → sprite transparente → parece que "desaparece"
	# el personaje mirando esa dirección.
	var actual: int = int(sheet.get_width() / frame_size.x)
	var safe_count: int = min(frame_count, actual) if actual > 0 else frame_count
	for i in range(safe_count):
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * frame_size.x, 0, frame_size.x, frame_size.y)
		frames.append(atlas)
	return frames

## Swordman: 4-direction melee que evoluciona por tier (lvl1..lvl6).
## Se carga tier N según el level del player. Convención:
##   - Level 1-5 → tier 1
##   - Level 6-10 → tier 2
##   - Level 11-15 → tier 3
##   - Level 16-20 → tier 4
##   - Level 21-25 → tier 5
##   - Level 26+ → tier 6
## Cada evolución cambia de sprites in-place — se siente el poder crecer.
func _tier_for_level(lvl: int) -> int:
	return clampi(1 + (lvl - 1) / 5, 1, SWORDMAN_MAX_TIER)

## Path builder — el folder es INCONSISTENTE entre tiers:
## Lvl 1-3 usan prefijo "Swordsman_lvlN_Anim/" (ej Swordsman_lvl1_Idle/)
## Lvl 4-6 usan sólo "Anim/" (ej Idle/)
## Los filenames adentro también varían — "attack" es lowercase, el
## resto capitalizado. Se maneja acá para no ensuciar el caller.
func _swordman_path(tier: int, anim: String, direction: String) -> String:
	var base := "res://assets/sprites/swordman/Swordsman_lvl%d/" % tier
	var folder := anim if tier >= 4 else "Swordsman_lvl%d_%s" % [tier, anim]
	var fname := "Swordsman_lvl%d_%s_%s.png" % [tier, anim if anim != "Attack" else "attack", direction]
	return "%s%s/%s" % [base, folder, fname]

func _load_swordman_textures() -> void:
	_swordman_tier = _tier_for_level(level)
	_swordman_idle.clear()
	_swordman_run.clear()
	_swordman_attack.clear()
	for dir_name in SWORDMAN_DIRS:
		_swordman_idle[dir_name] = _slice_sheet(_swordman_path(_swordman_tier, "Idle", dir_name), SWORDMAN_FRAME_SIZE, SWORDMAN_IDLE_FRAMES)
		_swordman_run[dir_name] = _slice_sheet(_swordman_path(_swordman_tier, "Run", dir_name), SWORDMAN_FRAME_SIZE, SWORDMAN_RUN_FRAMES)
		_swordman_attack[dir_name] = _slice_sheet(_swordman_path(_swordman_tier, "Attack", dir_name), SWORDMAN_FRAME_SIZE, SWORDMAN_ATTACK_FRAMES)

## Chequea si el level actual del player amerita subir de tier de sprite
## — se llama desde _level_up. Si sube, recarga texturas in-place.
func _maybe_upgrade_swordman_tier() -> void:
	if not _is_swordman: return
	var new_tier := _tier_for_level(level)
	if new_tier != _swordman_tier:
		_swordman_tier = new_tier
		_load_swordman_textures()

func _load_axel_textures() -> void:
	for dir_name in AXEL_DIRS:
		_axel_idle[dir_name] = _slice_sheet(AXEL_BASE_PATH + "IDLE/idle_%s.png" % dir_name, AXEL_FRAME_SIZE, AXEL_FRAME_COUNT)
		_axel_run[dir_name] = _slice_sheet(AXEL_BASE_PATH + "RUN/run_%s.png" % dir_name, AXEL_FRAME_SIZE, AXEL_FRAME_COUNT)
		_axel_attack[dir_name] = _slice_sheet(AXEL_BASE_PATH + "ATTACK 1/attack1_%s.png" % dir_name, AXEL_FRAME_SIZE, AXEL_FRAME_COUNT)

func _load_ranged_textures(skin_id: String) -> void:
	var data: Dictionary = RANGED_SKINS[skin_id]
	var base: String = data["base_path"]
	for dir_key in data["idle_files"]:
		_ranged_idle[dir_key] = _slice_sheet(base + data["idle_files"][dir_key], RANGED_FRAME_SIZE, RANGED_FRAME_COUNT)
	for dir_key in data["run_files"]:
		_ranged_run[dir_key] = _slice_sheet(base + data["run_files"][dir_key], RANGED_FRAME_SIZE, RANGED_FRAME_COUNT)

## AXEL sólo tiene 4 direcciones — el facing se resuelve por el eje
## dominante del vector en vez de los 8 pasos de _vec_to_dir().
func _dir_name_from_vec(v: Vector2) -> String:
	if abs(v.x) > abs(v.y):
		return "right" if v.x > 0.0 else "left"
	return "down" if v.y > 0.0 else "up"

## KAY/LINA no tienen izquierda/derecha puras, sólo diagonales +
## arriba/abajo — da exactamente las 6 claves que existen en
## RANGED_SKINS (down, up, left_down, left_up, right_down, right_up).
## Un movimiento puramente horizontal cae en "_down" por convención.
func _side_dir_key(v: Vector2) -> String:
	var side := ""
	if v.x > 0.01:
		side = "right"
	elif v.x < -0.01:
		side = "left"
	var vert := ""
	if v.y > 0.01:
		vert = "down"
	elif v.y < -0.01:
		vert = "up"
	if side == "":
		return vert if vert != "" else "down"
	if vert == "":
		return side + "_down"
	return side + "_" + vert

func set_touch_input(v: Vector2) -> void:
	_touch_input = v

## Flechas (InputMap ui_*) + WASD. WASD no está en el InputMap del
## proyecto, así que se lee por posición física de tecla (no por
## layout) para no tocar project.godot a mano — is_physical_key_pressed
## así funciona igual en QWERTY/AZERTY/etc. Sumar ambos es seguro: si
## se mantienen flecha y WASD juntas, moving/normalized() más abajo
## ya manejan la magnitud >1.
func _keyboard_input() -> Vector2:
	var v := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down"),
	)
	v.x += (1.0 if Input.is_physical_key_pressed(KEY_D) else 0.0) \
		- (1.0 if Input.is_physical_key_pressed(KEY_A) else 0.0)
	v.y += (1.0 if Input.is_physical_key_pressed(KEY_S) else 0.0) \
		- (1.0 if Input.is_physical_key_pressed(KEY_W) else 0.0)
	return v

## En móvil la pantalla es chica y queremos ver menos mundo pero
## más detalle — subimos el zoom. En desktop 2.0 (match sandbox),
## mobile 2.4. Antes eran 1.5/2.4 pero el 1.5 se sentía muy lejos.
## Cuántas unidades de mundo entran en el lado corto de la pantalla —
## más chico = cámara más cerca. En teléfono va más cerca que en PC: la
## pantalla es chica y el héroe se perdía entre los bichos. Se calcula
## sobre el viewport lógico que arma el autoload Screen, así da lo
## mismo la resolución real o si el teléfono está vertical/horizontal.
const VIEW_SHORT_UNITS_DESKTOP := 335.0
const VIEW_SHORT_UNITS_PHONE := 200.0

func _on_layout_changed(_compact: bool) -> void:
	_apply_camera_zoom_for_device()

func _apply_camera_zoom_for_device() -> void:
	var cam: Camera2D = $Camera2D
	var vp := get_viewport().get_visible_rect().size
	var units: float = VIEW_SHORT_UNITS_PHONE if Screen.is_phone else VIEW_SHORT_UNITS_DESKTOP
	var z: float = minf(vp.x, vp.y) / units
	cam.zoom = Vector2(z, z)
	# CRÍTICO: force ser la cámara current. Sin esto, la PreviewCamera
	# de world.tscn (zoom 0.35, usada para F6 de solo el mundo) le gana
	# porque entra al tree antes. Con esto la del player siempre wins,
	# tanto en sandbox como en el juego real.
	cam.make_current()

# ── Cámara: zoom con Q/E y rueda del mouse ──────────────────────

const CAM_ZOOM_MIN := 0.3
const CAM_ZOOM_MAX := 4.0
const CAM_ZOOM_KEY_STEP := 0.06     # Q/E: cambio por frame mientras presionado
const CAM_ZOOM_WHEEL_STEP := 0.15   # rueda: cambio por notch

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var cam: Camera2D = $Camera2D
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(cam.zoom.x + CAM_ZOOM_WHEEL_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(cam.zoom.x - CAM_ZOOM_WHEEL_STEP)

func _process(delta: float) -> void:
	# Q aleja, E acerca — mismo esquema que sandbox.gd.
	var cam: Camera2D = $Camera2D
	if Input.is_key_pressed(KEY_Q):
		_set_zoom(cam.zoom.x - CAM_ZOOM_KEY_STEP)
	elif Input.is_key_pressed(KEY_E):
		_set_zoom(cam.zoom.x + CAM_ZOOM_KEY_STEP)
	_update_shake(cam, delta)

# ── Sacudida de cámara ──────────────────────────────────────────

var _shake_strength: float = 0.0

## Sacude la cámara `strength` unidades de mundo y decae sola. Si ya
## está sacudiendo más fuerte, no la achica.
func shake(strength: float) -> void:
	_shake_strength = maxf(_shake_strength, strength)

func _update_shake(cam: Camera2D, delta: float) -> void:
	if _shake_strength > 0.1:
		cam.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_strength
		_shake_strength = lerpf(_shake_strength, 0.0, minf(1.0, 12.0 * delta))
	elif cam.offset != Vector2.ZERO:
		_shake_strength = 0.0
		cam.offset = Vector2.ZERO

func _set_zoom(value: float) -> void:
	# clampf en vez de clamp — el proyecto tiene warnings como errores
	# y el clamp untyped devuelve Variant (parser bomb).
	var clamped: float = clampf(value, CAM_ZOOM_MIN, CAM_ZOOM_MAX)
	$Camera2D.zoom = Vector2(clamped, clamped)

func _physics_process(delta: float) -> void:
	# Movement — teclado tiene prioridad; si no hay tecla, usamos touch.
	var kb := _keyboard_input()
	var input: Vector2 = kb if kb != Vector2.ZERO else _touch_input
	var moving := input != Vector2.ZERO
	if moving:
		input = input.normalized()
		var new_dir := _vec_to_dir(input)
		if new_dir != current_dir:
			current_dir = new_dir
			_run_frame = 0
			_run_time = 0.0
	if moving:
		_last_move_dir = input
	# Aceleración en vez de velocidad instantánea — un toque de peso
	# natural sin perder respuesta (llega a top speed en ~0.11s).
	velocity = velocity.move_toward(input * move_speed, ACCELERATION * delta)
	_tick_active_skill(delta)
	move_and_slide()

	# Sprite: ataque (si está en curso) tiene prioridad sobre correr/
	# idle — el swing se ve completo aunque sigas esquivando.
	if _axel_attacking:
		_update_axel_attack(delta)
	elif _swordman_attacking:
		_update_swordman_attack(delta)
	elif moving:
		_run_time += delta
		if _run_time >= 1.0 / RUN_FPS:
			_run_time = 0.0
			_run_frame = (_run_frame + 1) % 8
		if _is_axel:
			_axel_facing = _dir_name_from_vec(input)
			_sprite.texture = _axel_run[_axel_facing][_run_frame]
		elif _is_swordman:
			_swordman_facing = _swordman_dir_from_vec(input)
			_sprite.texture = _swordman_run[_swordman_facing][_run_frame % SWORDMAN_RUN_FRAMES]
		elif _is_ranged_skin:
			_ranged_facing = _side_dir_key(input)
			_sprite.texture = _ranged_run[_ranged_facing][_run_frame]
		else:
			_sprite.texture = _run_textures[current_dir][_run_frame]
	else:
		_apply_idle(delta)

	if moving:
		Realtime.send_move(position.x, position.y, 1, current_dir)

	# Regen pasivo
	if hp_regen_per_sec > 0.0 and hp < max_hp:
		_regen_accum += delta
		if _regen_accum >= REGEN_TICK:
			heal(hp_regen_per_sec * REGEN_TICK)
			_regen_accum = 0.0

	# Auto-fire
	_fire_cd -= delta
	if _fire_cd <= 0.0:
		_auto_fire()

	# Carta "meteoritos"
	if _has_meteors:
		_meteor_cd -= delta
		if _meteor_cd <= 0.0:
			_spawn_meteor()
			_meteor_cd = _meteor_interval

	# Magnetismo XP
	_magnet_orbs()

func _auto_fire() -> void:
	var target := _nearest_monster()
	if target == null:
		# Sin blanco cerca — reintentamos rápido, no gastamos el CD
		_fire_cd = 0.15
		return
	# Personajes melee: si el target está fuera del rango de la espada,
	# no hacemos la animación de attack (nos trabaría), PERO si ya
	# tienen desbloqueada la carta "disparo a distancia" igual sale la
	# flecha — sino nunca dispararían nada a distancia aunque tengan la
	# carta.
	var is_melee_char := _is_axel or _is_swordman
	var melee_range: float = SWORDMAN_ATTACK_RANGE if _is_swordman else AXEL_ATTACK_RANGE
	var to_target_dist: float = global_position.distance_to(target.global_position)
	var out_of_melee_range: bool = is_melee_char and to_target_dist > melee_range
	if out_of_melee_range and ranged_bonus_shots == 0:
		# Sin ranged bonus no hay nada para hacer a distancia — no
		# gastamos el CD, reintentamos rápido.
		_fire_cd = 0.15
		return
	_fire_cd = AUTO_FIRE_INTERVAL / atk_speed_mult
	# Sin sonido de ataque — sonaban muy fuerte disparando/atacando
	# tan seguido (cada AUTO_FIRE_INTERVAL, a veces varias veces por
	# segundo con atk_speed alto).
	var to_target: Vector2 = (target.global_position - global_position).normalized()
	# Face hacia el target así el sprite gira acorde
	current_dir = _vec_to_dir(to_target)
	if _is_swordman:
		# Si está en rango melee, hace el sablazo. Si sólo pudo llegar
		# acá por tener ranged (out_of_melee_range), skippeamos la anim
		# — sino se trabaría en el swing sin tocar a nadie.
		if not out_of_melee_range:
			_start_swordman_attack(to_target)
		# La carta "disparo a distancia" también le suma disparos al
		# swordman, igual que en AXEL — no reemplaza el melee.
		if ranged_bonus_shots > 0:
			_fire_shot(to_target, ranged_bonus_shots)
	elif _is_axel:
		if not out_of_melee_range:
			_start_axel_attack(to_target)
		# Carta "disparo a distancia": el espadachín también larga
		# disparos, además del sablazo — no reemplaza el melee.
		if ranged_bonus_shots > 0:
			_fire_shot(to_target, ranged_bonus_shots)
	else:
		if _is_ranged_skin:
			_ranged_facing = _side_dir_key(to_target)
		_fire_shot(to_target, projectiles_per_shot + ranged_bonus_shots)

func _fire_shot(to_target: Vector2, count: int) -> void:
	# El primer disparo de la ráfaga después de subir de nivel sale
	# "cargado" — más grande, más brillante, más daño.
	var charged := _charged_shot_pending
	_charged_shot_pending = false
	# Multishot: proyectiles con un ligero spread
	for i in range(count):
		var offset := (i - (count - 1) / 2.0) * AUTO_FIRE_SPREAD
		var dir := to_target.rotated(offset)
		var shot = SHOT_SCENE.instantiate()
		get_tree().current_scene.add_child(shot)
		shot.global_position = global_position + dir * 24.0
		# set_damage ANTES de setup(): setup() multiplica el daño ya
		# escalado si charged, en vez de que set_damage lo pise.
		if shot.has_method("set_damage"):
			shot.set_damage(shot.DAMAGE * damage_mult * (1.0 + ranged_power_level * 0.3))
		shot.setup(dir, charged and i == 0, ranged_power_level)
		if _arrow_pierce > 0:
			shot.pierce = _arrow_pierce
			shot.source = "lluvia_flechas"

func _spawn_meteor() -> void:
	# Evolución "apocalipsis": 3 meteoros por tanda, más grandes y fuertes.
	for i in range(3 if _meteors_evolved else 1):
		var monsters := get_tree().get_nodes_in_group("monster")
		var target_pos: Vector2
		if monsters.is_empty():
			target_pos = global_position + Vector2(randf_range(-200.0, 200.0), randf_range(-200.0, 200.0))
		else:
			var m = monsters[randi() % monsters.size()]
			target_pos = m.global_position + Vector2(randf_range(-40.0, 40.0), randf_range(-40.0, 40.0))
		# Sin tipo explícito (mismo motivo que _swords_rig más arriba):
		# .damage no existe en Node2D, sólo en el script que le pegamos.
		var meteor = Node2D.new()
		meteor.set_script(METEOR_SCRIPT)
		get_tree().current_scene.add_child(meteor)
		meteor.global_position = target_pos
		meteor.damage = METEOR_DAMAGE * damage_mult * (1.5 if _meteors_evolved else 1.0)
		if _meteors_evolved:
			meteor.impact_radius = 105.0
			meteor.source = "apocalipsis"

# ── AXEL: ataque melee ────────────────────────────────────────────

func _start_axel_attack(to_target: Vector2) -> void:
	_axel_facing = _dir_name_from_vec(to_target)
	_axel_attacking = true
	_axel_attack_elapsed = 0.0
	_axel_hit_applied = false

## Avanza la animación de attack1 sincronizada con el intervalo de
## ataque real (así atk_speed también acelera el swing visual) y
## aplica daño una sola vez, cuando el frame llega al tajo.
func _update_axel_attack(delta: float) -> void:
	_axel_attack_elapsed += delta
	var duration: float = AUTO_FIRE_INTERVAL / atk_speed_mult
	var t: float = clamp(_axel_attack_elapsed / duration, 0.0, 1.0)
	var frame: int = min(int(t * AXEL_FRAME_COUNT), AXEL_FRAME_COUNT - 1)
	_sprite.texture = _axel_attack[_axel_facing][frame]
	if not _axel_hit_applied and frame >= AXEL_ATTACK_HIT_FRAME:
		_axel_hit_applied = true
		_axel_apply_melee_damage()
	if t >= 1.0:
		_axel_attacking = false

## El alcance real lo define el CircleShape2D de AttackArea (más
## grande que la silueta del personaje a propósito, ver player.tscn)
## en vez del alcance visual del sprite del tajo — un swing corto en
## dibujo puede seguir conectando con algo un poco más lejos.
func _axel_apply_melee_damage() -> void:
	for body in _attack_area.get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(AXEL_MELEE_DAMAGE * damage_mult, "ataque")

# ── SWORDMAN: ataque melee con evolución por tier ────────────────

func _start_swordman_attack(to_target: Vector2) -> void:
	_swordman_facing = _swordman_dir_from_vec(to_target)
	_swordman_attacking = true
	_swordman_attack_elapsed = 0.0
	_swordman_hit_applied = false

## Anima el swing y aplica daño una sola vez, en el frame donde cae
## el tajo (SWORDMAN_ATTACK_HIT_FRAME). El daño escala por tier: cada
## tier de sprite suma 1.2x más daño — sentís que la evolución te da
## mucho más punch, no sólo visual.
func _update_swordman_attack(delta: float) -> void:
	_swordman_attack_elapsed += delta
	var duration: float = AUTO_FIRE_INTERVAL / atk_speed_mult
	var t: float = clamp(_swordman_attack_elapsed / duration, 0.0, 1.0)
	var frame: int = min(int(t * SWORDMAN_ATTACK_FRAMES), SWORDMAN_ATTACK_FRAMES - 1)
	_sprite.texture = _swordman_attack[_swordman_facing][frame]
	if not _swordman_hit_applied and frame >= SWORDMAN_ATTACK_HIT_FRAME:
		_swordman_hit_applied = true
		_swordman_apply_melee_damage()
	if t >= 1.0:
		_swordman_attacking = false

func _swordman_apply_melee_damage() -> void:
	# Damage boost por tier: tier 1 = 1.0x, tier 6 = 2.2x (0.24x extra per tier)
	var tier_mult: float = 1.0 + (_swordman_tier - 1) * 0.24
	var dmg: float = SWORDMAN_MELEE_DAMAGE * damage_mult * tier_mult
	for body in _attack_area.get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(dmg, "ataque")

## Mapea un vector de movimiento/target a la dirección del sprite
## swordman (front/back/side_left/side_right). Usa el eje dominante
## para clasificar en 4 cuadrantes.
func _swordman_dir_from_vec(v: Vector2) -> String:
	if abs(v.x) > abs(v.y):
		return "side_left" if v.x < 0 else "side_right"
	return "back" if v.y < 0 else "front"

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
	if _damage_scales_with_level:
		damage_mult *= 1.10
	# Si sos swordman, chequeamos si toca subir de tier de sprite
	# (cada 5 levels). La evolución cambia el look in-place.
	_maybe_upgrade_swordman_tier()
	# El próximo disparo sale cargado — el "premio" visual de subir de
	# nivel, estilo buster cargado de Mega Man.
	_charged_shot_pending = true
	emit_signal("leveled_up", level)

func apply_upgrade(id: String) -> void:
	upgrade_log.append(id)
	if Upgrades.PASSIVES.has(id):
		passive_levels[id] = passive_level(id) + 1
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
		"multishot":  projectiles_per_shot = min(4, projectiles_per_shot + 1)
		# Desbloqueo — arranca los dos caminos en su primer escalón.
		"ranged_bonus":
			ranged_power_level = 1
			ranged_bonus_shots = max(ranged_bonus_shots, 1)
			weapon_levels["disparo"] = ranged_power_level
		# Camino "más fuerte": sube potencia + color del disparo.
		"ranged_power":
			ranged_power_level = min(RANGED_MAX_POWER_LEVEL, ranged_power_level + 1)
			weapon_levels["disparo"] = ranged_power_level
		# Camino "más cantidad": suma otro disparo a la ráfaga.
		"ranged_count": ranged_bonus_shots = min(RANGED_MAX_BONUS_SHOTS, ranged_bonus_shots + 1)
		"level_damage": _damage_scales_with_level = true
		"meteors":
			if not _has_meteors:
				_has_meteors = true
			else:
				_meteor_interval = max(2.0, _meteor_interval - 0.7)
			weapon_levels["meteoros"] = mini(Upgrades.MAX_LEVEL, weapon_level("meteoros") + 1)
		# Desbloqueo — crea el rig la primera vez.
		"flying_swords":
			if _swords_rig == null:
				_swords_rig = Node2D.new()
				_swords_rig.set_script(FLYING_SWORDS_RIG_SCRIPT)
				get_tree().current_scene.add_child(_swords_rig)
				_swords_rig.setup(self)
			weapon_levels["espadas"] = _swords_rig.level
		# Camino "más fuerte": sube nivel/color/daño de cada espada.
		"flying_swords_power":
			if _swords_rig != null:
				_swords_rig.buff()
				weapon_levels["espadas"] = _swords_rig.level
		# Camino "más cantidad": más espadas atacan a la vez por ciclo.
		"flying_swords_count":
			if _swords_rig != null:
				_swords_rig.buff_count()
		# Armas nuevas: la primera carta la crea, las siguientes le suben
		# el nivel.
		"aura":
			_aura = _level_weapon(_aura, AURA_SCRIPT, "aura", true)
		"hacha":
			_axes = _level_weapon(_axes, AXE_SCRIPT, "hacha", false)
		"rayo":
			_lightning = _level_weapon(_lightning, LIGHTNING_SCRIPT, "rayo", false)
		# Relleno cuando ya no queda nada por mejorar.
		"coins":
			GameState.add_run_currency(25)
		"heal":
			heal(max_hp * 0.3)
	upgrades_changed.emit(build_summary())

## Crea el arma la primera vez (como hijo del player si sigue su
## posición — el aura — o de la escena si no) o le sube el nivel.
func _level_weapon(node, script: Script, id: String, attach_to_player: bool):
	var lvl: int = mini(Upgrades.MAX_LEVEL, weapon_level(id) + 1)
	weapon_levels[id] = lvl
	if node == null:
		node = Node2D.new()
		node.set_script(script)
		if attach_to_player:
			add_child(node)
		else:
			get_tree().current_scene.add_child(node)
		node.setup(self)
	node.set_level(lvl)
	return node

# ── HP ──────────────────────────────────────────────────────────

## La armadura comprada en la tienda da una barra de defensa que
## absorbe daño ANTES que la vida (no regenera durante la run — es
## efectivamente HP extra "gratis" cada partida).
func take_damage(amount: float) -> void:
	if hp <= 0.0: return
	# Dash/voltereta/escudo: invulnerable mientras dura.
	if _invuln_t > 0.0: return
	Audio.play_sfx("player_hurt", global_position, 0.1)
	shake(3.0)
	var remaining := amount
	if defense > 0.0:
		var absorbed: float = min(defense, remaining)
		defense -= absorbed
		remaining -= absorbed
		emit_signal("defense_changed", defense, max_defense)
		_sprite.modulate = Color(0.5, 0.7, 1.6)
		create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.15)
	if remaining > 0.0:
		hp = max(0.0, hp - remaining)
		emit_signal("hp_changed", hp, max_hp)
		# Flash rojo brevísimo
		_sprite.modulate = Color(1.6, 0.5, 0.5)
		create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.2)
	if hp <= 0.0:
		Audio.play_sfx("player_death", global_position)
		emit_signal("died")

func heal(amount: float) -> void:
	hp = min(max_hp, hp + amount)
	emit_signal("hp_changed", hp, max_hp)

# ── Estado consultado por level_up_menu.gd para filtrar cartas ──────

## true si el player dispara algo de alguna forma ahora mismo — todo
## personaje ranged, o AXEL sólo si ya tiene "disparo a distancia".
## Sin esto, cartas como "+1 proyectil" podían salir sorteadas antes
## de que AXEL tuviera siquiera un disparo que multiplicar.
func has_ranged_attack() -> bool:
	# Swordman también es melee puro por default — como AXEL, sólo
	# tiene disparo si tomó la carta "disparo a distancia".
	if _is_axel or _is_swordman:
		return ranged_power_level > 0
	return true

func has_flying_swords() -> bool:
	return _swords_rig != null

## Cuántas espadas atacan a la vez por ciclo (carta "más cantidad").
## 0 si todavía no tenemos la carta base de espadas.
func sword_attacks_per_cycle() -> int:
	return _swords_rig.attacks_per_cycle if _swords_rig != null else 0

## 0 si todavía no tenemos la carta. Lo usa level_up_menu.gd para
## dejar de ofrecer "espadas voladoras" una vez llegado al máximo.
func sword_level() -> int:
	return _swords_rig.level if _swords_rig != null else 0

func has_meteors() -> bool:
	return _has_meteors

# ── Habilidad activa ────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		use_active_skill()
		get_viewport().set_input_as_handled()

func skill_ready() -> bool:
	return _skill_cd <= 0.0

func use_active_skill() -> void:
	if _skill_cd > 0.0 or hp <= 0.0 or get_tree().paused or active_skill.is_empty():
		return
	_skill_cd = active_skill["cooldown"]
	match active_skill["id"]:
		"dash":
			_start_dash(0.19)
			_invuln_t = maxf(_invuln_t, 0.3)
			Audio.play_sfx("sword_swing", global_position)
		"roll":
			_start_dash(0.16)
			_invuln_t = maxf(_invuln_t, 1.0)
			Audio.play_sfx("sword_swing", global_position)
		"volley":
			for i in range(VOLLEY_ARROWS):
				_fire_single_shot(Vector2.RIGHT.rotated(TAU * i / VOLLEY_ARROWS), 1.5)
			Audio.play_sfx("meteor_whoosh", global_position)
		"shield":
			_invuln_t = maxf(_invuln_t, 2.0)
			_shield_fx_t = 0.0001
			for m in get_tree().get_nodes_in_group("monster"):
				if is_instance_valid(m) and global_position.distance_to(m.global_position) <= SHIELD_RADIUS:
					var away: Vector2 = (m.global_position - global_position).normalized()
					m.take_damage(SHIELD_DAMAGE * damage_mult, "habilidad")
					if m.has_method("knockback"):
						m.knockback(away, 420.0)
			shake(4.0)
			Audio.play_sfx("meteor_impact", global_position)
	skill_cooldown_changed.emit(_skill_cd, active_skill["cooldown"])

func _start_dash(duration: float) -> void:
	_dash_dir = _last_move_dir.normalized() if _last_move_dir != Vector2.ZERO else Vector2.DOWN
	_dash_t = duration
	_dash_hit.clear()
	_spawn_afterimage()

## Un disparo suelto en `dir` (la ráfaga de KAY) — mismo proyectil que
## el disparo automático, más fuerte.
func _fire_single_shot(dir: Vector2, dmg_mult: float) -> void:
	var shot = SHOT_SCENE.instantiate()
	get_tree().current_scene.add_child(shot)
	shot.global_position = global_position + dir * 20.0
	shot.set_damage(shot.DAMAGE * damage_mult * dmg_mult * (1.0 + ranged_power_level * 0.3))
	shot.setup(dir, false, maxi(1, ranged_power_level))
	shot.source = "habilidad"

func _tick_active_skill(delta: float) -> void:
	if _skill_cd > 0.0:
		_skill_cd = maxf(0.0, _skill_cd - delta)
		skill_cooldown_changed.emit(_skill_cd, active_skill.get("cooldown", 1.0))
	if _invuln_t > 0.0:
		_invuln_t -= delta
		# Parpadeo mientras sos invulnerable.
		_sprite.self_modulate.a = 0.45 if int(_invuln_t * 16.0) % 2 == 0 else 1.0
		if _invuln_t <= 0.0:
			_sprite.self_modulate.a = 1.0
	if _shield_fx_t > 0.0:
		_shield_fx_t += delta
		if _shield_fx_t > 2.0:
			_shield_fx_t = 0.0
		queue_redraw()
	if _dash_t > 0.0:
		_dash_t -= delta
		velocity = _dash_dir * DASH_SPEED
		if int(_dash_t * 60.0) % 4 == 0:
			_spawn_afterimage()
		if active_skill.get("id", "") == "dash":
			for m in get_tree().get_nodes_in_group("monster"):
				if is_instance_valid(m) and not (m in _dash_hit) and global_position.distance_to(m.global_position) < 28.0:
					_dash_hit.append(m)
					m.take_damage(DASH_DAMAGE * damage_mult, "habilidad")

## Copia fantasma del sprite que se desvanece — estela del dash.
func _spawn_afterimage() -> void:
	var ghost := Sprite2D.new()
	ghost.texture = _sprite.texture
	ghost.scale = _sprite.scale
	ghost.flip_h = _sprite.flip_h
	ghost.offset = _sprite.offset
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.modulate = Color(0.6, 0.85, 1.0, 0.55)
	get_tree().current_scene.add_child(ghost)
	ghost.global_position = _sprite.global_position
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tw.tween_callback(ghost.queue_free)

## Burbuja del escudo divino (GAROTH) mientras dura.
func _draw() -> void:
	if _shield_fx_t <= 0.0:
		return
	var a: float = clampf(1.0 - _shield_fx_t / 2.0, 0.0, 1.0)
	var ring: float = minf(1.0, _shield_fx_t / 0.25) * SHIELD_RADIUS
	if _shield_fx_t < 0.3:
		draw_arc(Vector2.ZERO, ring, 0.0, TAU, 40, Color(1.0, 0.95, 0.6, 1.0 - _shield_fx_t / 0.3), 3.0, false)
	draw_circle(Vector2(0, -8), 26.0, Color(0.6, 0.85, 1.0, 0.18 * a + 0.05))
	draw_arc(Vector2(0, -8), 26.0, 0.0, TAU, 32, Color(0.75, 0.92, 1.0, 0.6 * a + 0.2), 2.0, false)

# ── Build: casillas, niveles y evoluciones (ver upgrades.gd) ────────

func weapon_level(id: String) -> int:
	return weapon_levels.get(id, 0)

func passive_level(id: String) -> int:
	return passive_levels.get(id, 0)

func weapons_owned() -> int:
	return weapon_levels.size()

func passives_owned() -> int:
	return passive_levels.size()

func has_evolution(id: String) -> bool:
	return id in evolutions

func has_companion(id: String) -> bool:
	return _companion != null and is_instance_valid(_companion) and _companion_id == id

## Aplica una evolución (la da el cofre, ver chest_popup.gd).
func evolve(evo_id: String) -> void:
	if evo_id in evolutions:
		return
	evolutions.append(evo_id)
	match evo_id:
		"lluvia_flechas":
			_arrow_pierce = 3
			ranged_bonus_shots += 2
		"tormenta_espadas":
			if _swords_rig != null:
				_swords_rig.evolve()
		"apocalipsis":
			_meteors_evolved = true
		"santuario":
			if _aura != null:
				_aura.evolve()
		"torbellino":
			if _axes != null:
				_axes.evolve()
		"tormenta_electrica":
			if _lightning != null:
				_lightning.evolve()
		"gallina_dorada":
			if _companion != null and is_instance_valid(_companion):
				_companion.evolve()
	upgrades_changed.emit(build_summary())

## Casillas para la barra de mejoras del HUD: primero armas (con el
## ícono de su evolución si evolucionó), después pasivas.
func build_summary() -> Array:
	var out: Array = []
	for w in weapon_levels:
		var evo := Upgrades.evolution_of(self, w)
		var icon: String = Upgrades.EVOLUTIONS[evo]["icon"] if evo != "" \
			else Upgrades.card(Upgrades.WEAPONS[w]["unlock"]).get("icon", "")
		out.append({"icon": icon, "level": weapon_levels[w], "evolved": evo != ""})
	for p in passive_levels:
		out.append({"icon": Upgrades.card(p).get("icon", ""), "level": passive_levels[p], "evolved": false})
	if has_evolution("gallina_dorada"):
		out.append({"icon": Upgrades.EVOLUTIONS["gallina_dorada"]["icon"], "level": 0, "evolved": true})
	return out

## Primer frame del idle mirando a cámara — el HUD lo usa de retrato.
## Para el swordman refleja el tier actual (evoluciona con el nivel).
func portrait_texture() -> Texture2D:
	var frames: Array = []
	if _is_swordman:
		frames = _swordman_idle.get("front", [])
	elif _is_axel:
		frames = _axel_idle.get("down", [])
	elif _is_ranged_skin:
		frames = _ranged_idle.get("down", [])
	else:
		frames = _idle_textures
	return frames[0] if not frames.is_empty() else null

# ── Utils ───────────────────────────────────────────────────────

func _apply_idle(delta: float = 0.0) -> void:
	if _axel_attacking or _swordman_attacking:
		return
	if _is_axel:
		_idle_time += delta
		if _idle_time >= 1.0 / IDLE_ANIM_FPS:
			_idle_time = 0.0
			_idle_frame = (_idle_frame + 1) % AXEL_FRAME_COUNT
		_sprite.texture = _axel_idle[_axel_facing][_idle_frame]
	elif _is_swordman:
		# Cada dirección puede traer distinta cantidad de frames
		# (front trae 12, back trae 4 en este pack). Usamos el size
		# real del array de esa dirección para el módulo, así el
		# _idle_frame nunca se sale del rango — con constante fija
		# el sprite "desaparecía" al mirar norte.
		var facing_frames: Array = _swordman_idle[_swordman_facing]
		if facing_frames.is_empty():
			return
		_idle_time += delta
		if _idle_time >= 1.0 / IDLE_ANIM_FPS:
			_idle_time = 0.0
			_idle_frame = (_idle_frame + 1) % facing_frames.size()
		# Clamp por si _idle_frame quedó de otra dirección con más frames
		_sprite.texture = facing_frames[_idle_frame % facing_frames.size()]
	elif _is_ranged_skin:
		_idle_time += delta
		if _idle_time >= 1.0 / IDLE_ANIM_FPS:
			_idle_time = 0.0
			_idle_frame = (_idle_frame + 1) % RANGED_FRAME_COUNT
		_sprite.texture = _ranged_idle[_ranged_facing][_idle_frame]
	elif current_dir < _idle_textures.size():
		_sprite.texture = _idle_textures[current_dir]

func _vec_to_dir(v: Vector2) -> int:
	var angle := v.angle()
	var shifted := -angle + PI / 2.0
	var normalized := fmod(shifted + TAU, TAU)
	return int(round(normalized / (PI / 4.0))) % 8
