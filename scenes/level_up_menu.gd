extends CanvasLayer

## Modal de subida de nivel. Pausa el juego, muestra 3 upgrades al
## azar de la pool, y al elegir uno lo aplica al player y despausa.
##
## Uso:
##   var menu = LEVEL_UP_MENU.instantiate()
##   add_child(menu)
##   menu.show_for(player)
##
## El menu se auto-destruye después de elegir.

const UITheme := preload("res://scenes/ui_theme.gd")

signal upgrade_chosen(id: String)

# Cada upgrade: id, título, descripción corta, icon.
# icon es opcional — apunta a un PNG de assets/ui/weapon_icons/ (32x32
# craftpix). Los números elegidos son placeholders semi-lógicos (ej.
# damage → icon_01 asumiendo que es una espada). Cuando probemos y
# algún icon no coincida con la carta lo cambiamos acá.
#
# "Disparo a distancia" y "espadas voladoras" son primero un
# desbloqueo y después se RAMIFICAN en dos caminos independientes
# que el jugador elige por separado en cada level-up:
#   _power  → más fuerte / más nivel / más efecto visual
#   _count  → más cantidad (más disparos por ráfaga / más espadas
#             atacando a la vez)
## Mapeo icon → carta con el pack "100 weapon icons" (Craftpix). Los
## iconos son 32x32 pixel art (espadas, arcos, escudos, martillos,
## etc) — matchean mejor la estética pixel del juego que los skill
## icons 256x256 de arte más pulido. Layout del atlas:
##   001-020 espadas | 021-040 arcos/ballestas | 041-050 báculos
##   051-060 martillos | 061-070 escudos | 071-080 lanzas
##   081-090 hachas | 091-100 varitas
const ICON_BASE := "res://assets/ui/weapon_icons/"
const UPGRADES: Array = [
	{ "id": "damage",       "title": "+25% DAÑO",         "desc": "El disparo pega más",
		"icon": ICON_BASE + "icon_96.png" },
	{ "id": "atk_speed",    "title": "+20% ATK SPEED",    "desc": "Auto-disparo más rápido",
		"icon": ICON_BASE + "icon_99.png" },
	{ "id": "move_speed",   "title": "+12% MOVE SPEED",   "desc": "Corres más rápido",
		"icon": ICON_BASE + "icon_80.png" },
	{ "id": "max_hp",       "title": "+25% MAX HP",       "desc": "Aguantas más golpes",
		"icon": ICON_BASE + "icon_83.png" },
	{ "id": "hp_regen",     "title": "+1 HP/S",           "desc": "Regen pasivo",
		"icon": ICON_BASE + "icon_79.png" },
	{ "id": "magnet",       "title": "+40% MAGNET",       "desc": "Absorbes XP desde más lejos",
		"icon": ICON_BASE + "icon_30.png" },
	{ "id": "multishot",    "title": "+1 PROYECTIL",      "desc": "Un disparo extra por ráfaga (hasta 4)",
		"icon": ICON_BASE + "icon_63.png" },
	{ "id": "ranged_bonus", "title": "DISPARO A DISTANCIA", "desc": "Desbloqueas un disparo automático en tu ataque normal",
		"icon": ICON_BASE + "icon_55.png" },
	{ "id": "ranged_power", "title": "DISPARO A DISTANCIA", "desc": "Más fuerte y más brillante",
		"icon": ICON_BASE + "icon_67.png" },
	{ "id": "ranged_count", "title": "DISPARO A DISTANCIA", "desc": "Sumas otro disparo a la ráfaga",
		"icon": ICON_BASE + "icon_63.png" },
	{ "id": "level_damage", "title": "INSTINTO ASESINO",  "desc": "+10% de daño automático en cada nivel futuro",
		"icon": ICON_BASE + "icon_37.png" },
	{ "id": "meteors",      "title": "LLUVIA DE METEOROS", "desc": "Meteoritos caen solos cerca de los enemigos",
		"icon": ICON_BASE + "icon_22.png" },
	{ "id": "flying_swords",       "title": "ESPADAS VOLADORAS", "desc": "5 espadas te rodean y atacan solas",
		"icon": ICON_BASE + "icon_05.png" },
	{ "id": "flying_swords_power", "title": "ESPADAS VOLADORAS", "desc": "Más fuertes y más brillantes",
		"icon": ICON_BASE + "icon_65.png" },
	{ "id": "flying_swords_count", "title": "ESPADAS VOLADORAS", "desc": "Más espadas atacan a la vez",
		"icon": ICON_BASE + "icon_65.png" },
]

## Cartas que "desbloquean" una mecánica nueva — mientras no las
## tengamos todavía, se prioriza que aparezcan entre las 3 opciones
## en vez de dejarlo librado al azar puro.
const UNLOCK_IDS := ["ranged_bonus", "flying_swords", "meteors"]

var _player: Node = null
var _current_choices: Array = []

