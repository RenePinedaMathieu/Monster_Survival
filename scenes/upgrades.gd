extends RefCounted

## Catálogo de cartas de level-up + reglas de la build. Lo usan:
##   level_up_menu.gd  qué cartas ofrecer (is_eligible, title_for)
##   player.gd         niveles de armas/pasivas y evoluciones
##   chest_popup.gd    qué evoluciona al abrir un cofre
##   hud.gd / pause_menu.gd  íconos y títulos
##
## Reglas (estilo Vampire Survivors):
##   - Hasta MAX_WEAPONS armas y MAX_PASSIVES pasivas por run. Con las
##     casillas llenas sólo salen mejoras de lo que ya tenés.
##   - Armas y pasivas suben hasta MAX_LEVEL.
##   - EVOLUCIÓN: arma al nivel máximo + su pasiva compañera → al abrir
##     un cofre (lo sueltan élites y jefes) el arma evoluciona.
## Se usa vía preload, igual que ui_theme.gd.

const ICON := "res://assets/ui/skill_icons/"

const MAX_WEAPONS := 8
const MAX_PASSIVES := 5
const MAX_LEVEL := 5

const CARDS: Array = [
	# ── Pasivas ──
	{"id": "damage",       "title": "+25% DAÑO",          "desc": "Todas tus armas pegan más",           "icon": ICON + "skill_96.png"},
	{"id": "atk_speed",    "title": "+20% VEL. ATAQUE",   "desc": "Atacas y disparas más seguido",       "icon": ICON + "skill_99.png"},
	{"id": "move_speed",   "title": "+8% VELOCIDAD",     "desc": "Corres más rápido",                   "icon": ICON + "skill_80.png"},
	{"id": "max_hp",       "title": "+25% VIDA MÁXIMA",   "desc": "Aguantas más golpes",                 "icon": ICON + "skill_83.png"},
	{"id": "hp_regen",     "title": "+1 VIDA/S",          "desc": "Regeneración pasiva",                 "icon": ICON + "skill_79.png"},
	{"id": "magnet",       "title": "+40% IMÁN",          "desc": "Absorbes experiencia desde más lejos", "icon": ICON + "skill_30.png"},
	{"id": "level_damage", "title": "INSTINTO ASESINO",   "desc": "+10% de daño en cada nivel futuro",   "icon": ICON + "skill_53.png"},
	# Pasivas que se ganan en los DESAFÍOS (ver LOCKED_CARDS): cada una
	# evoluciona una de las armas elementales.
	{"id": "toughness",    "title": "PIEL DE HIERRO",     "desc": "Recibes 6% menos daño",               "icon": ICON + "skill_68.png"},
	{"id": "area",         "title": "EXPANSIÓN",          "desc": "+10% de tamaño: pulso, aura, meteoros y aturdir", "icon": ICON + "skill_17.png"},
	{"id": "duration",     "title": "PERSISTENCIA",       "desc": "Quemar, congelar y aturdir duran 20% más", "icon": ICON + "skill_4.png"},
	{"id": "precision",    "title": "OJO CERTERO",        "desc": "+5% de golpe crítico (doble daño)",   "icon": ICON + "skill_56.png"},
	{"id": "haste",        "title": "PRISA",              "desc": "Tu habilidad y tus armas se recargan 8% más rápido", "icon": ICON + "skill_60.png"},
	{"id": "bloodthirst",  "title": "SED DE SANGRE",      "desc": "Cada enemigo que muere te cura 0,3 de vida", "icon": ICON + "skill_93.png"},
	# ── Disparo a distancia ──
	{"id": "ranged_bonus", "title": "DISPARO A DISTANCIA", "desc": "Un disparo automático al enemigo más cercano", "icon": ICON + "skill_55.png"},
	{"id": "ranged_power", "title": "DISPARO A DISTANCIA", "desc": "Más fuerte y más brillante",        "icon": ICON + "skill_67.png"},
	{"id": "ranged_count", "title": "DISPARO A DISTANCIA", "desc": "Suma otro disparo a la ráfaga",     "icon": ICON + "skill_63.png"},
	{"id": "multishot",    "title": "+1 PROYECTIL",        "desc": "Un proyectil extra por ráfaga",     "icon": ICON + "skill_63.png"},
	# ── Espadas voladoras ──
	{"id": "flying_swords",       "title": "ESPADAS VOLADORAS", "desc": "5 espadas te escoltan y atacan solas", "icon": ICON + "skill_5.png"},
	{"id": "flying_swords_power", "title": "ESPADAS VOLADORAS", "desc": "Más fuertes y más brillantes",    "icon": ICON + "skill_65.png"},
	{"id": "flying_swords_count", "title": "ESPADAS VOLADORAS", "desc": "Más espadas atacan a la vez",     "icon": ICON + "skill_65.png"},
	# ── Meteoros ──
	{"id": "meteors",      "title": "LLUVIA DE METEOROS", "desc": "Meteoritos caen solos sobre los enemigos", "icon": ICON + "skill_22.png"},
	# ── Armas nuevas (se desbloquean en la tienda) ──
	{"id": "aura",         "title": "AURA SAGRADA",       "desc": "Quema a los enemigos que se te acercan", "icon": ICON + "skill_23.png"},
	{"id": "hacha",        "title": "HACHA GIRATORIA",    "desc": "Lanza hachas que van y vuelven atravesando todo", "icon": ICON + "skill_25.png"},
	{"id": "rayo",         "title": "RAYO EN CADENA",     "desc": "Un rayo que salta entre enemigos cercanos", "icon": ICON + "skill_70.png"},
	{"id": "laser_cadena", "title": "LASER EN CADENA",    "desc": "Un laser rebota hacia dos enemigos cercanos", "icon": ICON + "skill_40.png"},
	{"id": "disparo_fuego", "title": "DISPARO DE FUEGO",  "desc": "Disparo que quema 3% de vida por segundo durante 3 s", "icon": ICON + "skill_84.png"},
	{"id": "disparo_electrico", "title": "DISPARO ELECTRICO", "desc": "Paraliza al objetivo y puede aturdir enemigos cercanos", "icon": ICON + "skill_71.png"},
	{"id": "disparo_congelante", "title": "DISPARO CONGELANTE", "desc": "Congela al enemigo golpeado", "icon": ICON + "skill_64.png"},
	{"id": "centinela",   "title": "CENTINELA DRON",      "desc": "Un dron te acompaña y dispara al enemigo más cercano", "icon": ICON + "skill_91.png"},
	{"id": "sierras",     "title": "SIERRAS ORBITALES",   "desc": "Una sierra gira a tu alrededor y corta al contacto", "icon": ICON + "skill_39.png"},
	{"id": "aura_lenta",  "title": "AURA HELADA",         "desc": "Frena a los enemigos cercanos", "icon": ICON + "skill_69.png"},
	{"id": "escudo_fuerza", "title": "ESCUDO DE FUERZA",  "desc": "Se recarga cada pocos segundos y bloquea un disparo", "icon": ICON + "skill_1.png"},
	{"id": "pulso",        "title": "PULSO",              "desc": "Una onda expansiva golpea enemigos alrededor", "icon": ICON + "skill_74.png"},
	# ── Escalado cuando la build ya tiene sus 8 armas ──
	{"id": "overflow_attack",  "title": "+15% ATAQUE",    "desc": "Toda tu build pega más fuerte", "icon": ICON + "skill_96.png"},
	{"id": "overflow_defense", "title": "+20% DEFENSA",   "desc": "Aumenta tu barra de defensa", "icon": ICON + "skill_76.png"},
	{"id": "overflow_hp",      "title": "+20% VIDA",      "desc": "Aumenta tu vida máxima y cura un poco", "icon": ICON + "skill_83.png"},
	# ── Relleno cuando no queda nada por mejorar ──
	{"id": "coins",        "title": "BOLSA DE MONEDAS",   "desc": "+25 monedas para la tienda",         "icon": "res://assets/ui/rpg/coin.png"},
	{"id": "heal",         "title": "POCIÓN",             "desc": "Recuperas 30% de tu vida",           "icon": ICON + "skill_86.png"},
]

