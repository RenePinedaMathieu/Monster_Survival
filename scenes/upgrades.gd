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

const MAX_WEAPONS := 4
const MAX_PASSIVES := 5
const MAX_LEVEL := 5

const CARDS: Array = [
	# ── Pasivas ──
	{"id": "damage",       "title": "+25% DAÑO",          "desc": "Todas tus armas pegan más",           "icon": ICON + "skill_96.png"},
	{"id": "atk_speed",    "title": "+20% VEL. ATAQUE",   "desc": "Atacas y disparas más seguido",       "icon": ICON + "skill_99.png"},
	{"id": "move_speed",   "title": "+12% VELOCIDAD",     "desc": "Corres más rápido",                   "icon": ICON + "skill_80.png"},
	{"id": "max_hp",       "title": "+25% VIDA MÁXIMA",   "desc": "Aguantas más golpes",                 "icon": ICON + "skill_83.png"},
	{"id": "hp_regen",     "title": "+1 VIDA/S",          "desc": "Regeneración pasiva",                 "icon": ICON + "skill_79.png"},
	{"id": "magnet",       "title": "+40% IMÁN",          "desc": "Absorbes experiencia desde más lejos", "icon": ICON + "skill_30.png"},
	{"id": "level_damage", "title": "INSTINTO ASESINO",   "desc": "+10% de daño en cada nivel futuro",   "icon": ICON + "skill_53.png"},
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
	# ── Relleno cuando no queda nada por mejorar ──
	{"id": "coins",        "title": "BOLSA DE MONEDAS",   "desc": "+25 monedas para la tienda",         "icon": "res://assets/ui/rpg/coin.png"},
	{"id": "heal",         "title": "POCIÓN",             "desc": "Recuperas 30% de tu vida",           "icon": ICON + "skill_86.png"},
]

## Pasivas: id de carta → nivel máximo.
const PASSIVES: Dictionary = {
	"damage": MAX_LEVEL, "atk_speed": MAX_LEVEL, "move_speed": MAX_LEVEL,
	"max_hp": MAX_LEVEL, "hp_regen": MAX_LEVEL, "magnet": MAX_LEVEL,
	"level_damage": 1,
}

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
}

## Cartas de desbloqueo — si todavía no las tenés, se prioriza que
## aparezca al menos una entre las 3 opciones.
const UNLOCK_IDS: Array = ["ranged_bonus", "flying_swords", "meteors", "aura", "hacha", "rayo"]

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
	if PASSIVES.has(id):
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
