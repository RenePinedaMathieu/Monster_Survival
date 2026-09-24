extends Node

## Guarda la elección hecha en character_select.tscn, y el progreso
## persistente entre runs: moneda ganada matando monstruos y las
## mejoras permanentes compradas en shop_menu.tscn.
##
## NOTA: character_select sólo conecta bien el skin de main_char1
## (AXEL) a player.gd — main_char2/main_char2_female sí tienen su
## propio sprite (ver player.gd) pero no ataque propio.
##
## Persistencia: user://save.cfg vía ConfigFile — sobrevive entre
## sesiones del juego (funciona igual en editor, build de escritorio
## y export Web, que guarda esto en IndexedDB).

var selected_character_id: String = "main_char1"
## Mapa y dificultad de la próxima partida (los elige la pantalla de
## mapa, ver map_select). Transitorios: no se persisten.
var selected_map: String = "pradera"
var selected_difficulty: String = "normal"

## Dato completo (dict) del personaje recién elegido en
## character_select.tscn — lo lee character_confirm.tscn para armar
## la pantalla de "revisá antes de arrancar" sin tener que duplicar
## el array CHARACTERS en dos scripts. Transitorio: no se persiste.
var pending_character: Dictionary = {}

## A qué pantalla volver al salir de shop_menu.tscn — la tienda es
## accesible tanto desde el menú principal como desde la selección de
## personaje (barra superior), y el botón VOLVER de ahí debe volver a
## la que corresponda. Transitorio: no se persiste.
var shop_return_scene: String = "res://scenes/main_menu.tscn"

## true la primera vez que se ve el tutorial — de ahí en más
## main_menu.gd no lo vuelve a mostrar solo al picar "Jugar" (se
## puede repasar a mano si en algún momento sumamos un botón para eso).
var tutorial_seen: bool = false

## Récord de la mejor run: hasta qué oleada se llegó y cuánto tiempo
## se sobrevivió. Son independientes — quedarse mucho tiempo en una
## oleada larga no implica haber llegado más lejos, y viceversa.
var best_wave: int = 0
var best_time: float = 0.0

signal currency_changed(amount: int)

const SAVE_PATH := "user://save.cfg"

