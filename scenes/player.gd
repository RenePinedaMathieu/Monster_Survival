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
	"swordman": {"id": "shield", "name": "Escudo divino", "cooldown": 8.0, "icon": SKILL_ICON + "skill_27.png",
		"desc": "2 s invulnerable y empujas a los enemigos cercanos"},
	"edric": {"id": "whirl", "name": "Remolino", "cooldown": 7.0, "icon": SKILL_ICON + "skill_89.png",
		"desc": "Giras con la espada 1,2 s golpeando todo a tu alrededor"},
	"sira": {"id": "wolf", "name": "Llamado del lobo", "cooldown": 14.0, "icon": SKILL_ICON + "skill_75.png",
		"desc": "Un lobo caza a tu lado durante 10 s"},
	# TOREN, BRAN y VAEL (GAROTH recoloreado) usan habilidades que ya
	# existían: la de EDRIC, la de LINA y la de KAY (fuera del juego).
	"toren": {"id": "whirl", "name": "Remolino", "cooldown": 7.0, "icon": SKILL_ICON + "skill_89.png",
		"desc": "Giras con la espada 1,2 s golpeando todo a tu alrededor"},
	"bran": {"id": "roll", "name": "Voltereta", "cooldown": 3.5, "icon": SKILL_ICON + "skill_77.png",
		"desc": "Ruedas lejos y eres invulnerable un instante"},
	"vael": {"id": "volley", "name": "Ráfaga", "cooldown": 6.0, "icon": SKILL_ICON + "skill_61.png",
		"desc": "Lanzas 12 proyectiles en círculo"},
}
const DASH_SPEED := 900.0
const DASH_DAMAGE := 8.0
## Duración del empuje de la Embestida (Axel): 0.15 s a DASH_SPEED ≈
## 135 unidades. Antes 0.19 s y además el héroe seguía deslizándose al
## terminar (ver _physics_process): recorría ~525 unidades, más de dos
## pantallas de ancho en el teléfono.
const EMBESTIDA_TIME := 0.15
const SHIELD_RADIUS := 110.0
const SHIELD_DAMAGE := 10.0
const VOLLEY_ARROWS := 12
## Remolino (EDRIC): golpea alrededor cada WHIRL_TICK mientras gira.
const WHIRL_TIME := 1.2
const WHIRL_TICK := 0.2
const WHIRL_RADIUS := 80.0
const WHIRL_DAMAGE := 6.0
const WOLF_SCRIPT := preload("res://scenes/wolf_ally.gd")

const SHOT_SCENE := preload("res://scenes/shot_projectile.tscn")
const METEOR_SCRIPT := preload("res://scenes/meteor.gd")
const FLYING_SWORDS_RIG_SCRIPT := preload("res://scenes/flying_swords_rig.gd")
const COMPANION_SCRIPT := preload("res://scenes/companion.gd")
const FLOAT_TEXT := preload("res://scenes/damage_number.gd")
const Upgrades := preload("res://scenes/upgrades.gd")
const AURA_SCRIPT := preload("res://scenes/aura_weapon.gd")
const AXE_SCRIPT := preload("res://scenes/axe_weapon.gd")
const LIGHTNING_SCRIPT := preload("res://scenes/lightning_weapon.gd")
const CHAIN_LASER_SCRIPT := preload("res://scenes/chain_laser_weapon.gd")
const ELEMENTAL_SHOT_SCRIPT := preload("res://scenes/elemental_shot_weapon.gd")
const FORCE_SHIELD_SCRIPT := preload("res://scenes/force_shield_weapon.gd")
const PULSE_SCRIPT := preload("res://scenes/pulse_weapon.gd")
const SENTINEL_SCRIPT := preload("res://scenes/sentinel_weapon.gd")
const SAW_SCRIPT := preload("res://scenes/saw_weapon.gd")
const SLOW_AURA_SCRIPT := preload("res://scenes/slow_aura_weapon.gd")

const BASE_SCALE := 0.5
## 220 → 175 → 125. A 175 se cruzaba la pantalla (335 unidades de alto
## en PC, ver VIEW_SHORT_UNITS_DESKTOP) en ~1.9 s y los testers decían
## que el héroe "cruza todo muy rápido". A 125 tarda ~2.7 s, más cerca
## del ritmo de Vampire Survivors. Los monstruos y sus proyectiles se
## bajaron en la misma proporción (ver monster.gd) para no volver el
## juego más difícil, sólo más pausado. El dash (DASH_SPEED) queda
## igual a propósito: el contraste con caminar lo hace sentir mejor.
const BASE_SPEED := 125.0
const ACCELERATION := 1150.0          # px/s² — llega a top speed en ~0.11s, igual que antes
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
# Escala x1 como todo el juego: un píxel del dibujo = una unidad del
# mundo (el estándar es GAROTH). Antes 0.8 para que midiera lo mismo
# que el resto; con eso sus píxeles eran más chicos que los demás.
const AXEL_SCALE := 1.0
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
const RANGED_SCALE := 1.0   # x1 como todo el juego (antes 1.05)
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
		"death_files": {
			"down": "Death/death_normal_down.png", "up": "Death/death_normal_up.png",
			"left_down": "Death/death_normal_left_down.png", "left_up": "Death/death_normal_left_up.png",
			"right_down": "Death/death_normal_right_down.png", "right_up": "Death/death_normal_right_up.png",
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
		"death_files": {
			"down": "Death/death_Down.png", "up": "Death/death_Up.png",
			"left_down": "Death/death_Left_Down.png", "left_up": "Death/death_Left_Up.png",
			"right_down": "Death/death_Right_Down.png", "right_up": "Death/death_Right_Up.png",
		},
	},
}

