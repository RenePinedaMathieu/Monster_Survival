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

enum State { IDLE_WANDER, CHASE, WINDUP, STRIKE, COOLDOWN, CHARGE_WINDUP, CHARGE }

const XP_ORB_SCENE := preload("res://scenes/xp_orb.tscn")
const DAMAGE_NUMBER := preload("res://scenes/damage_number.gd")
const CHEST_SCRIPT := preload("res://scenes/chest.gd")
const ENEMY_SHOT_SCRIPT := preload("res://scenes/enemy_projectile.gd")
## El propio monster.tscn (para las crías de slime y las ratas que
## invocan los jefes). load() y no preload(): la escena usa este script.
const MONSTER_SCENE_PATH := "res://scenes/monster.tscn"

## Comportamientos por familia (ver _behavior_for):
##   melee     persigue y pega (ratas)
##   caster    imp: mantiene distancia y tira bolas de fuego
##   turret    beholder: ráfaga de 3 rayos desde lejos
##   charger   lizardman: avisa en naranja y embiste
##   splitter  slime: al morir se parte en 2 slimes chicos
##   phantom   fantasma: se desvanece y reaparece cerca del player
##   boss      demonios: anillo de fuego e invocación de ratas
const CHARGE_WINDUP_TIME := 0.45
const CHARGE_TIME := 0.38
const CHARGE_SPEED_MULT := 6.0
const CHARGE_DAMAGE := 14.0
const SHOT_DAMAGE := 8.0
const BOSS_SHOT_DAMAGE := 10.0

## Élite: versión dorada y más grande de un monstruo común. Mucha más
## vida, más recompensa y suelta un cofre (igual que los jefes).
const ELITE_HP_MULT := 7.0
const ELITE_SCALE := 1.35
const ELITE_COLOR := Color(1.0, 0.82, 0.3)

## Escalados x0.72 junto con BASE_SPEED del player (175 → 125) para
## bajar el ritmo general sin cambiar la dificultad: CHASE_SPEED sigue
## siendo ~26% de la velocidad del héroe, así esquivar se siente igual.
const WANDER_SPEED := 10.0
const CHASE_SPEED  := 33.0
const WANDER_CHANGE_MS := 2000
const ATTACK_RANGE := 30.0   # a esta distancia empieza el windup (x collision_scale del kind)
const DETECT_RANGE := 240.0
const WINDUP_TIME := 0.40
const STRIKE_TIME := 0.20
const COOLDOWN_TIME := 0.60
const HIT_DAMAGE := 12.0

const ANIM_FPS := 9.0     # idle/run — no crítico para el gameplay
const DEATH_FPS := 10.0