## Árbol de habilidades permanentes (pestaña MEJORAS de la tienda): 3
## ramas con nodos en orden — cada nodo pide su anterior a cierto nivel
## ("requires"/"req_level"). Cada nivel sale "base_cost + nivel *
## cost_step" monedas. Los bonos que dan están en get_bonus_*() más
## abajo; player.gd los aplica al arrancar cada run. Los ids de las 4
## mejoras originales (armor/max_hp/damage/regen) se mantienen para no
## perder lo ya comprado.
const SKILL_ICON := "res://assets/ui/skill_icons/"
const SKILL_TREE: Dictionary = {
	# ── Ataque ──
	"damage":    {"branch": "attack", "tier": 1, "name": "Fuerza", "desc": "+5% daño",
		"base_cost": 18, "cost_step": 12, "max_level": 10, "requires": "", "req_level": 0, "icon": SKILL_ICON + "skill_96.png"},
	"atk_speed_t": {"branch": "attack", "tier": 2, "name": "Celeridad", "desc": "+4% velocidad de ataque",
		"base_cost": 40, "cost_step": 25, "max_level": 5, "requires": "damage", "req_level": 3, "icon": SKILL_ICON + "skill_99.png"},
	"crit":      {"branch": "attack", "tier": 3, "name": "Crítico", "desc": "+3% de golpe crítico (doble daño)",
		"base_cost": 60, "cost_step": 40, "max_level": 5, "requires": "atk_speed_t", "req_level": 2, "icon": SKILL_ICON + "skill_88.png"},
	"hunter":    {"branch": "attack", "tier": 4, "name": "Cazador", "desc": "+10% daño a jefes y élites",
		"base_cost": 80, "cost_step": 60, "max_level": 3, "requires": "crit", "req_level": 3, "icon": SKILL_ICON + "skill_38.png"},
	# ── Defensa ──
	"max_hp":    {"branch": "defense", "tier": 1, "name": "Vitalidad", "desc": "+15 vida máxima",
		"base_cost": 15, "cost_step": 10, "max_level": 10, "requires": "", "req_level": 0, "icon": SKILL_ICON + "skill_83.png"},
	"armor":     {"branch": "defense", "tier": 2, "name": "Armadura", "desc": "+8 de defensa (absorbe daño antes que la vida)",
		"base_cost": 20, "cost_step": 15, "max_level": 10, "requires": "max_hp", "req_level": 3, "icon": SKILL_ICON + "skill_76.png"},
	"regen":     {"branch": "defense", "tier": 3, "name": "Vigor", "desc": "+0.3 vida por segundo",
		"base_cost": 25, "cost_step": 18, "max_level": 5, "requires": "armor", "req_level": 3, "icon": SKILL_ICON + "skill_79.png"},
	"revive":    {"branch": "defense", "tier": 4, "name": "Segunda vida", "desc": "Revives una vez por partida con media vida",
		"base_cost": 400, "cost_step": 0, "max_level": 1, "requires": "regen", "req_level": 3, "icon": SKILL_ICON + "skill_44.png"},
	# ── Utilidad ──
	"magnet_t":  {"branch": "utility", "tier": 1, "name": "Imán", "desc": "+10% radio para juntar experiencia",
		"base_cost": 25, "cost_step": 15, "max_level": 5, "requires": "", "req_level": 0, "icon": SKILL_ICON + "skill_30.png"},
	"greed":     {"branch": "utility", "tier": 2, "name": "Codicia", "desc": "+10% monedas",
		"base_cost": 50, "cost_step": 40, "max_level": 5, "requires": "magnet_t", "req_level": 2, "icon": "res://assets/ui/rpg/coin.png"},
	"wisdom":    {"branch": "utility", "tier": 3, "name": "Sabiduría", "desc": "+8% experiencia",
		"base_cost": 60, "cost_step": 45, "max_level": 5, "requires": "greed", "req_level": 2, "icon": SKILL_ICON + "skill_72.png"},
	"reroll":    {"branch": "utility", "tier": 4, "name": "Relanzar", "desc": "+1 relanzamiento de cartas por partida",
		"base_cost": 120, "cost_step": 100, "max_level": 3, "requires": "wisdom", "req_level": 2, "icon": SKILL_ICON + "skill_41.png"},
	"luck":      {"branch": "utility", "tier": 5, "name": "Suerte", "desc": "Una 4ª carta en cada subida de nivel",
		"base_cost": 500, "cost_step": 0, "max_level": 1, "requires": "reroll", "req_level": 1, "icon": SKILL_ICON + "skill_7.png"},
}
## Mapas (pantalla de mapa, map_select.tscn). "mult" escala la vida y
## el daño de los monstruos Y las monedas; "pools" son los bichos de
## las oleadas 1-3 / 4-6 / 7+; "bosses" el jefe de la oleada 10 y el
## final (20); "hazard" el peligro propio (ver painted_world.gd).
const MAPS: Dictionary = {
	"pradera": {
		"name": "Pradera", "desc": "Donde empieza todo: ratas, imps y lizardmen.",
		"mult": 1.0, "scene": "res://scenes/Grass1.tscn", "tileset": "res://assets/tiles/overworld_tileset_grass.png",
		"tint": Color(1, 1, 1), "hazard": "", "bosses": ["demon1", "demon2"],
		"pools": [
			["rat", "imp", "lizardman", "slime_1"],
			["rat", "imp", "lizardman", "rat_2", "imp_2", "lizardman_2", "slime_1", "slime_2", "ghost_1"],
			["rat_2", "imp_2", "lizardman_2", "rat_3", "imp_3", "lizardman_3", "slime_2", "slime_3", "ghost_2", "ghost_3", "beholder_1", "beholder_2", "beholder_3"],
		],
	},
	"pantano": {
		"name": "Pantano", "desc": "Lodo que te frena, slimes que se parten y fantasmas.",
		"mult": 1.35, "scene": "res://scenes/Swamp1.tscn", "tileset": "res://assets/tiles/overworld_tileset_swamp.png",
		"tint": Color(0.84, 0.92, 0.86), "hazard": "mud", "bosses": ["demon2", "demon3"],
		"pools": [
			["slime_1", "ghost_1", "rat", "imp"],
			["slime_1", "slime_2", "ghost_1", "ghost_2", "imp_2", "rat_2"],
			["slime_2", "slime_3", "ghost_2", "ghost_3", "beholder_1", "imp_3", "rat_3"],
		],
	},
	"desierto": {
		"name": "Desierto", "desc": "Tormentas de arena, lizardmen que embisten y beholders.",
		"mult": 1.7, "scene": "res://scenes/Desert1.tscn", "tileset": "res://assets/tiles/overworld_tileset_desert.png",
		"tint": Color(1.0, 0.97, 0.9), "hazard": "sandstorm", "bosses": ["demon3", "demon3"],
		"pools": [
			["lizardman", "rat", "imp", "lizardman"],
			["lizardman", "lizardman_2", "rat_2", "imp_2", "beholder_1"],
			["lizardman_2", "lizardman_3", "rat_3", "beholder_2", "beholder_3", "imp_3"],
		],
	},
}
const MAP_ORDER: Array = ["pradera", "pantano", "desierto"]

