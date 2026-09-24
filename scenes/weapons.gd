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
