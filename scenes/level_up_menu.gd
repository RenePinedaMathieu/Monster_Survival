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

signal upgrade_chosen(id: String)

# Cada upgrade: id, título, descripción corta, delta (aplicado en
# player.apply_upgrade). Los mismos ids se repiten (stackean).
const UPGRADES: Array = [
	{ "id": "damage",       "title": "+25% DAÑO",         "desc": "El coin pega más" },
	{ "id": "atk_speed",    "title": "+20% ATK SPEED",    "desc": "Auto-disparo más rápido" },
	{ "id": "move_speed",   "title": "+12% MOVE SPEED",   "desc": "Corrés más rápido" },
	{ "id": "max_hp",       "title": "+25% MAX HP",       "desc": "Aguantás más golpes" },
	{ "id": "hp_regen",     "title": "+1 HP/S",           "desc": "Regen pasivo" },
	{ "id": "magnet",       "title": "+40% MAGNET",       "desc": "Absorbés XP desde más lejos" },
	{ "id": "multishot",    "title": "+1 PROYECTIL",      "desc": "Un coin extra por disparo" },
]

var _player: Node = null

func _ready() -> void:
	$Center/VBox/HBox/Card1.pressed.connect(_pick.bind(0))
	$Center/VBox/HBox/Card2.pressed.connect(_pick.bind(1))
	$Center/VBox/HBox/Card3.pressed.connect(_pick.bind(2))

var _current_choices: Array = []

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
		cards[i].text = u.title + "\n\n" + u.desc
	get_tree().paused = true

func _pick(idx: int) -> void:
	var u = _current_choices[idx]
	if _player and _player.has_method("apply_upgrade"):
		_player.apply_upgrade(u.id)
	emit_signal("upgrade_chosen", u.id)
	get_tree().paused = false
	queue_free()

func _random_three() -> Array:
	var pool: Array = UPGRADES.duplicate()
	pool.shuffle()
	return pool.slice(0, 3)