## Dificultad: multiplica vida/daño de los monstruos y las monedas.
## Difícil se abre al ganar una partida; Pesadilla, al ganar en Difícil.
const DIFFICULTIES: Dictionary = {
	"normal":    {"name": "NORMAL",    "mult": 1.0, "coins": 1.0, "unlock": ""},
	"dificil":   {"name": "DIFÍCIL",   "mult": 1.5, "coins": 1.5, "unlock": "win_1"},
	"pesadilla": {"name": "PESADILLA", "mult": 2.2, "coins": 2.0, "unlock": "hard_win"},
}
const DIFFICULTY_ORDER: Array = ["normal", "dificil", "pesadilla"]

func is_difficulty_unlocked(id: String) -> bool:
	var need: String = DIFFICULTIES[id]["unlock"]
	return need == "" or is_achievement_unlocked(need)

func map_data() -> Dictionary:
	return MAPS.get(selected_map, MAPS["pradera"])

func difficulty_data() -> Dictionary:
	return DIFFICULTIES.get(selected_difficulty, DIFFICULTIES["normal"])

const SKILL_BRANCHES: Array = [
	{"id": "attack", "name": "ATAQUE", "color": Color("d74427")},
	{"id": "defense", "name": "DEFENSA", "color": Color("37a0df")},
	{"id": "utility", "name": "UTILIDAD", "color": Color("44a13b")},
]

## Poderes: compra ÚNICA en la tienda. No dan nada directo — habilitan
## que la carta del poder pueda salir en los level-ups durante las
## oleadas (ver level_up_menu.gd _is_eligible). El id es el mismo que
## el de la carta que desbloquean.
const SHOP_POWERS: Dictionary = {
	"meteors": {
		"name": "Lluvia de meteoros", "cost": 60,
		"desc": "Desbloquea la carta: meteoritos caen solos sobre los enemigos",
	},
	"flying_swords": {
		"name": "Espadas voladoras", "cost": 80,
		"desc": "Desbloquea la carta: 5 espadas te escoltan y atacan solas",
	},
	"aura": {
		"name": "Aura sagrada", "cost": 100,
		"desc": "Desbloquea la carta: un aura que quema a los enemigos cercanos",
	},
	"hacha": {
		"name": "Hacha giratoria", "cost": 150,
		"desc": "Desbloquea la carta: hachas que van y vuelven atravesando todo",
	},
	"rayo": {
		"name": "Rayo en cadena", "cost": 200,
		"desc": "Desbloquea la carta: un rayo que salta entre enemigos",
	},
}

## Acompañantes: se compran una vez y se lleva UNO equipado por run
## (player.gd lo spawnea al arrancar, comportamiento en companion.gd).
const COMPANIONS: Dictionary = {
	"chicken": {
		"name": "Pollo", "cost": 120,
		"desc": "Te sigue a todos lados y le tira huevos al bicho más cercano",
	},
}

var total_currency: int = 0
## Lo ganado DURANTE la run en curso — se banca a total_currency (y
## se guarda a disco) recién cuando la run termina, ver
## bank_run_currency(). Así el HUD puede mostrar "lo que vas ganando"
## sin que ya cuente como gastable hasta terminar.
var run_currency: int = 0
var shop_levels: Dictionary = {}   # id -> nivel comprado (int), default 0
var unlocked_powers: Array = []
var owned_companions: Array = []
var equipped_companion: String = ""
## Evoluciones que el jugador ya consiguió alguna vez — a partir de ahí
## las cartas muestran la pista "• Evoluciona en ..." (upgrades.gd).
var discovered_evolutions: Array = []

