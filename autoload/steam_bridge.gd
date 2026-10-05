extends Node

## Autoload "SteamBridge" — conecta los logros propios del juego
## (GameState.ACHIEVEMENTS) con los logros de Steam.
##
## Funciona sólo si el build tiene el addon GodotSteam (GDExtension) y
## el juego se lanzó desde Steam. Si no — editor, Web, build sin el
## addon — no hace NADA: no hay referencias directas al singleton
## "Steam" en el código (se pide por nombre con Engine.get_singleton),
## así el proyecto compila igual con o sin el addon instalado.
##
## En Steamworks, cada logro tiene que crearse con este "API Name":
##   "ACH_" + id en mayúsculas   (ej: kills_100 → ACH_KILLS_100)
## Ver steam_api_name(). La lista completa la arma GameState.ACHIEVEMENTS.
##
## Guardado en la nube (Steam Cloud) NO necesita código: se configura en
## Steamworks → Steam Cloud → Auto-Cloud apuntando a la carpeta de
## usuario del juego (%APPDATA%/OneLastHero en Windows, ver
## config/custom_user_dir_name en project.godot).

var _steam = null   # sin tipo: el singleton sólo existe con el addon
var active: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("web") or not Engine.has_singleton("Steam"):
		return
	_steam = Engine.get_singleton("Steam")
	var result = _steam.steamInitEx()
	# GodotSteam devuelve {"status": 0, "verbal": "..."}; 0 = todo OK.
	if typeof(result) == TYPE_DICTIONARY and int(result.get("status", 1)) != 0:
		push_warning("[steam] no se pudo iniciar: %s" % str(result.get("verbal", "")))
		_steam = null
		return
	active = true
	GameState.achievement_unlocked.connect(_on_achievement_unlocked)
	# Logros conseguidos antes de tener Steam (o en otra PC sin nube):
	# se suben todos al arrancar. setAchievement es idempotente.
	for id in GameState.achievements_unlocked:
		_steam.setAchievement(steam_api_name(id))
	_steam.storeStats()

func _process(_delta: float) -> void:
	if active:
		_steam.run_callbacks()

static func steam_api_name(id: String) -> String:
	return "ACH_" + id.to_upper()

func _on_achievement_unlocked(achievement: Dictionary) -> void:
	if not active:
		return
	_steam.setAchievement(steam_api_name(achievement["id"]))
	_steam.storeStats()
