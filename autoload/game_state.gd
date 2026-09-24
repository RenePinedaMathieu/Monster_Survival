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

## Cada item: nombre, descripción, costo base, cuánto sube el costo
## por nivel comprado, y tope de niveles. Los bonos reales que dan
## están en get_bonus_*() más abajo — player.gd los lee al arrancar
## cada run.
const SHOP_ITEMS: Dictionary = {
	"armor": {
		"name": "Armadura", "desc": "+8 de defensa — absorbe daño antes que la vida",
		"base_cost": 20, "cost_step": 15, "max_level": 10,
	},
	"max_hp": {
		"name": "Vitalidad", "desc": "+15 vida máxima inicial",
		"base_cost": 15, "cost_step": 10, "max_level": 10,
	},
	"damage": {
		"name": "Fuerza", "desc": "+5% daño inicial",
		"base_cost": 18, "cost_step": 12, "max_level": 10,
	},
	"regen": {
		"name": "Vigor", "desc": "+0.3 HP/s de regeneración inicial",
		"base_cost": 25, "cost_step": 18, "max_level": 5,
	},
}

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
	if beat_wave or beat_time:
		_save()
	return {"wave": beat_wave, "time": beat_time}

func mark_tutorial_seen() -> void:
	if tutorial_seen:
		return
	tutorial_seen = true
	_save()

## Se llama por cada monstruo que muere durante la run (ver
## monster.gd). No toca total_currency todavía.
func add_run_currency(amount: int) -> void:
	run_currency += amount
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
	var item: Dictionary = SHOP_ITEMS[id]
	return item["base_cost"] + get_shop_level(id) * item["cost_step"]

func can_afford(id: String) -> bool:
	var item: Dictionary = SHOP_ITEMS[id]
	if get_shop_level(id) >= item["max_level"]:
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