# ── Logros ───────────────────────────────────────────────────────
## Cada logro mira una estadística acumulada (stat_value) y al llegar a
## "goal" da su premio: monedas, un personaje o un mapa. Es de donde
## sale la mayor parte de la progresión entre partidas (el objetivo de
## "la próxima run"), junto con la tienda.

signal achievement_unlocked(achievement: Dictionary)

const ACHIEVEMENTS: Array = [
	{"id": "kills_100",   "name": "Primera sangre",   "desc": "Derrota 100 enemigos",               "stat": "kills",      "goal": 100,   "reward": {"coins": 50}},
	{"id": "wave_10",     "name": "Superviviente",    "desc": "Llega a la oleada 10",               "stat": "best_wave",  "goal": 10,    "reward": {"character": "main_char2_female"}},
	{"id": "boss_1",      "name": "Matagigantes",     "desc": "Derrota a un jefe",                  "stat": "bosses",     "goal": 1,     "reward": {"character": "swordman"}},
	{"id": "evo_1",       "name": "Evolución",        "desc": "Consigue tu primera evolución",      "stat": "evolutions", "goal": 1,     "reward": {"coins": 100}},
	{"id": "weapons_4",   "name": "Arsenal",          "desc": "Ten 4 armas a la vez",               "stat": "max_weapons", "goal": 4,    "reward": {"coins": 100}},
	{"id": "win_1",       "name": "Héroe",            "desc": "Gana una partida",                   "stat": "wins",       "goal": 1,     "reward": {"coins": 200, "map": "pantano"}},
	{"id": "kills_1000",  "name": "Exterminador",     "desc": "Derrota 1.000 enemigos",             "stat": "kills",      "goal": 1000,  "reward": {"coins": 150}},
	{"id": "elites_20",   "name": "Rompe-élites",     "desc": "Derrota 20 élites",                  "stat": "elites",     "goal": 20,    "reward": {"coins": 150}},
	{"id": "chests_25",   "name": "Cazatesoros",      "desc": "Abre 25 cofres",                     "stat": "chests",     "goal": 25,    "reward": {"coins": 150}},
	{"id": "level_20",    "name": "Veterano",         "desc": "Llega a nivel 20 en una partida",    "stat": "best_level", "goal": 20,    "reward": {"coins": 150}},
	{"id": "no_hit_5",    "name": "Intocable",        "desc": "Llega a la oleada 5 sin recibir daño", "stat": "no_hit_wave", "goal": 5,  "reward": {"coins": 200}},
	{"id": "boss_10",     "name": "Cazajefes",        "desc": "Derrota 10 jefes",                   "stat": "bosses",     "goal": 10,    "reward": {"coins": 300}},
	{"id": "win_pantano", "name": "Señor del pantano", "desc": "Gana en el Pantano",                "stat": "wins_pantano", "goal": 1,   "reward": {"coins": 300, "map": "desierto"}},
	{"id": "win_desierto", "name": "Rey del desierto", "desc": "Gana en el Desierto",               "stat": "wins_desierto", "goal": 1,  "reward": {"coins": 500}},
	{"id": "hard_win",    "name": "Pesadilla",        "desc": "Gana en dificultad Difícil",         "stat": "hard_wins",  "goal": 1,     "reward": {"coins": 400}},
	{"id": "wave_30",     "name": "Infinito",         "desc": "Llega a la oleada 30 en modo infinito", "stat": "best_wave", "goal": 30,  "reward": {"coins": 400}},
	{"id": "evo_7",       "name": "Coleccionista",    "desc": "Descubre las 7 evoluciones",         "stat": "evolutions", "goal": 7,     "reward": {"character": "chicken"}},
	{"id": "heroes_4",    "name": "Todos para uno",   "desc": "Gana con 4 héroes distintos",        "stat": "hero_wins",  "goal": 4,     "reward": {"coins": 500}},
	{"id": "chicken_win", "name": "Gallina de oro",   "desc": "Gana jugando con el pollo",          "stat": "chicken_wins", "goal": 1,   "reward": {"coins": 300}},
	{"id": "kills_10000", "name": "Leyenda",          "desc": "Derrota 10.000 enemigos",            "stat": "kills",      "goal": 10000, "reward": {"coins": 600}},
]

const DEFAULT_CHARACTERS: Array = ["main_char1", "main_char2"]
const DEFAULT_MAPS: Array = ["pradera"]