## Tier 1 — enemigos "cría", HP bajísimo. Sólo aparecen en las
## primeras waves. Slime se suma acá como filler clásico.
const KIND_IDS: Array[String] = ["rat", "imp", "lizardman", "slime_1"]
## Tier 2 — mezcla del tier 1 con las variantes intermedias +
## ghost (mid-game spooky) + beholder 1 (wizard-ish).
const KIND_IDS_MID: Array[String] = [
	"rat", "imp", "lizardman",
	"rat_2", "imp_2", "lizardman_2",
	"slime_1", "slime_2", "ghost_1",
]
## Tier 3 — sólo variantes fuertes. Waves altas. Incluye beholders
## (los que disparan tipo wizard) y ghosts de tier alto.
const KIND_IDS_HIGH: Array[String] = [
	"rat_2", "imp_2", "lizardman_2",
	"rat_3", "imp_3", "lizardman_3",
	"slime_2", "slime_3",
	"ghost_2", "ghost_3",
	"beholder_1", "beholder_2", "beholder_3",
]
## Alias para compat.
const KIND_IDS_ADVANCED: Array[String] = ["rat_2", "imp_2", "lizardman_2", "rat_3", "imp_3", "lizardman_3"]
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

	# ── Regulares por tier ──────────────────────────────────────
	# Cada familia (Imp/Lizardman/Rat) tiene 3 variantes (1/2/3) con
	# animaciones idénticas — sólo cambia el arte (más armado, más
	# oscuro/rojo, más grande). Cada tier sube hp y coin_reward para
	# que el jugador SIENTA la escalada, no sólo la vea.

	# ── IMP: chiquito y rápido ──────────────────────────────────
	"imp": {
		"base": "res://assets/sprites/IMP/Imp1/",
		"frame_size": Vector2(64, 64),
		"idle":   {"file": "Idle/Imp1_Idle_front.png",     "frames": 4, "cols": 4},
		"run":    {"file": "Run/Imp1_Run_front.png",       "frames": 8, "cols": 8},
		"attack": {"file": "Attack/Imp1_Attack_front.png", "frames": 6, "cols": 6},
		"death":  {"file": "Death/Imp1_Death_front.png",   "frames": 10, "cols": 10},
		"scale": 0.7, "hp": 3.0, "coin_reward": 1,
	},
	"imp_2": {
		"base": "res://assets/sprites/IMP/Imp2/",
		"frame_size": Vector2(64, 64),
		"idle":   {"file": "Idle/Imp2_Idle_front.png",     "frames": 4, "cols": 4},
		"run":    {"file": "Run/Imp2_Run_front.png",       "frames": 8, "cols": 8},
		"attack": {"file": "Attack/Imp2_Attack_front.png", "frames": 6, "cols": 6},
		"death":  {"file": "Death/Imp2_Death_front.png",   "frames": 10, "cols": 10},
		"scale": 0.75, "hp": 6.0, "coin_reward": 2,
	},
	"imp_3": {
		"base": "res://assets/sprites/IMP/Imp3/",
		"frame_size": Vector2(64, 64),
		"idle":   {"file": "Idle/Imp3_Idle_front.png",     "frames": 4, "cols": 4},
		"run":    {"file": "Run/Imp3_Run_front.png",       "frames": 8, "cols": 8},
		"attack": {"file": "Attack/Imp3_Attack_front.png", "frames": 6, "cols": 6},
		"death":  {"file": "Death/Imp3_Death_front.png",   "frames": 10, "cols": 10},
		"scale": 0.8, "hp": 12.0, "coin_reward": 4,
	},

	# ── LIZARDMAN: mediano equilibrado ──────────────────────────
	"lizardman": {
		"base": "res://assets/sprites/Lizardman/Lizardman1/",
		"frame_size": Vector2(64, 64),
		"idle":   {"file": "Idle/Lizardman1_Idle_front.png",     "frames": 4, "cols": 4},
		"run":    {"file": "Run/Lizardman1_Run_front.png",       "frames": 8, "cols": 8},
		"attack": {"file": "Attack/Lizardman1_Attack_front.png", "frames": 7, "cols": 7},
		"death":  {"file": "Death/Lizardman1_Death_front.png",   "frames": 7, "cols": 7},
		"scale": 0.7, "hp": 4.0, "coin_reward": 1,
	},
	"lizardman_2": {
		"base": "res://assets/sprites/Lizardman/Lizardman2/",
		"frame_size": Vector2(64, 64),
		"idle":   {"file": "Idle/Lizardman2_Idle_front.png",     "frames": 4, "cols": 4},
		"run":    {"file": "Run/Lizardman2_Run_front.png",       "frames": 8, "cols": 8},
		"attack": {"file": "Attack/Lizardman2_Attack_front.png", "frames": 7, "cols": 7},
		"death":  {"file": "Death/Lizardman2_Death_front.png",   "frames": 7, "cols": 7},
		"scale": 0.75, "hp": 8.0, "coin_reward": 2,
	},
	"lizardman_3": {
		"base": "res://assets/sprites/Lizardman/Lizardman3/",
		"frame_size": Vector2(64, 64),
		"idle":   {"file": "Idle/Lizardman3_Idle_front.png",     "frames": 4, "cols": 4},
		"run":    {"file": "Run/Lizardman3_Run_front.png",       "frames": 8, "cols": 8},
		"attack": {"file": "Attack/Lizardman3_Attack_front.png", "frames": 7, "cols": 7},
		"death":  {"file": "Death/Lizardman3_Death_front.png",   "frames": 7, "cols": 7},
		"scale": 0.8, "hp": 16.0, "coin_reward": 4,
	},

	# ── SLIME: cada sheet es grid 64x64 con 4 filas (direcciones)
	# y N cols (frames por dirección). Usamos la primera fila = 1
	# dirección; monster.gd fallback repite para las 4 dirs porque
	# el filename no tiene sufijo _front/_back.
	"slime_1": {
		"base": "res://assets/sprites/Slime/Slime1/",
		"frame_size": Vector2(64, 64),
		"idle":   {"file": "Slime1_Idle_without_shadow.png",   "frames": 6, "cols": 6},
		"run":    {"file": "Slime1_Run_without_shadow.png",    "frames": 8, "cols": 8},
		"attack": {"file": "Slime1_Attack_without_shadow.png", "frames": 9, "cols": 10},
		"death":  {"file": "Slime1_Death_without_shadow.png",  "frames": 8, "cols": 8},
		"scale": 0.7, "hp": 2.0, "coin_reward": 1,
	},
	"slime_2": {
		"base": "res://assets/sprites/Slime/Slime2/",
		"frame_size": Vector2(64, 64),
		"idle":   {"file": "Slime2_Idle_without_shadow.png",   "frames": 6, "cols": 6},
		"run":    {"file": "Slime2_Run_without_shadow.png",    "frames": 8, "cols": 8},
		"attack": {"file": "Slime2_Attack_without_shadow.png", "frames": 9, "cols": 10},
		"death":  {"file": "Slime2_Death_without_shadow.png",  "frames": 8, "cols": 10},
		"scale": 0.8, "hp": 5.0, "coin_reward": 2,
	},
	"slime_3": {
		"base": "res://assets/sprites/Slime/Slime3/",
		"frame_size": Vector2(64, 64),
		"idle":   {"file": "Slime3_Idle_without_shadow.png",   "frames": 6, "cols": 6},
		"run":    {"file": "Slime3_Run_without_shadow.png",    "frames": 8, "cols": 8},
		"attack": {"file": "Slime3_Attack_without_shadow.png", "frames": 9, "cols": 9},
		"death":  {"file": "Slime3_Death_without_shadow.png",  "frames": 8, "cols": 10},
		"scale": 0.9, "hp": 10.0, "coin_reward": 3,
	},

	# ── GHOST: mismo layout 64x64 x 4 filas ─────────────────────
	"ghost_1": {
		"base": "res://assets/sprites/Ghost/Ghost1/",
		"frame_size": Vector2(64, 64),
		"idle":   {"file": "Ghost1_Idle_without_shadow.png",   "frames": 4,  "cols": 4},
		"run":    {"file": "Ghost1_Run_without_shadow.png",    "frames": 6,  "cols": 6},
		"attack": {"file": "Ghost1_Attack_without_shadow.png", "frames": 12, "cols": 12},
		"death":  {"file": "Ghost1_Death_without_shadow.png",  "frames": 9,  "cols": 9},
		"scale": 0.7, "hp": 5.0, "coin_reward": 2,
	},
	"ghost_2": {
		"base": "res://assets/sprites/Ghost/Ghost2/",
		"frame_size": Vector2(64, 64),
		"idle":   {"file": "Ghost2_Idle_without_shadow.png",   "frames": 4,  "cols": 4},
		"run":    {"file": "Ghost2_Run_without_shadow.png",    "frames": 6,  "cols": 6},
		"attack": {"file": "Ghost2_Attack_without_shadow.png", "frames": 12, "cols": 12},
		"death":  {"file": "Ghost2_Death_without_shadow.png",  "frames": 9,  "cols": 9},
		"scale": 0.8, "hp": 8.0, "coin_reward": 3,
	},
	"ghost_3": {
		"base": "res://assets/sprites/Ghost/Ghost3/",
		"frame_size": Vector2(64, 64),
		"idle":   {"file": "Ghost3_Idle_without_shadow.png",   "frames": 4,  "cols": 4},
		"run":    {"file": "Ghost3_Run_without_shadow.png",    "frames": 6,  "cols": 6},
		"attack": {"file": "Ghost3_Attack_without_shadow.png", "frames": 12, "cols": 12},
		"death":  {"file": "Ghost3_Death_without_shadow.png",  "frames": 9,  "cols": 9},
		"scale": 0.9, "hp": 14.0, "coin_reward": 5,
	},

	# ── BEHOLDER: el más animado del pool (12 frames idle) ──────
	"beholder_1": {
		"base": "res://assets/sprites/Beholder/Beholder1/",
		"frame_size": Vector2(64, 64),
		"idle":   {"file": "Beholder1_Idle_without_shadow.png",   "frames": 12, "cols": 12},
		"run":    {"file": "Beholder1_Run_without_shadow.png",    "frames": 8,  "cols": 8},
		"attack": {"file": "Beholder1_Attack_without_shadow.png", "frames": 12, "cols": 12},
		"death":  {"file": "Beholder1_Death_without_shadow.png",  "frames": 9,  "cols": 9},
		"scale": 0.7, "hp": 6.0, "coin_reward": 2,
	},
	"beholder_2": {
		"base": "res://assets/sprites/Beholder/Beholder2/",
		"frame_size": Vector2(64, 64),
		"idle":   {"file": "Beholder2_Idle_without_shadow.png",   "frames": 12, "cols": 12},
		"run":    {"file": "Beholder2_Run_without_shadow.png",    "frames": 8,  "cols": 8},
		"attack": {"file": "Beholder2_Attack_without_shadow.png", "frames": 12, "cols": 12},
		"death":  {"file": "Beholder2_Death_without_shadow.png",  "frames": 9,  "cols": 9},
		"scale": 0.8, "hp": 10.0, "coin_reward": 3,
	},
	"beholder_3": {
		"base": "res://assets/sprites/Beholder/Beholder3/",
		"frame_size": Vector2(64, 64),
		"idle":   {"file": "Beholder3_Idle_without_shadow.png",   "frames": 12, "cols": 12},
		"run":    {"file": "Beholder3_Run_without_shadow.png",    "frames": 8,  "cols": 8},
		"attack": {"file": "Beholder3_Attack_without_shadow.png", "frames": 12, "cols": 12},
		"death":  {"file": "Beholder3_Death_without_shadow.png",  "frames": 9,  "cols": 9},
		"scale": 0.9, "hp": 18.0, "coin_reward": 6,
	},

	# ── RAT: 128x128, muy animado ───────────────────────────────
	"rat": {
		"base": "res://assets/sprites/Rat/Rat1/",
		"frame_size": Vector2(128, 128),
		"idle":   {"file": "Idle/Rat1_Idle_front.png",     "frames": 6, "cols": 6},
		"run":    {"file": "Run/Rat1_Run_front.png",       "frames": 6, "cols": 6},
		"attack": {"file": "Attack/Rat1_Attack_front.png", "frames": 8, "cols": 8},
		"death":  {"file": "Death/Rat1_Death_front.png",   "frames": 5, "cols": 5},
		"scale": 0.4, "hp": 3.0, "coin_reward": 1,
	},
	"rat_2": {
		"base": "res://assets/sprites/Rat/Rat2/",
		"frame_size": Vector2(128, 128),
		"idle":   {"file": "Idle/Rat2_Idle_front.png",     "frames": 6, "cols": 6},
		"run":    {"file": "Run/Rat2_Run_front.png",       "frames": 6, "cols": 6},
		"attack": {"file": "Attack/Rat2_Attack_front.png", "frames": 8, "cols": 8},
		"death":  {"file": "Death/Rat2_Death_front.png",   "frames": 5, "cols": 5},
		"scale": 0.44, "hp": 6.0, "coin_reward": 2,
	},
	"rat_3": {
		"base": "res://assets/sprites/Rat/Rat3/",
		"frame_size": Vector2(128, 128),
		"idle":   {"file": "Idle/Rat3_Idle_front.png",     "frames": 6, "cols": 6},
		"run":    {"file": "Run/Rat3_Run_front.png",       "frames": 6, "cols": 6},
		"attack": {"file": "Attack/Rat3_Attack_front.png", "frames": 8, "cols": 8},
		"death":  {"file": "Death/Rat3_Death_front.png",   "frames": 5, "cols": 5},
		"scale": 0.48, "hp": 12.0, "coin_reward": 4,
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
var _last_hit_source := "otro"
var is_elite := false
var _elite_t := 0.0
## Lo setea main.gd según la oleada: multiplica el daño que hace.
var power_mult: float = 1.0
var behavior: String = "melee"
var _behavior_cd: float = 2.0
var _charge_dir := Vector2.ZERO
var _strafe_sign: float = 1.0
var _boss_cycle: int = 0
## Crías (slime partido / ratas invocadas): no se vuelven a partir.
var _is_minion := false
## Setup diferido para crías creadas en pleno callback de física
## (ver _spawn_minion): se aplica en _ready.
var _pending_setup: Dictionary = {}

var _base_sprite_scale := Vector2.ONE
var _kind_id := ""
## Dirección actual del sprite del monstruo. Se actualiza en cada
## frame según el vector velocity — el eje dominante manda.
var _facing := "front"

const DIRECTIONS: Array[String] = ["front", "back", "left", "right"]
var _attack_range := ATTACK_RANGE
var _anim_frames: Dictionary = {}   # "idle"/"run"/"attack"/"death" -> Array[Texture2D]

## Frames recortados por tipo de monstruo, compartidos por todas las
## instancias (sólo se leen). Antes cada monstruo armaba sus propias
## ~130 AtlasTexture (4 animaciones x 4 direcciones): con 50 bichos y
## las crías de slime eran más de 20.000 objetos al matar al jefe y la
## memoria de la versión web saltaba ~100 MB justo ahí (iOS recargaba
## la página). Se cuentan los monstruos vivos de cada tipo: cuando muere
## el último, el tipo sale del caché y sus hojas se liberan como antes.
static var _frames_cache: Dictionary = {}
static var _frames_users: Dictionary = {}
var _frames_kind: String = ""
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
	if not _pending_setup.is_empty():
		_apply_pending_setup.call_deferred()
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
	behavior = _behavior_for(kind_id)
	_behavior_cd = randf_range(1.2, 2.6)
	_strafe_sign = 1.0 if randf() < 0.5 else -1.0
	var data: Dictionary = KIND_DATA.get(kind_id, KIND_DATA[KIND_IDS[0]])
	var frame_size: Vector2 = data.get("frame_size", Vector2(64, 64))
	var cols: int = data.get("cols", 4)
	_release_frames()
	if not _frames_cache.has(kind_id):
		_frames_cache[kind_id] = _build_anim_frames(data, frame_size, cols)
	_frames_users[kind_id] = int(_frames_users.get(kind_id, 0)) + 1
	_frames_kind = kind_id
	_anim_frames = _frames_cache[kind_id]

	_base_sprite_scale = Vector2.ONE * float(data.get("scale", 1.0))
	_sprite.scale = _base_sprite_scale
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# Aplicamos hp y coin_reward del KIND_DATA si están definidos.
	# Esto permite que cada tier tenga sus stats sin tocar main.gd
	# ni el @export default del monster.tscn.
	if data.has("hp"):
		max_hp = float(data["hp"])
		hp = max_hp
	if data.has("coin_reward"):
		coin_reward = int(data["coin_reward"])

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

func _exit_tree() -> void:
	_release_frames()

## Este monstruo deja de usar los frames de su tipo (sigue teniendo su
## referencia en _anim_frames, así que la animación de muerte no se corta).
func _release_frames() -> void:
	if _frames_kind == "":
		return
	var n: int = int(_frames_users.get(_frames_kind, 1)) - 1
	if n <= 0:
		_frames_users.erase(_frames_kind)
		_frames_cache.erase(_frames_kind)
	else:
		_frames_users[_frames_kind] = n
	_frames_kind = ""

## Arma los frames de todas las animaciones de un tipo (una vez por tipo,
## ver _frames_cache).
static func _build_anim_frames(data: Dictionary, frame_size: Vector2, cols: int) -> Dictionary:
	var anim_frames := {}
	for anim_name in ["idle", "run", "attack", "death"]:
		if data.has(anim_name):
			var info: Dictionary = data[anim_name]
			# "cols" = frames por anim en las hojas horizontales (1 fila).
			var anim_cols: int = info.get("cols", cols)
			# Los packs nuevos traen SHEETS SEPARADAS por dirección con
			# sufijo _front/_back/_left/_right en el filename. Cargamos
			# las 4 y las guardamos en un dict por dirección; el
			# _update_animation elige según _facing.
			var front_path: String = info["file"]
			var per_dir: Dictionary = {}
			for dir_name in DIRECTIONS:
				var dir_path: String = front_path.replace("_front", "_" + dir_name)
				var full_path: String = data["base"] + dir_path
				if not ResourceLoader.exists(full_path):
					# Fallback al _front si no existe esa dirección
					full_path = data["base"] + front_path
				per_dir[dir_name] = _slice_frames(
					full_path, frame_size, anim_cols, info["frames"], info.get("start", 0)
				)
			anim_frames[anim_name] = per_dir
	return anim_frames

## "start" es el índice (fila*cols + columna) del primer frame — 0
## para los packs de un archivo por animación (todos los actuales);
## sirve para un pack que comparta una única hoja grande con varias
## animaciones en filas distintas, si se suma alguno más adelante.
static func _slice_frames(path: String, frame_size: Vector2, cols: int, frame_count: int, start: int = 0) -> Array[Texture2D]:
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

	if is_elite:
		_elite_t += delta
		queue_redraw()

	# El cooldown de disparo/embestida/anillo corre en TODOS los estados:
	# un jefe pegado al player vive en windup→strike→cooldown y pasaba
	# por chase un solo frame por ciclo — nunca llegaba a atacar.
	_behavior_cd -= delta

	# Empujón (escudo divino de GAROTH): mientras dura no persigue.
	if _knock_t > 0.0:
		_knock_t -= delta
		velocity = _knock_vel
		move_and_slide()
		_update_animation(delta)
		return

	match state:
		State.IDLE_WANDER: _tick_wander(delta)
		State.CHASE:       _tick_chase(delta)
		State.WINDUP:      _tick_windup(delta)
		State.STRIKE:      _tick_strike(delta)
		State.COOLDOWN:    _tick_cooldown(delta)
		State.CHARGE_WINDUP: _tick_charge_windup(delta)
		State.CHARGE:        _tick_charge(delta)

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

func _tick_chase(delta: float) -> void:
	if target == null:
		_enter_wander()
		return
	var to_player: Vector2 = target.global_position - global_position
	var d := to_player.length()
	var dir := to_player.normalized()
	match behavior:
		"caster", "turret":
			# Se mantienen a distancia y disparan; si el player se les
			# pega igual, pegan cuerpo a cuerpo como el resto.
			var near: float = 140.0 if behavior == "caster" else 170.0
			var far: float = 210.0 if behavior == "caster" else 250.0
			if d < _attack_range:
				_enter_windup()
				return
			if _behavior_cd <= 0.0 and d < far + 70.0:
				_shoot_at_player(dir)
			if d > far:
				velocity = dir * CHASE_SPEED * speed_mult
			elif d < near:
				velocity = -dir * CHASE_SPEED * 0.8 * speed_mult
			else:
				velocity = dir.orthogonal() * CHASE_SPEED * 0.5 * speed_mult * _strafe_sign
			_update_facing(dir)
			return
		"charger":
			if _behavior_cd <= 0.0 and d > 60.0 and d < 200.0:
				_enter_charge_windup(dir)
				return
		"phantom":
			if _behavior_cd <= 0.0 and d > 150.0:
				_phase_teleport()
		"boss":
			if _behavior_cd <= 0.0:
				_boss_attack()
	if d < _attack_range:
		_enter_windup()
		return
	# Sin techo de distancia — persigue eternamente al player.
	velocity = dir * CHASE_SPEED * speed_mult
	# Actualiza el _facing por eje dominante del vector velocity.
	_update_facing(dir)

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
		emit_signal("hit_player", HIT_DAMAGE * power_mult)
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

func _tick_charge_windup(delta: float) -> void:
	velocity = Vector2.ZERO
	_state_timer += delta
	if _state_timer >= CHARGE_WINDUP_TIME:
		state = State.CHARGE
		_state_timer = 0.0
		_set_animation("run", ANIM_FPS * 2.0)

func _tick_charge(delta: float) -> void:
	velocity = _charge_dir * CHASE_SPEED * CHARGE_SPEED_MULT * speed_mult
	_state_timer += delta
	if not _did_hit_this_strike and target != null \
			and global_position.distance_to(target.global_position) < _attack_range + 8.0:
		_did_hit_this_strike = true
		emit_signal("hit_player", CHARGE_DAMAGE * power_mult)
	if _state_timer >= CHARGE_TIME:
		_behavior_cd = 2.8
		_enter_cooldown()

# ── Comportamientos ─────────────────────────────────────────────

static func _behavior_for(kind: String) -> String:
	if kind.begins_with("demon"): return "boss"
	if kind.begins_with("imp"): return "caster"
	if kind.begins_with("beholder"): return "turret"
	if kind.begins_with("lizardman"): return "charger"
	if kind.begins_with("slime"): return "splitter"
	if kind.begins_with("ghost"): return "phantom"
	return "melee"

func _enter_charge_windup(dir: Vector2) -> void:
	state = State.CHARGE_WINDUP
	_state_timer = 0.0
	_charge_dir = dir
	_did_hit_this_strike = false
	velocity = Vector2.ZERO
	# Naranja = "va a embestir" (el rojo es el golpe normal).
	_sprite.modulate = Color(1.6, 1.1, 0.4)
	_set_animation("idle")

func _shoot_at_player(dir: Vector2) -> void:
	if behavior == "caster":
		_behavior_cd = 2.6
		# Velocidades de proyectil x0.72, igual que el héroe (ver BASE_SPEED).
		_spawn_enemy_shot(dir, 122.0, SHOT_DAMAGE, Color("ff7a2e"))
	else:
		_behavior_cd = 3.2
		for a in [-0.26, 0.0, 0.26]:
			_spawn_enemy_shot(dir.rotated(a), 108.0, SHOT_DAMAGE * 0.85, Color("b36bff"))

func _spawn_enemy_shot(dir: Vector2, speed: float, dmg: float, color: Color) -> void:
	var shot := Area2D.new()
	shot.set_script(ENEMY_SHOT_SCRIPT)
	get_tree().current_scene.add_child(shot)
	shot.setup(global_position + dir * 12.0, dir, speed, dmg * power_mult, color)

## Fantasma: se desvanece y reaparece a un costado del player.
func _phase_teleport() -> void:
	_behavior_cd = 5.0
	var ang := randf() * TAU
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate:a", 0.0, 0.25)
	tw.tween_callback(_teleport_near_target.bind(ang))
	tw.tween_property(_sprite, "modulate:a", 1.0, 0.25)

func _teleport_near_target(ang: float) -> void:
	if not _dead and target != null and is_instance_valid(target):
		global_position = target.global_position + Vector2(cos(ang), sin(ang)) * randf_range(95.0, 125.0)

## Jefe: dos anillos de fuego y a la tercera invoca 3 ratas.
func _boss_attack() -> void:
	_behavior_cd = 3.4
	_boss_cycle += 1
	if _boss_cycle % 3 == 0:
		for i in range(3):
			_spawn_minion("rat", global_position + Vector2.RIGHT.rotated(TAU * i / 3.0) * 44.0, 1.0, 1.0)
	else:
		var n: int = 10 + maxi(0, BOSS_KIND_IDS.find(_kind_id)) * 2
		for i in range(n):
			_spawn_enemy_shot(Vector2.RIGHT.rotated(TAU * i / n + _boss_cycle * 0.3), 90.0, BOSS_SHOT_DAMAGE, Color("ff4d2e"))

## Crea una cría (slime partido / rata invocada). Se registra en la
## escena YA (así main.gd la cuenta antes de que este monstruo avise
## que murió y no se cierre la oleada con crías vivas) y se agrega al
## árbol diferido (puede estar pasando en pleno callback de física).
func _spawn_minion(kind: String, pos: Vector2, hp_frac: float, scale_mult: float) -> void:
	var m = load(MONSTER_SCENE_PATH).instantiate()
	m.position = pos
	m.power_mult = power_mult
	m.speed_mult = speed_mult
	m._is_minion = true
	m._pending_setup = {"kind": kind, "hp_frac": hp_frac, "scale": scale_mult}
	var scene := get_tree().current_scene
	if scene.has_method("register_monster"):
		scene.register_monster(m)
	else:
		m.target = target
	scene.add_child.call_deferred(m)

func _apply_pending_setup() -> void:
	var setup: Dictionary = _pending_setup
	_pending_setup = {}
	set_kind(setup["kind"])
	max_hp *= setup["hp_frac"]
	hp = max_hp
	xp_reward = 1
	coin_reward = 0
	_base_sprite_scale *= setup["scale"]
	_sprite.scale = _base_sprite_scale
	if target != null:
		_enter_chase()

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
	var attack_frames: Array = _frames_for("attack")
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

## Ajusta _facing por eje dominante del vector de movimiento.
## Con velocidad casi cero mantiene el facing anterior (evita el
## flicker cuando el monstruo se detiene apenas).
func _update_facing(dir: Vector2) -> void:
	if dir.length_squared() < 0.01:
		return
	if abs(dir.x) > abs(dir.y):
		_facing = "left" if dir.x < 0 else "right"
	else:
		_facing = "back" if dir.y < 0 else "front"

## Frames de una animación para la dirección actual (_facing), con
## fallback a "front". _anim_frames[anim] es un Dictionary por
## dirección, no un Array — asignarlo directo a un Array rompía
## _die() y _enter_windup(). Devuelve [] si el kind no tiene esa anim.
func _frames_for(anim: String) -> Array:
	var per_dir: Dictionary = _anim_frames.get(anim, {})
	if per_dir.is_empty():
		return []
	return per_dir.get(_facing, per_dir.get("front", []))

func _update_animation(delta: float) -> void:
	# _anim_frames[anim] ahora es Dictionary[direction] = Array[Texture2D].
	# Elige la dirección actual; cae en "front" si no existe.
	var per_dir = _anim_frames.get(_anim_name, {})
	if per_dir == null or (per_dir is Dictionary and per_dir.is_empty()):
		return
	var frames: Array = per_dir.get(_facing, per_dir.get("front", []))
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

## `source` = id del arma que pegó (ver weapons.gd) — alimenta el
## "daño por arma" de la pantalla de resultados. El daño que sobra
## después de matar no cuenta.
func take_damage(amount: float, source: String = "otro") -> void:
	if _dead: return
	# Árbol de habilidades: "Cazador" (jefes/élites) y "Crítico" (x2).
	if is_elite or is_boss():
		amount *= 1.0 + GameState.run_hunter_bonus
	var crit: bool = GameState.run_crit_chance > 0.0 and randf() < GameState.run_crit_chance
	if crit:
		amount *= 2.0
	GameState.record_damage(source, minf(amount, hp))
	_last_hit_source = source
	hp -= amount
	DAMAGE_NUMBER.spawn(DAMAGE_NUMBER, get_tree().current_scene, global_position, amount, crit)
	emit_signal("hp_changed", max(0.0, hp), max_hp)
	_sprite.modulate = Color(2.0, 2.0, 2.0)
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.12)
	Audio.play_sfx("monster_hit", global_position, 0.15)
	if hp <= 0.0:
		_die()