## Pasivas: id de carta → nivel máximo.
const PASSIVES: Dictionary = {
	"damage": MAX_LEVEL, "atk_speed": MAX_LEVEL, "move_speed": MAX_LEVEL,
	"max_hp": MAX_LEVEL, "hp_regen": MAX_LEVEL, "magnet": MAX_LEVEL,
	"level_damage": 1,
	"toughness": MAX_LEVEL, "area": MAX_LEVEL, "duration": MAX_LEVEL,
	"precision": MAX_LEVEL, "haste": MAX_LEVEL, "bloodthirst": MAX_LEVEL,
}

## Cartas que no salen hasta ganarlas en un desafío (GameState.TRIALS).
const LOCKED_CARDS: Array = ["toughness", "area", "duration", "precision", "haste", "bloodthirst"]

## Armas: "unlock" = carta que la da, "level" = carta que le sube el
## nivel (puede ser la misma), "extras" = cartas propias que no suben
## nivel pero la potencian. "shop" = poder de la tienda que la habilita
## ("" = siempre disponible).
const WEAPONS: Dictionary = {
	"disparo":  {"name": "Disparo a distancia", "unlock": "ranged_bonus", "level": "ranged_power",
		"extras": ["ranged_count", "multishot"], "shop": ""},
	"espadas":  {"name": "Espadas voladoras", "unlock": "flying_swords", "level": "flying_swords_power",
		"extras": ["flying_swords_count"], "shop": "flying_swords"},
	"meteoros": {"name": "Lluvia de meteoros", "unlock": "meteors", "level": "meteors", "extras": [], "shop": "meteors"},
	"aura":     {"name": "Aura sagrada", "unlock": "aura", "level": "aura", "extras": [], "shop": "aura"},
	"hacha":    {"name": "Hacha giratoria", "unlock": "hacha", "level": "hacha", "extras": [], "shop": "hacha"},
	"rayo":     {"name": "Rayo en cadena", "unlock": "rayo", "level": "rayo", "extras": [], "shop": "rayo"},
	"laser_cadena": {"name": "Laser en cadena", "unlock": "laser_cadena", "level": "laser_cadena", "extras": [], "shop": ""},
	"disparo_fuego": {"name": "Disparo de fuego", "unlock": "disparo_fuego", "level": "disparo_fuego", "extras": [], "shop": ""},
	"disparo_electrico": {"name": "Disparo electrico", "unlock": "disparo_electrico", "level": "disparo_electrico", "extras": [], "shop": ""},
	"disparo_congelante": {"name": "Disparo congelante", "unlock": "disparo_congelante", "level": "disparo_congelante", "extras": [], "shop": ""},
	"centinela": {"name": "Centinela dron", "unlock": "centinela", "level": "centinela", "extras": [], "shop": ""},
	"sierras": {"name": "Sierras orbitales", "unlock": "sierras", "level": "sierras", "extras": [], "shop": ""},
	"aura_lenta": {"name": "Aura helada", "unlock": "aura_lenta", "level": "aura_lenta", "extras": [], "shop": ""},
	"escudo_fuerza": {"name": "Escudo de fuerza", "unlock": "escudo_fuerza", "level": "escudo_fuerza", "extras": [], "shop": ""},
	"pulso": {"name": "Pulso", "unlock": "pulso", "level": "pulso", "extras": [], "shop": ""},
}