## Estadísticas acumuladas de todas las partidas (kills, jefes, etc).
var stats: Dictionary = {}
var achievements_unlocked: Array = []
var unlocked_characters: Array = DEFAULT_CHARACTERS.duplicate()
var unlocked_maps: Array = DEFAULT_MAPS.duplicate()
## Logros conseguidos en la partida en curso (los lista la pantalla de
## resultados). Transitorio.
var run_new_achievements: Array = []

func stat_value(name: String) -> int:
	match name:
		"evolutions": return discovered_evolutions.size()
		"best_wave": return best_wave
		"hero_wins": return stats.get("hero_wins", []).size()
	return int(stats.get(name, 0))

func bump_stat(name: String, amount: int = 1) -> void:
	stats[name] = int(stats.get(name, 0)) + amount
	check_achievements()

## Para stats de "mejor marca" (nivel máximo, armas a la vez...).
func report_max(name: String, value: int) -> void:
	if value > int(stats.get(name, 0)):
		stats[name] = value
		check_achievements()

func is_achievement_unlocked(id: String) -> bool:
	return id in achievements_unlocked

func achievement_progress() -> float:
	return float(achievements_unlocked.size()) / ACHIEVEMENTS.size()

func check_achievements() -> void:
	var any := false
	for a in ACHIEVEMENTS:
		if a["id"] in achievements_unlocked:
			continue
		if stat_value(a["stat"]) >= a["goal"]:
			achievements_unlocked.append(a["id"])
			_grant_reward(a["reward"])
			run_new_achievements.append(a)
			achievement_unlocked.emit(a)
			any = true
	if any:
		_save()

func _grant_reward(reward: Dictionary) -> void:
	if reward.has("coins"):
		total_currency += int(reward["coins"])
	if reward.has("character") and not (reward["character"] in unlocked_characters):
		unlocked_characters.append(reward["character"])
	if reward.has("map") and not (reward["map"] in unlocked_maps):
		unlocked_maps.append(reward["map"])

## Texto corto del premio, para la pantalla de logros y los avisos.
func reward_text(reward: Dictionary) -> String:
	var parts: Array = []
	if reward.has("character"):
		parts.append("Nuevo héroe: " + CHARACTER_NAMES.get(reward["character"], reward["character"]))
	if reward.has("map"):
		parts.append("Nuevo mapa: " + MAP_NAMES.get(reward["map"], reward["map"]))
	if reward.has("coins"):
		parts.append("+%d monedas" % reward["coins"])
	return " · ".join(parts)

const CHARACTER_NAMES: Dictionary = {
	"main_char1": "AXEL", "main_char2": "KAY", "main_char2_female": "LINA",
	"swordman": "GAROTH", "chicken": "POLLO",
}
const MAP_NAMES: Dictionary = {"pradera": "Pradera", "pantano": "Pantano", "desierto": "Desierto"}

func is_character_unlocked(id: String) -> bool:
	return id in unlocked_characters

## Qué logro desbloquea a un personaje (para mostrar el candado).
func unlock_hint_for_character(id: String) -> String:
	for a in ACHIEVEMENTS:
		if a["reward"].get("character", "") == id:
			return a["desc"]
	return ""

func is_map_unlocked(id: String) -> bool:
	return id in unlocked_maps

func unlock_hint_for_map(id: String) -> String:
	for a in ACHIEVEMENTS:
		if a["reward"].get("map", "") == id:
			return a["desc"]
	return ""

## Fin de partida: victorias por mapa / héroe / dificultad.
func report_win(hero_id: String, map_id: String, difficulty: String) -> void:
	stats["wins"] = int(stats.get("wins", 0)) + 1
	stats["wins_" + map_id] = int(stats.get("wins_" + map_id, 0)) + 1
	var heroes: Array = stats.get("hero_wins", [])
	if not (hero_id in heroes):
		heroes.append(hero_id)
	stats["hero_wins"] = heroes
	if hero_id == "chicken":
		stats["chicken_wins"] = int(stats.get("chicken_wins", 0)) + 1
	if difficulty != "normal":
		stats["hard_wins"] = int(stats.get("hard_wins", 0)) + 1
	check_achievements()
	_save()

# ── Reto diario + registro de partidas (Supabase, tabla "runs") ──
## Todos juegan lo mismo cada día (fecha UTC): héroe, mapa y un
## modificador, 10 oleadas. El puntaje va a un ranking diario. Además
## TODAS las partidas se registran (sin fecha de reto) para poder ver
## en qué oleada muere la gente y qué elige — y ajustar el balance.
## SQL de la tabla: docs/supabase_runs.sql.