# EDRIC y SIRA: sprites de 8 direcciones con un PNG por frame (como el
# viejo "Man"). Pelean cuerpo a cuerpo igual que AXEL/GAROTH. "idle" es
# una animación o, si falta, la pose quieta de rotations/. "alias" cubre
# carpetas con otro nombre en el pack. "hp"/"speed" ajustan la vida y la
# velocidad base; "attack_time" acorta el ciclo de ataque (SIRA apuñala
# más seguido) y "reach" agranda el área del tajo (EDRIC).
const PIXEL_SKINS := {
	"edric": {
		"base": "res://assets/sprites/Man/",
		"idle": "animations/idle_v4/%s/frame_%03d.png",
		"run": "animations/run_v4/%s/frame_%03d.png",
		"attack": "animations/atk_sword_v4/%s/frame_%03d.png",
		"alias": {"attack": {"north-east": "north-east-00f1db12"}},
		"hit_frame": 4, "damage": 5.0, "range": 80.0,
		"hp": 1.25, "speed": 0.95, "attack_time": 1.0, "reach": 1.3,
	},
	"sira": {
		"base": "res://assets/sprites/woman/",
		"rest": "rotations/%s.png",
		"run": "animations/run/%s/frame_%03d.png",
		"attack": "animations/atk sword/%s/frame_%03d.png",
		"hit_frame": 3, "damage": 3.2, "range": 66.0,
		"hp": 0.85, "speed": 1.15, "attack_time": 0.7, "reach": 1.0,
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
## Pasivas de los desafíos (upgrades.gd LOCKED_CARDS): daño recibido,
## tamaño de las áreas, duración de quemar/congelar/aturdir, recarga de
## habilidad y armas, y vida por enemigo muerto.
var damage_taken_mult: float = 1.0
var area_mult: float = 1.0
var effect_duration_mult: float = 1.0
var cooldown_mult: float = 1.0
var kill_heal: float = 0.0
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
## Acompañantes equipados en la tienda (companion.gd), uno por espacio.
var _companions: Array = []
## Armas nuevas (aura/hacha/rayo) — mismo patrón que _swords_rig.
var _aura = null
var _axes = null
var _lightning = null
var _chain_laser = null
var _fire_shot_weapon = null
var _electric_shot = null
var _freeze_shot = null
var _sentinels = null
var _saws = null
var _slow_aura = null
var _force_shield = null
var _pulse_weapon = null

## Build de la run (ver upgrades.gd): nivel de cada arma y pasiva que
## se tiene, y evoluciones conseguidas. Las casillas (máximo de armas/
## pasivas) y las evoluciones se calculan a partir de esto.
var weapon_levels: Dictionary = {}
var passive_levels: Dictionary = {}
var evolutions: Array[String] = []
## Evolución "lluvia de flechas": cuántos enemigos atraviesa cada flecha.
var _arrow_pierce: int = 0
var _meteors_evolved: bool = false

var took_damage: bool = false
var _xp_frac: float = 0.0
## "Segunda vida" del árbol de habilidades.
var _revives_left: int = 0
## Terreno (painted_world.gd): charcos de lodo del pantano en los que
## está parado y tormenta de arena del desierto — ambos frenan.
var _mud_zones: int = 0
var in_sandstorm: bool = false
var _burn_t: float = 0.0
var _burn_dps_frac: float = 0.0
var _burn_tick: float = 0.0

func enter_mud() -> void:
	_mud_zones += 1

func exit_mud() -> void:
	_mud_zones = maxi(0, _mud_zones - 1)

func apply_burn(dps_frac: float, duration: float) -> void:
	_burn_dps_frac = maxf(_burn_dps_frac, dps_frac)
	_burn_t = maxf(_burn_t, duration)
	queue_redraw()

func _tick_burn(delta: float) -> void:
	if _burn_t <= 0.0:
		return
	_burn_t = maxf(0.0, _burn_t - delta)
	_burn_tick += delta
	while _burn_tick >= 0.5:
		_burn_tick -= 0.5
		take_damage(max_hp * _burn_dps_frac * 0.5)
	if _burn_t <= 0.0:
		_burn_dps_frac = 0.0
		_burn_tick = 0.0
	queue_redraw()

func _terrain_mult() -> float:
	var m: float = 1.0
	if _mud_zones > 0:
		m *= 0.6
	if in_sandstorm:
		m *= 0.82
	return m
## "Relanzar" del árbol: cuántas veces se pueden re-sortear las cartas
## del level-up en esta partida (lo gasta level_up_menu.gd).
var rerolls_left: int = 0
var active_skill: Dictionary = {}
var _skill_cd: float = 0.0
var _skill_cd_total: float = 1.0
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
# (lvl1 → lvl2 → … → lvl9, una cada 3 niveles). Las tiers superiores
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
## Golpe (5 cuadros) y muerte (7) del pack, en las 6 formas.
const SWORDMAN_HURT_FRAMES := 5
const SWORDMAN_DEATH_FRAMES := 7
const SWORDMAN_SCALE := 1.0
const SWORDMAN_ATTACK_RANGE := 70.0
const SWORDMAN_MELEE_DAMAGE := 5.0
const SWORDMAN_MAX_TIER := 9   # formas 7-9: tools/import_swordsman_pack.py
## Una forma nueva cada SWORDMAN_TIER_EVERY niveles. Con 3, se gana la
## etapa (nivel ~18) en la forma 6-7 y el desafío 21-30 llega a la 8-9.
const SWORDMAN_TIER_EVERY := 3
## Daño extra del tajo por forma: forma 9 = x2,2 (antes, con 6 formas y
## +0,24 cada una, también llegaba a x2,2).
const SWORDMAN_TIER_DAMAGE := 0.15
## TOREN, BRAN y VAEL: GAROTH recoloreado (pelo y ojos) con
## tools/recolor_hero.py. Evolucionan igual que él en 6 formas; "hp" y
## "speed" ajustan su vida y velocidad base.
const SWORD_SKINS := {
	"toren": {"dir": "res://assets/sprites/toren/", "name": "Toren", "hp": 1.2, "speed": 0.95},
	"bran": {"dir": "res://assets/sprites/bran/", "name": "Bran", "hp": 0.9, "speed": 1.1},
	"vael": {"dir": "res://assets/sprites/vael/", "name": "Vael", "hp": 1.0, "speed": 1.0},
}
var _is_swordman: bool = false
var _sword_skin: Dictionary = {}   # vacío = GAROTH
var _swordman_tier: int = 1
var _swordman_facing: String = "front"
var _swordman_idle: Dictionary = {}
var _swordman_run: Dictionary = {}
var _swordman_attack: Dictionary = {}
var _swordman_hurt: Dictionary = {}
var _swordman_death: Dictionary = {}
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

# EDRIC / SIRA
var _is_pixel_skin: bool = false
var _pixel: Dictionary = {}
var _pixel_idle: Dictionary = {}
var _pixel_run: Dictionary = {}
var _pixel_attack: Dictionary = {}
var _pixel_facing: String = "south"
var _pixel_attacking: bool = false
var _pixel_attack_elapsed: float = 0.0
var _pixel_hit_applied: bool = false
var _attack_time_mult: float = 1.0
var _whirl_t: float = 0.0
var _whirl_tick: float = 0.0

# KAY / LINA
var _is_ranged_skin: bool = false
var _ranged_idle: Dictionary = {}
var _ranged_run: Dictionary = {}
var _ranged_death: Dictionary = {}

# Golpe y muerte animados (los que el pack trae: GAROTH ambos, KAY y
# LINA sólo muerte, AXEL ninguno). Sin animación queda el destello rojo
# y la caída de costado de siempre.
const HURT_FPS := 16.0
const HURT_COOLDOWN := 0.6   # recibiendo golpes seguidos no queda trabado en el golpe
const DEATH_FPS := 10.0
var _hurt_t: float = 0.0
var _hurt_cd: float = 0.0
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
	atk_speed_mult += GameState.get_bonus_atk_speed()
	magnet_radius *= 1.0 + GameState.get_bonus_magnet()
	_revives_left = GameState.get_revives()
	rerolls_left = GameState.get_rerolls()
	max_defense = GameState.get_bonus_max_defense()
	defense = max_defense
	hp = max_hp
	_apply_camera_zoom_for_device()
	Screen.layout_changed.connect(_on_layout_changed)
	var skin_id: String = GameState.selected_character_id
	active_skill = ACTIVE_SKILLS.get(skin_id, ACTIVE_SKILLS["main_char1"])
	_is_axel = skin_id == "main_char1"
	_is_swordman = skin_id == "swordman" or SWORD_SKINS.has(skin_id)
	_sword_skin = SWORD_SKINS.get(skin_id, {})
	_is_ranged_skin = RANGED_SKINS.has(skin_id)
	if _is_swordman:
		_sprite.scale = Vector2.ONE * SWORDMAN_SCALE
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_load_swordman_textures()
		if not _sword_skin.is_empty():
			max_hp *= float(_sword_skin["hp"])
			hp = max_hp
			move_speed *= float(_sword_skin["speed"])
	elif _is_axel:
		_sprite.scale = Vector2.ONE * AXEL_SCALE
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_load_axel_textures()
	elif _is_ranged_skin:
		_sprite.scale = Vector2.ONE * float(RANGED_SKINS[skin_id].get("scale", RANGED_SCALE))
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_load_ranged_textures(skin_id)
	elif PIXEL_SKINS.has(skin_id):
		_setup_pixel_skin(skin_id)
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
	var slot := 0
	for id in GameState.active_companions():
		spawn_companion.call_deferred(id, GameState.companion_level(id), slot)
		slot += 1

## Crea el acompañante en ese espacio (reemplaza al que hubiera). Sin
## nivel usa el comprado, o 3 (adulto) si no lo tenés — la sala QA.
func spawn_companion(id: String, lvl: int = -1, slot: int = 0) -> void:
	if lvl < 1:
		lvl = maxi(3, GameState.companion_level(id))
	for c in _companions.duplicate():
		if is_instance_valid(c) and c._slot == slot:
			_companions.erase(c)
			c.queue_free()
	var comp := Node2D.new()
	comp.set_script(COMPANION_SCRIPT)
	get_tree().current_scene.add_child(comp)
	comp.setup(self, id, lvl, slot)
	_companions.append(comp)

func _setup_pixel_skin(skin_id: String) -> void:
	_is_pixel_skin = true
	_pixel = PIXEL_SKINS[skin_id]
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var base: String = _pixel["base"]
	var alias: Dictionary = _pixel.get("alias", {})
	for d in DIR_NAMES:
		for anim in ["idle", "run", "attack"]:
			if not _pixel.has(anim):
				continue
			var dir_name: String = alias.get(anim, {}).get(d, d)
			var frames: Array = []
			for i in range(16):
				var path: String = base + _pixel[anim] % [dir_name, i]
				if not ResourceLoader.exists(path):
					break
				frames.append(load(path))
			var target: Dictionary = {"idle": _pixel_idle, "run": _pixel_run, "attack": _pixel_attack}[anim]
			target[d] = frames
		if not _pixel.has("idle"):
			_pixel_idle[d] = [load(base + _pixel["rest"] % d)]
	# Vida y velocidad propias del héroe (después de las de la tienda).
	max_hp *= float(_pixel["hp"])
	hp = max_hp
	move_speed *= float(_pixel["speed"])
	_attack_time_mult = float(_pixel["attack_time"])
	# El área del tajo es un recurso compartido por la escena: se copia
	# antes de agrandarla, si no el próximo héroe heredaría el alcance.
	var shape_node: CollisionShape2D = $AttackArea/AttackShape
	shape_node.shape = shape_node.shape.duplicate()
	shape_node.shape.radius *= float(_pixel["reach"])

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

## Swordman: 4-direction melee que evoluciona por tier (lvl1..lvl9).
## Forma N desde el nivel 1 + 3(N-1): 1, 4, 7, 10, 13, 16, 19, 22, 25.
## (Antes cada 5 niveles y 6 formas: como se gana la etapa cerca del
## nivel 18, casi nadie veía la 5 ni la 6.)
## Cada evolución cambia de sprites in-place — se siente el poder crecer.
func _tier_for_level(lvl: int) -> int:
	return clampi(1 + (lvl - 1) / SWORDMAN_TIER_EVERY, 1, SWORDMAN_MAX_TIER)

## Path builder — el folder es INCONSISTENTE entre tiers:
## Lvl 1-3 usan prefijo "Swordsman_lvlN_Anim/" (ej Swordsman_lvl1_Idle/)
## Lvl 4-6 usan sólo "Anim/" (ej Idle/)
## Los filenames adentro también varían — "attack" es lowercase, el
## resto capitalizado. Se maneja acá para no ensuciar el caller.
func _swordman_path(tier: int, anim: String, direction: String) -> String:
	# TOREN, BRAN y VAEL: un solo formato de nombre para todas las formas.
	if not _sword_skin.is_empty():
		var n: String = _sword_skin["name"]
		return "%s%s_lvl%d/%s/%s_lvl%d_%s_%s.png" % [_sword_skin["dir"], n, tier, anim, n, tier, anim, direction]
	var base := "res://assets/sprites/swordman/Swordsman_lvl%d/" % tier
	var folder := anim if tier >= 4 else "Swordsman_lvl%d_%s" % [tier, anim]
	var fname := "Swordsman_lvl%d_%s_%s.png" % [tier, anim if anim != "Attack" else "attack", direction]
	return "%s%s/%s" % [base, folder, fname]

func _load_swordman_textures() -> void:
	_swordman_tier = _tier_for_level(level)
	_swordman_idle.clear()
	_swordman_run.clear()
	_swordman_attack.clear()
	_swordman_hurt.clear()
	_swordman_death.clear()
	for dir_name in SWORDMAN_DIRS:
		_swordman_idle[dir_name] = _slice_sheet(_swordman_path(_swordman_tier, "Idle", dir_name), SWORDMAN_FRAME_SIZE, SWORDMAN_IDLE_FRAMES)
		_swordman_run[dir_name] = _slice_sheet(_swordman_path(_swordman_tier, "Run", dir_name), SWORDMAN_FRAME_SIZE, SWORDMAN_RUN_FRAMES)
		_swordman_attack[dir_name] = _slice_sheet(_swordman_path(_swordman_tier, "Attack", dir_name), SWORDMAN_FRAME_SIZE, SWORDMAN_ATTACK_FRAMES)
		_swordman_hurt[dir_name] = _slice_sheet(_swordman_path(_swordman_tier, "Hurt", dir_name), SWORDMAN_FRAME_SIZE, SWORDMAN_HURT_FRAMES)
		_swordman_death[dir_name] = _slice_sheet(_swordman_path(_swordman_tier, "Death", dir_name), SWORDMAN_FRAME_SIZE, SWORDMAN_DEATH_FRAMES)

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
		_ranged_idle[dir_key] = _slice_sheet(base + data["idle_files"][dir_key], data.get("frame_size", RANGED_FRAME_SIZE), data.get("frame_count", RANGED_FRAME_COUNT))
	for dir_key in data["run_files"]:
		_ranged_run[dir_key] = _slice_sheet(base + data["run_files"][dir_key], data.get("frame_size", RANGED_FRAME_SIZE), data.get("frame_count", RANGED_FRAME_COUNT))
	for dir_key in data.get("death_files", {}):
		_ranged_death[dir_key] = _slice_sheet(base + data["death_files"][dir_key], data.get("frame_size", RANGED_FRAME_SIZE), data.get("frame_count", RANGED_FRAME_COUNT))

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

## Cuántas unidades de mundo entran en el lado corto de la pantalla —
## más chico = cámara más cerca. En teléfono va más cerca que en PC: la
## pantalla es chica y el héroe se perdía entre los bichos (con 200 se
## veía demasiado poco alrededor y los bichos llegaban sin aviso). Se calcula
## sobre el viewport lógico que arma el autoload Screen, así da lo
## mismo la resolución real o si el teléfono está vertical/horizontal.
const VIEW_SHORT_UNITS_DESKTOP := 335.0
const VIEW_SHORT_UNITS_PHONE := 250.0

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
	_tick_burn(delta)
	if hp <= 0.0:
		return
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
	velocity = velocity.move_toward(input * move_speed * _terrain_mult(), ACCELERATION * delta)
	_tick_active_skill(delta)
	move_and_slide()

	# Sprite: ataque (si está en curso) tiene prioridad sobre correr/
	# idle — el swing se ve completo aunque sigas esquivando. El golpe
	# recibido va antes que correr, pero no corta un ataque.
	_hurt_cd = maxf(0.0, _hurt_cd - delta)
	if _whirl_t > 0.0:
		pass   # _tick_whirl ya eligió el cuadro
	elif _hurt_t > 0.0 and not (_axel_attacking or _swordman_attacking or _pixel_attacking):
		_update_hurt(delta)
	elif _axel_attacking:
		_update_axel_attack(delta)
	elif _swordman_attacking:
		_update_swordman_attack(delta)
	elif _pixel_attacking:
		_update_pixel_attack(delta)
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
			var run_frames: Array = _ranged_run[_ranged_facing]
			_sprite.texture = run_frames[_run_frame % run_frames.size()]
		elif _is_pixel_skin:
			_pixel_facing = DIR_NAMES[current_dir]
			var px_frames: Array = _pixel_run[_pixel_facing]
			if not px_frames.is_empty():
				_sprite.texture = px_frames[_run_frame % px_frames.size()]
		else:
			_sprite.texture = _run_textures[current_dir][_run_frame]
	else:
		_apply_idle(delta)

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
			_meteor_cd = _meteor_interval * cooldown_mult

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
	var is_melee_char := _is_axel or _is_swordman or _is_pixel_skin
	var melee_range: float = SWORDMAN_ATTACK_RANGE if _is_swordman else AXEL_ATTACK_RANGE
	if _is_pixel_skin:
		melee_range = float(_pixel["range"])
	var to_target_dist: float = global_position.distance_to(target.global_position)
	var out_of_melee_range: bool = is_melee_char and to_target_dist > melee_range
	if out_of_melee_range and ranged_bonus_shots == 0:
		# Sin ranged bonus no hay nada para hacer a distancia — no
		# gastamos el CD, reintentamos rápido.
		_fire_cd = 0.15
		return
	_fire_cd = AUTO_FIRE_INTERVAL / atk_speed_mult * _attack_time_mult
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
	elif _is_pixel_skin:
		if not out_of_melee_range:
			_pixel_facing = DIR_NAMES[current_dir]
			_pixel_attacking = true
			_pixel_attack_elapsed = 0.0
			_pixel_hit_applied = false
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
		meteor.impact_radius *= area_mult
		if _meteors_evolved:
			meteor.impact_radius = 105.0 * area_mult
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
	# Daño extra por forma: forma 1 = x1, forma 9 = x2,2.
	var tier_mult: float = 1.0 + (_swordman_tier - 1) * SWORDMAN_TIER_DAMAGE
	var dmg: float = SWORDMAN_MELEE_DAMAGE * damage_mult * tier_mult
	for body in _attack_area.get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(dmg, "ataque")

# ── EDRIC / SIRA: ataque en 8 direcciones ───────────────────────

func _update_pixel_attack(delta: float) -> void:
	_pixel_attack_elapsed += delta
	var frames: Array = _pixel_attack[_pixel_facing]
	var duration: float = AUTO_FIRE_INTERVAL / atk_speed_mult * _attack_time_mult
	var t: float = clampf(_pixel_attack_elapsed / duration, 0.0, 1.0)
	if not frames.is_empty():
		var frame: int = mini(int(t * frames.size()), frames.size() - 1)
		_sprite.texture = frames[frame]
		if not _pixel_hit_applied and frame >= int(_pixel["hit_frame"]):
			_pixel_hit_applied = true
			for body in _attack_area.get_overlapping_bodies():
				if body.has_method("take_damage"):
					body.take_damage(float(_pixel["damage"]) * damage_mult, "ataque")
	if t >= 1.0:
		_pixel_attacking = false

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
	# "Sabiduría" del árbol: más experiencia; las fracciones se acumulan
	# (orbes de 1 XP con +8% también suman con el tiempo).
	_xp_frac += amount * GameState.run_xp_mult
	amount = floori(_xp_frac)
	_xp_frac -= amount
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
	GameState.report_max("best_level", level)
	emit_signal("leveled_up", level)

func apply_upgrade(id: String) -> void:
	upgrade_log.append(id)
	if Upgrades.PASSIVES.has(id):
		passive_levels[id] = passive_level(id) + 1
	match id:
		"damage":     damage_mult *= 1.25
		"atk_speed":  atk_speed_mult *= 1.20
		# +8% por carta, 5 niveles máx (ver upgrades.gd) = +47% en total.
		# Antes +12% (hasta +76%) — al final de la run el héroe volaba.
		"move_speed": move_speed *= 1.08
		"max_hp":
			max_hp *= 1.25
			hp = min(max_hp, hp + max_hp * 0.20)
			emit_signal("hp_changed", hp, max_hp)
		"hp_regen":   hp_regen_per_sec += 1.0
		"magnet":     magnet_radius *= 1.40
		"toughness":  damage_taken_mult *= 0.94
		"area":       area_mult += 0.10
		"duration":   effect_duration_mult += 0.20
		"precision":  GameState.run_crit_chance += 0.05
		"haste":      cooldown_mult *= 0.92
		"bloodthirst": kill_heal += 0.3
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
		"laser_cadena":
			_chain_laser = _level_weapon(_chain_laser, CHAIN_LASER_SCRIPT, "laser_cadena", false)
		"disparo_fuego":
			_fire_shot_weapon = _level_elemental_shot(_fire_shot_weapon, "disparo_fuego", "fire")
		"disparo_electrico":
			_electric_shot = _level_elemental_shot(_electric_shot, "disparo_electrico", "electric")
		"disparo_congelante":
			_freeze_shot = _level_elemental_shot(_freeze_shot, "disparo_congelante", "freeze")
		"centinela":
			_sentinels = _level_weapon(_sentinels, SENTINEL_SCRIPT, "centinela", true)
		"sierras":
			_saws = _level_weapon(_saws, SAW_SCRIPT, "sierras", true)
		"aura_lenta":
			_slow_aura = _level_weapon(_slow_aura, SLOW_AURA_SCRIPT, "aura_lenta", true)
		"escudo_fuerza":
			_force_shield = _level_weapon(_force_shield, FORCE_SHIELD_SCRIPT, "escudo_fuerza", true)
		"pulso":
			_pulse_weapon = _level_weapon(_pulse_weapon, PULSE_SCRIPT, "pulso", false)
		"overflow_attack":
			damage_mult *= 1.15
		"overflow_defense":
			var gained: float = maxf(8.0, max_defense * 0.20)
			max_defense += gained
			defense += gained
			emit_signal("defense_changed", defense, max_defense)
		"overflow_hp":
			max_hp *= 1.20
			hp = min(max_hp, hp + max_hp * 0.18)
			emit_signal("hp_changed", hp, max_hp)
		# Relleno cuando ya no queda nada por mejorar.
		"coins":
			GameState.add_run_currency(25)
		"heal":
			heal(max_hp * 0.3)
	GameState.report_max("max_weapons", weapons_owned())
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

func _level_elemental_shot(node, id: String, element: String):
	node = _level_weapon(node, ELEMENTAL_SHOT_SCRIPT, id, false)
	node.element = element
	return node

# ── HP ──────────────────────────────────────────────────────────

## La armadura comprada en la tienda da una barra de defensa que
## absorbe daño ANTES que la vida (no regenera durante la run — es
## efectivamente HP extra "gratis" cada partida).
func block_projectile(from_pos: Vector2) -> bool:
	if _force_shield != null and is_instance_valid(_force_shield) and _force_shield.has_method("block_projectile"):
		return _force_shield.block_projectile(from_pos)
	return false

func take_damage(amount: float) -> void:
	if hp <= 0.0: return
	# Dash/voltereta/escudo: invulnerable mientras dura.
	if _invuln_t > 0.0: return
	# Legendaria "Espejismo" (Desierto): chance de esquivar el golpe.
	if GameState.run_dodge > 0.0 and randf() < GameState.run_dodge:
		FLOAT_TEXT.spawn_text(FLOAT_TEXT, get_tree().current_scene, global_position, "ESQUIVA", Color("9fd8ff"), 1.2)
		return
	# Evolución "Bastión": el escudo también para golpes cuerpo a cuerpo.
	if _force_shield != null and is_instance_valid(_force_shield) and _force_shield.absorb_hit():
		return
	amount *= damage_taken_mult
	## Para el logro "Intocable" (main.gd lo mira al empezar cada oleada).
	took_damage = true
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
		if hp > 0.0:
			_start_hurt()
		# Flash rojo brevísimo
		_sprite.modulate = Color(1.6, 0.5, 0.5)
		create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.2)
	if hp <= 0.0:
		if _revives_left > 0:
			_revive()
			return
		Audio.play_sfx("player_death", global_position)
		emit_signal("died")

## Muerte: el héroe deja de moverse y de atacar (se apaga su proceso y
## con él las armas que cuelgan de él) y juega su animación de muerte,
## o cae de costado en rojo si el pack no la trae. El tween va por el
## árbol y sin time_scale, así corre aunque el player esté apagado y el
## juego en cámara lenta (main.gd, pantalla MORISTE).
func play_death() -> void:
	$Camera2D.offset = Vector2.ZERO
	_shake_strength = 0.0
	_sprite.self_modulate.a = 1.0
	velocity = Vector2.ZERO
	process_mode = Node.PROCESS_MODE_DISABLED
	var frames := _death_frames()
	if not frames.is_empty():
		_sprite.modulate = Color(1.6, 0.6, 0.55)
		var anim := get_tree().create_tween().set_ignore_time_scale(true)
		anim.tween_method(func(i: float): _sprite.texture = frames[mini(int(i), frames.size() - 1)],
			0.0, float(frames.size()), frames.size() / DEATH_FPS)
		anim.parallel().tween_property(_sprite, "modulate", Color(0.8, 0.6, 0.6), 0.9)
		return
	var side: float = -1.0 if _last_move_dir.x < 0.0 else 1.0
	_sprite.modulate = Color(2.0, 0.45, 0.4)
	var tw := get_tree().create_tween().set_ignore_time_scale(true)
	tw.tween_property(_sprite, "rotation", side * PI / 2.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_sprite, "position:y", _sprite.position.y + 8.0, 0.45)
	tw.parallel().tween_property(_sprite, "modulate", Color(0.6, 0.35, 0.35), 0.9)

func _hurt_frames() -> Array:
	if _is_swordman:
		return _swordman_hurt.get(_swordman_facing, [])
	return []

func _death_frames() -> Array:
	if _is_swordman:
		return _swordman_death.get(_swordman_facing, [])
	if _is_ranged_skin:
		return _ranged_death.get(_ranged_facing, [])
	return []

func _start_hurt() -> void:
	var frames := _hurt_frames()
	if frames.is_empty() or _hurt_cd > 0.0:
		return
	_hurt_t = frames.size() / HURT_FPS
	_hurt_cd = HURT_COOLDOWN

func _update_hurt(delta: float) -> void:
	var frames := _hurt_frames()
	_hurt_t = maxf(0.0, _hurt_t - delta)
	if frames.is_empty():
		_hurt_t = 0.0
		return
	var i: int = clampi(int((frames.size() / HURT_FPS - _hurt_t) * HURT_FPS), 0, frames.size() - 1)
	_sprite.texture = frames[i]

## "Segunda vida" (árbol de habilidades): vuelve con media vida, un
## instante invulnerable y una onda que aleja a los que lo rodeaban.
func _revive() -> void:
	_revives_left -= 1
	hp = max_hp * 0.5
	emit_signal("hp_changed", hp, max_hp)
	_invuln_t = 2.5
	_shield_fx_t = 0.0001
	for m in get_tree().get_nodes_in_group("monster"):
		if is_instance_valid(m) and global_position.distance_to(m.global_position) < SHIELD_RADIUS * 1.5:
			if m.has_method("knockback"):
				m.knockback((m.global_position - global_position).normalized(), 520.0)
	shake(8.0)
	Audio.play_sfx("level_up", global_position)

const FLASH_GOLD := Color(2.2, 1.7, 0.35)
const FLASH_GREEN := Color(0.55, 2.2, 0.6)

## Destello de color sobre el héroe: dorado al agarrar monedas, verde al
## curarse (pickup.gd, cofres). Dos pulsos para que se note aunque haya
## mucho pasando en pantalla.
var _flash_tween: Tween

func flash(color: Color) -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_sprite.modulate = color
	_flash_tween.tween_property(_sprite, "modulate", Color.WHITE, 0.18)
	_flash_tween.tween_property(_sprite, "modulate", color, 0.08)
	_flash_tween.tween_property(_sprite, "modulate", Color.WHITE, 0.35)

func heal(amount: float) -> void:
	hp = min(max_hp, hp + amount)
	emit_signal("hp_changed", hp, max_hp)

## Carta "Sed de sangre": cada enemigo que muere cura (main.gd lo llama).
func on_monster_killed() -> void:
	if kill_heal > 0.0 and hp > 0.0 and hp < max_hp:
		heal(kill_heal)

# ── Estado consultado por level_up_menu.gd para filtrar cartas ──────

## true si el player dispara algo de alguna forma ahora mismo — todo
## personaje ranged, o AXEL sólo si ya tiene "disparo a distancia".
## Sin esto, cartas como "+1 proyectil" podían salir sorteadas antes
## de que AXEL tuviera siquiera un disparo que multiplicar.
func has_ranged_attack() -> bool:
	# Swordman también es melee puro por default — como AXEL, sólo
	# tiene disparo si tomó la carta "disparo a distancia".
	if _is_axel or _is_swordman or _is_pixel_skin:
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
	_skill_cd = active_skill["cooldown"] * cooldown_mult
	_skill_cd_total = _skill_cd
	match active_skill["id"]:
		"dash":
			_start_dash(EMBESTIDA_TIME)
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
		"whirl":
			_whirl_t = WHIRL_TIME
			_whirl_tick = 0.0
			Audio.play_sfx("sword_swing", global_position)
		"wolf":
			var wolf := Node2D.new()
			wolf.set_script(WOLF_SCRIPT)
			get_tree().current_scene.add_child(wolf)
			wolf.setup(self)
			Audio.play_sfx("ui_click", global_position)
	skill_cooldown_changed.emit(_skill_cd, _skill_cd_total)

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
		skill_cooldown_changed.emit(_skill_cd, _skill_cd_total)
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
	if _whirl_t > 0.0:
		_tick_whirl(delta)
	if _dash_t > 0.0:
		_dash_t -= delta
		velocity = _dash_dir * DASH_SPEED
		# Al terminar se vuelve a velocidad de caminata: si no, la
		# aceleración normal (ACCELERATION) tardaba ~0.8 s en frenar los
		# 900 y el héroe se deslizaba ~350 unidades más.
		if _dash_t <= 0.0:
			velocity = _dash_dir * move_speed
		if int(_dash_t * 60.0) % 4 == 0:
			_spawn_afterimage()
		if active_skill.get("id", "") == "dash":
			for m in get_tree().get_nodes_in_group("monster"):
				if is_instance_valid(m) and not (m in _dash_hit) and global_position.distance_to(m.global_position) < 28.0:
					_dash_hit.append(m)
					m.take_damage(DASH_DAMAGE * damage_mult, "habilidad")

## Remolino: el héroe gira mirando a las 8 direcciones y cada
## WHIRL_TICK golpea y empuja a todo lo que tenga alrededor.
func _tick_whirl(delta: float) -> void:
	_whirl_t = maxf(0.0, _whirl_t - delta)
	_whirl_tick -= delta
	if _whirl_tick <= 0.0:
		_whirl_tick = WHIRL_TICK
		var r: float = WHIRL_RADIUS * area_mult
		for m in get_tree().get_nodes_in_group("monster"):
			if is_instance_valid(m) and global_position.distance_to(m.global_position) <= r:
				m.take_damage(WHIRL_DAMAGE * damage_mult, "habilidad")
				if m.has_method("knockback"):
					m.knockback((m.global_position - global_position).normalized(), 140.0)
	if _is_pixel_skin:
		_pixel_attacking = false
		_pixel_facing = DIR_NAMES[int(_whirl_t * 24.0) % 8]
		var frames: Array = _pixel_attack[_pixel_facing]
		if not frames.is_empty():
			_sprite.texture = frames[int(frames.size() * 0.6)]
	elif _is_swordman:
		_swordman_attacking = false
		_swordman_facing = ["front", "side_right", "back", "side_left"][int(_whirl_t * 16.0) % 4]
		var sw_frames: Array = _swordman_attack.get(_swordman_facing, [])
		if not sw_frames.is_empty():
			_sprite.texture = sw_frames[int(sw_frames.size() * 0.5)]
	queue_redraw()

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
	if _shield_fx_t > 0.0:
		var a: float = clampf(1.0 - _shield_fx_t / 2.0, 0.0, 1.0)
		var ring: float = minf(1.0, _shield_fx_t / 0.25) * SHIELD_RADIUS
		if _shield_fx_t < 0.3:
			draw_arc(Vector2.ZERO, ring, 0.0, TAU, 40, Color(1.0, 0.95, 0.6, 1.0 - _shield_fx_t / 0.3), 3.0, false)
		draw_circle(Vector2(0, -8), 26.0, Color(0.6, 0.85, 1.0, 0.18 * a + 0.05))
		draw_arc(Vector2(0, -8), 26.0, 0.0, TAU, 32, Color(0.75, 0.92, 1.0, 0.6 * a + 0.2), 2.0, false)
	if _whirl_t > 0.0:
		var r: float = WHIRL_RADIUS * area_mult
		var spin: float = _whirl_t * 18.0
		var a: float = minf(1.0, _whirl_t / 0.2)
		for k in range(3):
			var start: float = -spin + k * TAU / 3.0
			draw_arc(Vector2(0, -4), r * 0.85, start, start + 1.3, 16, Color(0.85, 1.0, 0.9, 0.55 * a), 4.0, false)
		draw_circle(Vector2(0, -4), r, Color(0.7, 1.0, 0.85, 0.07 * a))
	if _burn_t > 0.0:
		var flicker: float = 0.65 + sin(Time.get_ticks_msec() * 0.018) * 0.2
		draw_arc(Vector2(0, 8), 17.0, 0.0, TAU, 24, Color(1.0, 0.25, 0.04, flicker), 3.0, false)
		draw_circle(Vector2(-8, -5), 3.5, Color(1.0, 0.55, 0.08, flicker))
		draw_circle(Vector2(8, -10), 3.0, Color(1.0, 0.8, 0.2, flicker))

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
	for c in _companions:
		if is_instance_valid(c) and c.line_id == id:
			return true
	return false

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
			for c in _companions:
				if is_instance_valid(c):
					c.evolve()
		"bastion":
			if _force_shield != null:
				_force_shield.evolve()
		"terremoto":
			if _pulse_weapon != null:
				_pulse_weapon.evolve()
		"infierno":
			if _fire_shot_weapon != null:
				_fire_shot_weapon.evolve()
		"cero_absoluto":
			if _freeze_shot != null:
				_freeze_shot.evolve()
			GameState.run_shatter = true
		"sobrecarga":
			if _electric_shot != null:
				_electric_shot.evolve()
		"cadena_carmesi":
			if _chain_laser != null:
				_chain_laser.evolve()
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
	elif _is_pixel_skin:
		frames = _pixel_idle.get("south", [])
	else:
		frames = _idle_textures
	return frames[0] if not frames.is_empty() else null

# ── Utils ───────────────────────────────────────────────────────

func _apply_idle(delta: float = 0.0) -> void:
	if _axel_attacking or _swordman_attacking or _pixel_attacking or _whirl_t > 0.0:
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
			_idle_frame = (_idle_frame + 1) % _ranged_idle[_ranged_facing].size()
		_sprite.texture = _ranged_idle[_ranged_facing][_idle_frame]
	elif _is_pixel_skin:
		var idle_frames: Array = _pixel_idle.get(_pixel_facing, [])
		if idle_frames.is_empty():
			return
		_idle_time += delta
		if _idle_time >= 1.0 / IDLE_ANIM_FPS:
			_idle_time = 0.0
			_idle_frame += 1
		_sprite.texture = idle_frames[_idle_frame % idle_frames.size()]
	elif current_dir < _idle_textures.size():
		_sprite.texture = _idle_textures[current_dir]

func _vec_to_dir(v: Vector2) -> int:
	var angle := v.angle()
	var shifted := -angle + PI / 2.0
	var normalized := fmod(shifted + TAU, TAU)
	return int(round(normalized / (PI / 4.0))) % 8