## Arma al nivel máximo + pasiva compañera → evolución (al abrir un
## cofre). "pollo" es el acompañante: cuenta como al máximo si está.
const EVOLUTIONS: Dictionary = {
	"lluvia_flechas": {"weapon": "disparo", "passive": "atk_speed", "name": "Lluvia de flechas",
		"desc": "Las flechas atraviesan 3 enemigos y cada ráfaga suma 2 más", "icon": ICON + "skill_43.png"},
	"tormenta_espadas": {"weapon": "espadas", "passive": "magnet", "name": "Tormenta de espadas",
		"desc": "Las espadas giran a tu alrededor cortando todo lo que tocan", "icon": ICON + "skill_26.png"},
	"apocalipsis": {"weapon": "meteoros", "passive": "level_damage", "name": "Apocalipsis",
		"desc": "Caen 3 meteoros a la vez, más grandes y más fuertes", "icon": ICON + "skill_35.png"},
	"santuario": {"weapon": "aura", "passive": "max_hp", "name": "Santuario",
		"desc": "El aura crece y te cura mientras quema enemigos", "icon": ICON + "skill_21.png"},
	"torbellino": {"weapon": "hacha", "passive": "damage", "name": "Torbellino",
		"desc": "4 hachas giran sin parar a tu alrededor", "icon": ICON + "skill_36.png"},
	"tormenta_electrica": {"weapon": "rayo", "passive": "move_speed", "name": "Tormenta eléctrica",
		"desc": "El rayo salta a 8 enemigos y cae dos veces", "icon": ICON + "skill_19.png"},
	"gallina_dorada": {"weapon": "pollo", "passive": "hp_regen", "name": "Gallina dorada",
		"desc": "El pollo pone huevos de oro: doble daño y +1 moneda por golpe", "icon": ICON + "skill_90.png"},
	"bastion": {"weapon": "escudo_fuerza", "passive": "toughness", "name": "Bastión",
		"desc": "El escudo aguanta 3 golpes (también cuerpo a cuerpo) y se recarga el doble de rápido", "icon": ICON + "skill_18.png"},
	"terremoto": {"weapon": "pulso", "passive": "area", "name": "Terremoto",
		"desc": "Cada pulso retumba dos veces, más grande, y aturde a los que toca", "icon": ICON + "skill_34.png"},
	"infierno": {"weapon": "disparo_fuego", "passive": "duration", "name": "Infierno",
		"desc": "El fuego se contagia: cada impacto quema a los enemigos de alrededor", "icon": ICON + "skill_32.png"},
	"cero_absoluto": {"weapon": "disparo_congelante", "passive": "precision", "name": "Cero absoluto",
		"desc": "Congela el doble de tiempo y los congelados reciben +50% de daño", "icon": ICON + "skill_59.png"},
	"sobrecarga": {"weapon": "disparo_electrico", "passive": "haste", "name": "Sobrecarga",
		"desc": "El rayo aturde siempre a todos alrededor, en el doble de radio", "icon": ICON + "skill_20.png"},
	"cadena_carmesi": {"weapon": "laser_cadena", "passive": "bloodthirst", "name": "Cadena carmesí",
		"desc": "El láser rebota a 6 enemigos y cada golpe te cura", "icon": ICON + "skill_100.png"},
}