const DAILY_WAVES := 10
const DAILY_HEROES: Array = ["main_char1", "main_char2", "main_char2_female", "swordman"]
const DAILY_MODIFIERS: Dictionary = {
	"elites":   {"name": "Noche de élites", "desc": "Cada oleada trae 2 élites (y 2 cofres)"},
	"veloces":  {"name": "Frenesí", "desc": "Los monstruos son 30% más rápidos"},
	"meteoros": {"name": "Lluvia de fuego", "desc": "Arrancas con la lluvia de meteoros"},
	"cristal":  {"name": "Cañón de cristal", "desc": "Mitad de vida, 50% más de daño"},
	"horda":    {"name": "La horda", "desc": "50% más monstruos por oleada"},
}

var player_name: String = ""
## true mientras se juega el reto diario (lo prende daily_menu, lo
## apaga el menú principal al volver).
var daily_active: bool = false
var daily_best: Dictionary = {}   # fecha -> mejor puntaje propio

func daily_date() -> String:
	return Time.get_date_string_from_system(true)

## El reto de hoy, derivado de la fecha: mismo para todo el mundo.
func daily_info() -> Dictionary:
	var date := daily_date()
	var h: int = absi(hash("one-last-hero-" + date))
	var mods: Array = DAILY_MODIFIERS.keys()
	return {
		"date": date,
		"seed": h,
		"hero": DAILY_HEROES[h % DAILY_HEROES.size()],
		"map": MAP_ORDER[(h / 7) % MAP_ORDER.size()],
		"modifier": mods[(h / 31) % mods.size()],
	}

func daily_modifier() -> String:
	return daily_info()["modifier"] if daily_active else ""

func ensure_player_name() -> String:
	if player_name == "":
		player_name = "Héroe%04d" % (randi() % 10000)
		_save()
	return player_name

func set_player_name(n: String) -> void:
	n = n.strip_edges().substr(0, 16)
	if n != "":
		player_name = n
		_save()

## Puntaje del reto: oleadas pesan mucho, bajas desempatan y ganar
## (sobrevivir las 10) suma un bonus grande.
static func run_score(wave: int, kills: int, victory: bool) -> int:
	return wave * 1000 + kills * 2 + (20000 if victory else 0)

## Registra la partida en Supabase (si hay sesión). Devuelve el puntaje.
func submit_run(wave: int, time_sec: float, victory: bool, build: Dictionary) -> int:
	var kills: int = run_stats.get("total_kills", 0)
	var score := run_score(wave, kills, victory)
	var date: Variant = null
	if daily_active:
		date = daily_date()
		if score > int(daily_best.get(date, 0)):
			daily_best = {date: score}   # sólo guarda el de hoy
			_save()
	if Supabase.is_signed_in():
		Supabase.rest_insert("/runs", {
			"player_name": ensure_player_name(),
			"hero": selected_character_id,
			"map": selected_map,
			"difficulty": selected_difficulty,
			"wave": wave,
			"time_sec": snappedf(time_sec, 0.1),
			"kills": kills,
			"victory": victory,
			"daily_date": date,
			"score": score,
			"build": build,
		})
	return score

