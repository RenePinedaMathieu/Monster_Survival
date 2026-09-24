extends RefCounted

## Catálogo de fuentes de daño: el id que cada arma le pasa a
## monster.take_damage(amount, source), con el nombre y el ícono que
## se muestran en la pantalla de resultados ("daño por arma").
## Se usa vía preload, igual que ui_theme.gd.

const SKILL := "res://assets/ui/skill_icons/"

const SOURCES: Dictionary = {
	"ataque":   {"name": "Ataque básico",       "icon": "res://assets/ui/weapon_icons/icon_15.png"},
	"disparo":  {"name": "Disparo a distancia", "icon": SKILL + "skill_55.png"},
	"espadas":  {"name": "Espadas voladoras",   "icon": SKILL + "skill_5.png"},
	"meteoros": {"name": "Lluvia de meteoros",  "icon": SKILL + "skill_22.png"},
	"pollo":    {"name": "Pollo",               "icon": "res://assets/sprites/Chicken/Idle/Chicken_front_Idle.png",
		"region": Rect2(6, 9, 20, 20)},
	"huevos":   {"name": "Huevos",              "icon": "res://assets/sprites/Chicken/Idle/Chicken_front_Idle.png",
		"region": Rect2(6, 9, 20, 20)},
	"habilidad": {"name": "Habilidad",          "icon": SKILL + "skill_62.png"},
	"bomba":    {"name": "Bomba",               "icon": SKILL + "skill_98.png"},
	"aura":     {"name": "Aura sagrada",        "icon": SKILL + "skill_23.png"},
	"hacha":    {"name": "Hacha giratoria",     "icon": SKILL + "skill_25.png"},
	"rayo":     {"name": "Rayo en cadena",      "icon": SKILL + "skill_70.png"},
	# Evoluciones (upgrades.gd EVOLUTIONS) — el arma evolucionada reporta
	# su daño con el id de la evolución.
	"lluvia_flechas":     {"name": "Lluvia de flechas",   "icon": SKILL + "skill_43.png"},
	"tormenta_espadas":   {"name": "Tormenta de espadas", "icon": SKILL + "skill_26.png"},
	"apocalipsis":        {"name": "Apocalipsis",         "icon": SKILL + "skill_35.png"},
	"santuario":          {"name": "Santuario",           "icon": SKILL + "skill_21.png"},
	"torbellino":         {"name": "Torbellino",          "icon": SKILL + "skill_36.png"},
	"tormenta_electrica": {"name": "Tormenta eléctrica",  "icon": SKILL + "skill_19.png"},
	"gallina_dorada":     {"name": "Gallina dorada",      "icon": SKILL + "skill_90.png"},
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