## Cartas de desbloqueo — si todavía no las tenés, se prioriza que
## aparezca al menos una entre las 3 opciones.
const UNLOCK_IDS: Array = [
	"ranged_bonus", "flying_swords", "meteors", "aura", "hacha", "rayo",
	"laser_cadena", "disparo_fuego", "disparo_electrico", "disparo_congelante",
	"centinela", "sierras", "aura_lenta", "escudo_fuerza", "pulso",
]

static func card(id: String) -> Dictionary:
	for c in CARDS:
		if c["id"] == id:
			return c
	return {}

static func weapon_of_card(card_id: String) -> String:
	for w in WEAPONS:
		var data: Dictionary = WEAPONS[w]
		if data["unlock"] == card_id or data["level"] == card_id or card_id in data["extras"]:
			return w
	return ""

## ¿Esta carta puede salir ahora para este player?
static func is_eligible(player, id: String) -> bool:
	if id == "coins" or id == "heal":
		return false
	if id in ["overflow_attack", "overflow_defense", "overflow_hp"]:
		return player.weapons_owned() >= MAX_WEAPONS
	if id in LOCKED_CARDS and not GameState.is_card_unlocked(id):
		return false
	if PASSIVES.has(id):
		if player.weapons_owned() >= MAX_WEAPONS:
			return false
		var lvl: int = player.passive_level(id)
		if lvl >= PASSIVES[id]:
			return false
		return lvl > 0 or player.passives_owned() < MAX_PASSIVES
	# Los personajes que ya disparan de base pueden sumar proyectiles
	# aunque no hayan tomado la carta de disparo.
	if id == "multishot":
		return player.has_ranged_attack() and player.projectiles_per_shot < 4
	var w := weapon_of_card(id)
	if w == "":
		return false
	var data: Dictionary = WEAPONS[w]
	var wlvl: int = player.weapon_level(w)
	if wlvl == 0:
		if id != data["unlock"]:
			return false
		if data["shop"] != "" and not GameState.is_power_unlocked(data["shop"]):
			return false
		return player.weapons_owned() < MAX_WEAPONS
	if id == data["level"]:
		return wlvl < MAX_LEVEL
	match id:
		"ranged_count":
			return player.ranged_bonus_shots < player.RANGED_MAX_BONUS_SHOTS
		"flying_swords_count":
			return player.sword_attacks_per_cycle() < 3
	return false