func _ready() -> void:
	_load()

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		total_currency = cfg.get_value("progress", "total_currency", 0)
		shop_levels = cfg.get_value("progress", "shop_levels", {})
		tutorial_seen = cfg.get_value("progress", "tutorial_seen", false)
		best_wave = cfg.get_value("progress", "best_wave", 0)
		best_time = cfg.get_value("progress", "best_time", 0.0)
		unlocked_powers = cfg.get_value("progress", "unlocked_powers", [])
		owned_companions = cfg.get_value("progress", "owned_companions", [])
		equipped_companion = cfg.get_value("progress", "equipped_companion", "")
		discovered_evolutions = cfg.get_value("progress", "discovered_evolutions", [])
		stats = cfg.get_value("progress", "stats", {})
		achievements_unlocked = cfg.get_value("progress", "achievements_unlocked", [])
		unlocked_characters = cfg.get_value("progress", "unlocked_characters", DEFAULT_CHARACTERS.duplicate())
		# Quien ya jugaba antes de los logros tenía a los 4 héroes: no se
		# los sacamos (sólo los jugadores nuevos los desbloquean).
		if not cfg.has_section_key("progress", "unlocked_characters") and (best_wave > 0 or total_currency > 0):
			unlocked_characters = ["main_char1", "main_char2", "main_char2_female", "swordman"]
		unlocked_maps = cfg.get_value("progress", "unlocked_maps", DEFAULT_MAPS.duplicate())
		player_name = cfg.get_value("progress", "player_name", "")
		daily_best = cfg.get_value("progress", "daily_best", {})
		# Partidas guardadas de antes de los logros: si ya tenías el récord
		# o las evoluciones, los logros correspondientes se dan al cargar.
		check_achievements()
		run_new_achievements.clear()

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "total_currency", total_currency)
	cfg.set_value("progress", "shop_levels", shop_levels)
	cfg.set_value("progress", "tutorial_seen", tutorial_seen)
	cfg.set_value("progress", "best_wave", best_wave)
	cfg.set_value("progress", "best_time", best_time)
	cfg.set_value("progress", "unlocked_powers", unlocked_powers)
	cfg.set_value("progress", "owned_companions", owned_companions)
	cfg.set_value("progress", "equipped_companion", equipped_companion)
	cfg.set_value("progress", "discovered_evolutions", discovered_evolutions)
	cfg.set_value("progress", "stats", stats)
	cfg.set_value("progress", "achievements_unlocked", achievements_unlocked)
	cfg.set_value("progress", "unlocked_characters", unlocked_characters)
	cfg.set_value("progress", "unlocked_maps", unlocked_maps)
	cfg.set_value("progress", "player_name", player_name)
	cfg.set_value("progress", "daily_best", daily_best)
	cfg.save(SAVE_PATH)

## Se llama cuando termina una run (player muerto). Actualiza los
## récords de forma independiente entre sí y guarda. Devuelve qué se
## batió, para que main.gd pueda mostrar "¡nuevo récord!" si quiere.
func report_run_result(wave: int, time_sec: float) -> Dictionary:
	var beat_wave := wave > best_wave
	var beat_time := time_sec > best_time
	if beat_wave:
		best_wave = wave
	if beat_time:
		best_time = time_sec
	check_achievements()
	# Siempre: también persiste las estadísticas de la run (bajas, etc.).
	_save()
	return {"wave": beat_wave, "time": beat_time}

func mark_tutorial_seen() -> void:
	if tutorial_seen:
		return
	tutorial_seen = true
	_save()

# ── Partida en curso ─────────────────────────────────────────────

## Estadísticas de la run actual: daño y bajas por arma (los registra
## monster.gd con el id de weapons.gd que le pegó) — las muestra la
## pantalla de resultados. Transitorio: no se persiste.
var run_stats: Dictionary = {}

func start_run() -> void:
	run_currency = 0
	run_new_achievements.clear()
	_compute_run_bonuses()
	run_stats = {"damage": {}, "kills": {}, "total_kills": 0, "bosses": 0}
	currency_changed.emit(0)

func record_damage(source: String, amount: float) -> void:
	if amount <= 0.0 or run_stats.is_empty():
		return
	var dmg: Dictionary = run_stats["damage"]
	dmg[source] = dmg.get(source, 0.0) + amount

func record_kill(source: String, is_boss: bool, is_elite: bool = false) -> void:
	stats["kills"] = int(stats.get("kills", 0)) + 1
	if is_boss:
		stats["bosses"] = int(stats.get("bosses", 0)) + 1
	if is_elite:
		stats["elites"] = int(stats.get("elites", 0)) + 1
	check_achievements()
	if run_stats.is_empty():
		return
	var kills: Dictionary = run_stats["kills"]
	kills[source] = kills.get(source, 0) + 1
	run_stats["total_kills"] += 1
	if is_boss:
		run_stats["bosses"] += 1

## Se llama por cada monstruo que muere durante la run (ver
## monster.gd). No toca total_currency todavía.
func add_run_currency(amount: int) -> void:
	# "Codicia" del árbol: multiplica la moneda; se acumulan las
	# fracciones para que +10% sobre monstruos de 1 moneda también cuente.
	_coin_frac += amount * run_coin_mult
	var whole: int = floori(_coin_frac)
	_coin_frac -= whole
	amount = whole
	run_currency += amount
	if not run_stats.is_empty():
		run_stats["coins"] = run_stats.get("coins", 0) + amount
	currency_changed.emit(run_currency)