func _ready() -> void:
	UITheme.style_label($Center/VBox/Title, 38, true)
	for i in range(3):
		var card: Button = [
			$Center/VBox/HBox/Card1,
			$Center/VBox/HBox/Card2,
			$Center/VBox/HBox/Card3,
		][i]
		UITheme.style_button(card, 17)
		card.mouse_entered.connect(UITheme.pulse.bind(card, 1.04, 0.08))
		card.mouse_exited.connect(UITheme.pulse.bind(card, 1.0, 0.08))
	$Center/VBox/HBox/Card1.pressed.connect(_pick.bind(0))
	$Center/VBox/HBox/Card2.pressed.connect(_pick.bind(1))
	$Center/VBox/HBox/Card3.pressed.connect(_pick.bind(2))

func show_for(player: Node) -> void:
	_player = player
	_current_choices = _random_three()
	var cards := [
		$Center/VBox/HBox/Card1,
		$Center/VBox/HBox/Card2,
		$Center/VBox/HBox/Card3,
	]
	for i in range(3):
		var u = _current_choices[i]
		cards[i].text = _title_for(u) + "\n\n" + u.desc
		# Ícono de la carta — Button.icon soporta Texture2D nativamente
		# y lo pone al lado del texto. Con expand_icon y alineación
		# center-top queda arriba del texto de la carta.
		if u.has("icon") and ResourceLoader.exists(u["icon"]):
			cards[i].icon = load(u["icon"])
			cards[i].expand_icon = true
			cards[i].icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cards[i].vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		else:
			cards[i].icon = null
	Audio.play_sfx("level_up")
	get_tree().paused = true

func _pick(idx: int) -> void:
	var u = _current_choices[idx]
	if _player and _player.has_method("apply_upgrade"):
		_player.apply_upgrade(u.id)
	Audio.play_sfx("card_selected")
	emit_signal("upgrade_chosen", u.id)
	get_tree().paused = false
	queue_free()

## Arma las 3 opciones:
##   1. Filtra cartas que hoy no harían nada (ej: la rama "más
##      cantidad" del disparo antes de desbloquear el disparo, o
##      cualquier rama ya al tope de su nivel).
##   2. Si hay una carta de desbloqueo todavía no tomada, GARANTIZA
##      que aparezca entre las 3 — evita pasar la run entera sin ver
##      "espadas"/"meteoritos" sólo por mala suerte del sorteo.
##   3. El resto de los slots se llena al azar del pool elegible.
func _random_three() -> Array:
	var eligible: Array = UPGRADES.filter(_is_eligible)

	var chosen: Array = []
	var pending_unlocks: Array = eligible.filter(
		func(u): return u["id"] in UNLOCK_IDS and not _already_unlocked(u["id"])
	)
	if not pending_unlocks.is_empty():
		var forced = pending_unlocks[randi() % pending_unlocks.size()]
		chosen.append(forced)
		eligible.erase(forced)

	eligible.shuffle()
	for u in eligible:
		if chosen.size() >= 3:
			break
		chosen.append(u)

	chosen.shuffle()   # que la carta forzada no quede siempre en Card1
	return chosen

## Los cuatro caminos ramificados muestran el nivel/cantidad que VAN
## A QUEDAR si se eligen, en vez del título fijo del pool.
func _title_for(u: Dictionary) -> String:
	if _player == null:
		return u.title
	match u["id"]:
		"ranged_power":
			return "DISPARO A DISTANCIA NV %d" % (_player.ranged_power_level + 1)
		"ranged_count":
			return "DISPARO A DISTANCIA x%d" % (_player.ranged_bonus_shots + 1)
		"flying_swords_power":
			return "ESPADAS VOLADORAS NV %d" % (_player.sword_level() + 1)
		"flying_swords_count":
			return "ESPADAS VOLADORAS x%d ATAQUES" % (_player.sword_attacks_per_cycle() + 1)
	return u.title

func _is_eligible(u: Dictionary) -> bool:
	if _player == null:
		return true
	match u["id"]:
		"multishot":
			# No sirve de nada mientras no dispare nada (AXEL sin
			# "disparo a distancia" todavía), ni pasado el tope (4).
			if not _player.has_ranged_attack():
				return false
			return _player.projectiles_per_shot < 4
		"ranged_bonus":
			return _player.ranged_power_level == 0
		"ranged_power":
			return _player.ranged_power_level > 0 and _player.ranged_power_level < _player.RANGED_MAX_POWER_LEVEL
		"ranged_count":
			return _player.ranged_power_level > 0 and _player.ranged_bonus_shots < _player.RANGED_MAX_BONUS_SHOTS
		"flying_swords":
			return not _player.has_flying_swords()
		"flying_swords_power":
			return _player.has_flying_swords() and _player.sword_level() < 5
		"flying_swords_count":
			return _player.has_flying_swords() and _player.sword_attacks_per_cycle() < 3
	return true

func _already_unlocked(id: String) -> bool:
	if _player == null:
		return false
	match id:
		"ranged_bonus":
			return _player.has_method("has_ranged_attack") and _player.ranged_power_level > 0
		"flying_swords":
			return _player.has_method("has_flying_swords") and _player.has_flying_swords()
		"meteors":
			return _player.has_method("has_meteors") and _player.has_meteors()
	return false