## Título con el nivel que VA A QUEDAR si se elige.
static func title_for(player, id: String) -> String:
	var c := card(id)
	var title: String = c.get("title", id)
	if player == null:
		return title
	if PASSIVES.has(id) and PASSIVES[id] > 1:
		return "%s  NV %d" % [title, player.passive_level(id) + 1]
	var w := weapon_of_card(id)
	if w != "" and id == WEAPONS[w]["level"] and player.weapon_level(w) > 0:
		return "%s NV %d" % [title, player.weapon_level(w) + 1]
	match id:
		"ranged_count":
			return "%s x%d" % [title, player.ranged_bonus_shots + 1]
		"flying_swords_count":
			return "%s x%d ATAQUES" % [title, player.sword_attacks_per_cycle() + 1]
	return title

## Descripción + pista de evolución si ya la descubriste en otra run.
static func desc_for(player, id: String) -> String:
	var desc: String = card(id).get("desc", "")
	for evo in EVOLUTIONS:
		var e: Dictionary = EVOLUTIONS[evo]
		if not GameState.is_evolution_discovered(evo):
			continue
		var w := weapon_of_card(id)
		if (w != "" and e["weapon"] == w and id == WEAPONS[w]["unlock"]) or e["passive"] == id:
			return desc + "\n• Evoluciona en " + e["name"]
	return desc

## Primera evolución disponible (arma al máximo + pasiva, sin evolucionar).
static func next_evolution(player) -> String:
	for evo in EVOLUTIONS:
		if player.has_evolution(evo):
			continue
		var e: Dictionary = EVOLUTIONS[evo]
		var weapon_ready: bool = player.has_companion("chicken") if e["weapon"] == "pollo" \
			else player.weapon_level(e["weapon"]) >= MAX_LEVEL
		if weapon_ready and player.passive_level(e["passive"]) > 0:
			return evo
	return ""

## Id de la evolución de un arma si ya evolucionó, o "".
static func evolution_of(player, weapon: String) -> String:
	for evo in EVOLUTIONS:
		if EVOLUTIONS[evo]["weapon"] == weapon and player.has_evolution(evo):
			return evo
	return ""



