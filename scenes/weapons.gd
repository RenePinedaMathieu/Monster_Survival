extends RefCounted

## Catálogo de fuentes de daño: el id que cada arma le pasa a
## monster.take_damage(amount, source), con el nombre y el ícono que
## se muestran en la pantalla de resultados ("daño por arma").
## Se usa vía preload, igual que ui_theme.gd.

const SKILL := "res://assets/ui/skill_icons/"
const COMP := "res://assets/companions/"

const SOURCES: Dictionary = {
	"ataque":   {"name": "Ataque básico",       "icon": "res://assets/ui/weapon_icons/icon_15.png"},
	"disparo":  {"name": "Disparo a distancia", "icon": SKILL + "skill_55.png"},
	"espadas":  {"name": "Espadas voladoras",   "icon": SKILL + "skill_5.png"},
	"meteoros": {"name": "Lluvia de meteoros",  "icon": SKILL + "skill_22.png"},
	# Acompañantes (companion.gd): primer frame del idle de frente.
	"pollo":    {"name": "Gallina",             "icon": COMP + "chicken/idle_front.png", "region": Rect2(0, 0, 18, 18)},
	"toro":     {"name": "Toro",                "icon": COMP + "bull/idle_front.png", "region": Rect2(0, 0, 44, 34)},
	"caballo":  {"name": "Caballo",             "icon": COMP + "horse/idle_front.png", "region": Rect2(0, 0, 44, 36)},
	"cabra":    {"name": "Cabra",               "icon": COMP + "goat/idle_front.png", "region": Rect2(0, 0, 28, 28)},
	"ganso":    {"name": "Ganso",               "icon": COMP + "goose/idle_front.png", "region": Rect2(0, 0, 20, 28)},
	"veneno":   {"name": "Veneno",              "icon": SKILL + "skill_33.png"},
	"habilidad": {"name": "Habilidad",          "icon": SKILL + "skill_62.png"},
	"lobo":     {"name": "Lobo",                "icon": SKILL + "skill_75.png"},
	"bomba":    {"name": "Bomba",               "icon": SKILL + "skill_98.png"},
	"aura":     {"name": "Aura de fuego",        "icon": SKILL + "skill_23.png"},
	"hacha":    {"name": "Hacha giratoria",     "icon": SKILL + "skill_25.png"},
	"rayo":     {"name": "Rayo en cadena",      "icon": SKILL + "skill_70.png"},
	"laser_cadena": {"name": "Laser en cadena", "icon": SKILL + "skill_40.png"},
	"disparo_fuego": {"name": "Flecha de fuego", "icon": SKILL + "skill_84.png"},
	"quemadura": {"name": "Quemadura", "icon": SKILL + "skill_84.png"},
	"disparo_electrico": {"name": "Flecha eléctrica", "icon": SKILL + "skill_71.png"},
	"disparo_congelante": {"name": "Flecha congelante", "icon": SKILL + "skill_64.png"},
	"centinela": {"name": "Centinela dron", "icon": SKILL + "skill_91.png"},
	"sierras": {"name": "Sierras orbitales", "icon": SKILL + "skill_39.png"},
	"aura_lenta": {"name": "Aura helada", "icon": SKILL + "skill_69.png"},
	"escudo_fuerza": {"name": "Escudo de fuerza", "icon": SKILL + "skill_1.png"},
	"pulso": {"name": "Pulso", "icon": SKILL + "skill_74.png"},
	# Evoluciones (upgrades.gd EVOLUTIONS) — el arma evolucionada reporta
	# su daño con el id de la evolución.
	"lluvia_flechas":     {"name": "Lluvia de flechas",   "icon": SKILL + "skill_43.png"},
	"tormenta_espadas":   {"name": "Tormenta de espadas", "icon": SKILL + "skill_26.png"},
	"apocalipsis":        {"name": "Apocalipsis",         "icon": SKILL + "skill_35.png"},
	"santuario":          {"name": "Santuario",           "icon": SKILL + "skill_21.png"},
	"torbellino":         {"name": "Torbellino",          "icon": SKILL + "skill_36.png"},
	"tormenta_electrica": {"name": "Tormenta eléctrica",  "icon": SKILL + "skill_19.png"},
	"gallina_dorada":     {"name": "Gallina dorada",      "icon": SKILL + "skill_90.png"},
	"terremoto":          {"name": "Terremoto",           "icon": SKILL + "skill_34.png"},
	"infierno":           {"name": "Infierno",            "icon": SKILL + "skill_32.png"},
	"cero_absoluto":      {"name": "Cero absoluto",       "icon": SKILL + "skill_59.png"},
	"sobrecarga":         {"name": "Sobrecarga",          "icon": SKILL + "skill_20.png"},
	"cadena_carmesi":     {"name": "Cadena carmesí",      "icon": SKILL + "skill_100.png"},
}

static func display_name(id: String) -> String:
	return SOURCES.get(id, {}).get("name", id.capitalize())

## Ícono del arma como textura lista para un TextureRect (recorta la
## región si el ícono es un frame dentro de una hoja de sprites).
static func icon(id: String) -> Texture2D:
	var data: Dictionary = SOURCES.get(id, {})
	var path: String = data.get("icon", "")
	if path == "" or not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path)
	if data.has("region"):
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = data["region"]
		return atlas
	return tex