func is_boss() -> bool:
	return _kind_id in BOSS_KIND_IDS

var _knock_vel := Vector2.ZERO
var _knock_t := 0.0

## Lo empuja en `dir`. A los jefes casi no los mueve.
func knockback(dir: Vector2, strength: float) -> void:
	if _dead:
		return
	_knock_vel = dir * strength * (0.25 if is_boss() else 1.0)
	_knock_t = 0.18

## Convierte al monstruo en élite — llamar después de set_kind() (que
## pisa max_hp/coin_reward con los del KIND_DATA).
func make_elite() -> void:
	is_elite = true
	max_hp *= ELITE_HP_MULT
	hp = max_hp
	coin_reward *= 4
	xp_reward *= 5
	_base_sprite_scale *= ELITE_SCALE
	_sprite.scale = _base_sprite_scale
	_sprite.self_modulate = ELITE_COLOR

## Aro dorado que late a los pies del élite (se dibuja debajo del sprite).
func _draw() -> void:
	if not is_elite or _dead:
		return
	var r: float = 15.0 * _base_sprite_scale.x
	var a: float = 0.55 + 0.3 * sin(_elite_t * 6.0)
	draw_arc(Vector2(0, 6), r, 0.0, TAU, 28, Color(ELITE_COLOR, a), 2.0, false)

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
	GameState.record_kill(_last_hit_source, is_boss(), is_elite)
	if is_elite or is_boss():
		_drop_chest()
	if behavior == "splitter" and not _is_minion:
		for side in [-1.0, 1.0]:
			_spawn_minion(_kind_id, global_position + Vector2(14.0 * side, 0.0), 0.3, 0.65)
	queue_redraw()
	# Boss suena distinto — más grave y grande. Cualquier demon (tier)
	# cuenta como boss.
	if _kind_id in BOSS_KIND_IDS:
		Audio.play_sfx("boss_death", global_position, 0.05)
	else:
		Audio.play_sfx("monster_death", global_position, 0.15)
	emit_signal("died")

	var death_frames: Array = _frames_for("death")
	if death_frames.is_empty():
		queue_free()
		return
	_sprite.modulate = Color.WHITE
	_set_animation("death", DEATH_FPS)

## Diferido por el mismo motivo que el orbe de XP (ver _drop_xp_orb).
func _drop_chest() -> void:
	var chest := Area2D.new()
	chest.set_script(CHEST_SCRIPT)
	chest.global_position = global_position
	get_tree().current_scene.add_child.call_deferred(chest)

func _drop_xp_orb() -> void:
	var orb = XP_ORB_SCENE.instantiate()
	orb.add_to_group("xp_orb")
	# _die() se llama desde take_damage(), que a su vez cuelga del
	# body_entered de un proyectil/AttackArea — todavía estamos
	# adentro del callback de física de ESE frame. Agregar un Area2D
	# (el orb) a la escena ahí mismo dispara "Can't change this state
	# while flushing queries" porque registrarlo toca el monitoring
	# state en pleno flush. Diferido, se agrega recién en el próximo
	# frame, ya fuera del flush.
	get_tree().current_scene.add_child.call_deferred(orb)
	orb.global_position = global_position
	orb.set_xp(xp_reward)