## Moneda directo al total gastable — sólo para la sala QA.
func grant_currency(amount: int) -> void:
	total_currency += amount
	_save()

## Se llama al terminar la run (main.gd, cuando el player muere) —
## banca lo ganado al total persistente y lo guarda a disco.
func bank_run_currency() -> void:
	total_currency += run_currency
	run_currency = 0
	_save()

func get_shop_level(id: String) -> int:
	return shop_levels.get(id, 0)

func get_shop_cost(id: String) -> int:
	var item: Dictionary = SKILL_TREE[id]
	return item["base_cost"] + get_shop_level(id) * item["cost_step"]

## ¿Está desbloqueado el nodo? (su anterior en la rama al nivel pedido)
func is_skill_available(id: String) -> bool:
	var item: Dictionary = SKILL_TREE[id]
	return item["requires"] == "" or get_shop_level(item["requires"]) >= item["req_level"]

func can_afford(id: String) -> bool:
	var item: Dictionary = SKILL_TREE[id]
	if get_shop_level(id) >= item["max_level"] or not is_skill_available(id):
		return false
	return total_currency >= get_shop_cost(id)

func buy_shop_item(id: String) -> bool:
	if not can_afford(id):
		return false
	total_currency -= get_shop_cost(id)
	shop_levels[id] = get_shop_level(id) + 1
	_save()
	return true

# ── Poderes ──────────────────────────────────────────────────────

func is_power_unlocked(id: String) -> bool:
	return id in unlocked_powers

func buy_power(id: String) -> bool:
	var cost: int = SHOP_POWERS[id]["cost"]
	if is_power_unlocked(id) or total_currency < cost:
		return false
	total_currency -= cost
	unlocked_powers.append(id)
	_save()
	return true

# ── Evoluciones ──────────────────────────────────────────────────

func is_evolution_discovered(id: String) -> bool:
	return id in discovered_evolutions

## Devuelve true si es la primera vez que se consigue.
func discover_evolution(id: String) -> bool:
	if id in discovered_evolutions:
		return false
	discovered_evolutions.append(id)
	check_achievements()
	_save()
	return true

# ── Acompañantes ─────────────────────────────────────────────────

func owns_companion(id: String) -> bool:
	return id in owned_companions

## Al comprar queda equipado directo — es lo que el jugador quiere en
## el 99% de los casos, y se ahorra un clic.
func buy_companion(id: String) -> bool:
	var cost: int = COMPANIONS[id]["cost"]
	if owns_companion(id) or total_currency < cost:
		return false
	total_currency -= cost
	owned_companions.append(id)
	equipped_companion = id
	_save()
	return true

## Equipa el acompañante, o lo desequipa si ya era el equipado.
func toggle_companion(id: String) -> void:
	if not owns_companion(id):
		return
	equipped_companion = "" if equipped_companion == id else id
	_save()

# ── Bonos permanentes — player.gd los aplica al arrancar cada run ──

func get_bonus_max_hp() -> float:
	return get_shop_level("max_hp") * 15.0

func get_bonus_damage_mult() -> float:
	return get_shop_level("damage") * 0.05

func get_bonus_max_defense() -> float:
	return get_shop_level("armor") * 8.0

func get_bonus_regen() -> float:
	return get_shop_level("regen") * 0.3

func get_bonus_atk_speed() -> float:
	return get_shop_level("atk_speed_t") * 0.04

func get_bonus_magnet() -> float:
	return get_shop_level("magnet_t") * 0.10

func get_revives() -> int:
	return get_shop_level("revive")

func get_rerolls() -> int:
	return get_shop_level("reroll")

func get_extra_cards() -> int:
	return get_shop_level("luck")

## Valores fijos durante la partida (se calculan en start_run): los
## usa monster.gd en cada golpe, así no recalcula nada por impacto.
var run_crit_chance: float = 0.0
var run_hunter_bonus: float = 0.0
var run_coin_mult: float = 1.0
var run_xp_mult: float = 1.0
var _coin_frac: float = 0.0

func _compute_run_bonuses() -> void:
	run_crit_chance = get_shop_level("crit") * 0.03
	run_hunter_bonus = get_shop_level("hunter") * 0.10
	run_coin_mult = 1.0 + get_shop_level("greed") * 0.10
	run_xp_mult = 1.0 + get_shop_level("wisdom") * 0.08
	_coin_frac = 0.0
