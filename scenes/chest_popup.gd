extends CanvasLayer

## Ventana al abrir un cofre (chest.gd). Pausa el juego y da la
## recompensa:
##   - si hay una evolución lista (arma al máximo + su pasiva, ver
##     upgrades.gd) → EVOLUCIÓN, y queda como descubierta para siempre;
##   - si no → una mejora al azar de las que podrían salir en un
##     level-up, gratis;
##   - siempre + CHEST_COINS monedas.

const RpgTheme := preload("res://scenes/rpg_theme.gd")
const Upgrades := preload("res://scenes/upgrades.gd")
const CHEST_COINS := 10
const COLOR_EVO := Color("b8860b")

@onready var _window: PanelContainer = $Center/Window
@onready var _title: Label = $Center/Window/VBox/Title
@onready var _icon: TextureRect = $Center/Window/VBox/Icon
@onready var _name: Label = $Center/Window/VBox/Name
@onready var _desc: Label = $Center/Window/VBox/Desc
@onready var _extra: Label = $Center/Window/VBox/Extra
@onready var _ok: Button = $Center/Window/VBox/OkButton

func _ready() -> void:
	add_to_group("modal")
	get_tree().paused = true
	_window.add_theme_stylebox_override("panel", RpgTheme.window_box_titled(28.0, 24.0))
	_window.custom_minimum_size.x = minf(420.0, Screen.view_size().x - 24.0)
	RpgTheme.style_header_title(_title, 24)
	RpgTheme.style_ink_label(_name, 22, true)
	RpgTheme.style_ink_label(_desc, 15, false, true)
	RpgTheme.style_ink_label(_extra, 15, true)
	_extra.add_theme_color_override("font_color", RpgTheme.COLOR_INK_GOOD)
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	RpgTheme.style_button(_ok, 18)
	_ok.pressed.connect(_close)
	_ok.grab_focus()

func open(player) -> void:
	GameState.bump_stat("chests")
	var extra: Array = []
	var evo := Upgrades.next_evolution(player)
	if evo != "":
		var e: Dictionary = Upgrades.EVOLUTIONS[evo]
		player.evolve(evo)
		_title.text = "¡EVOLUCIÓN!"
		_icon.texture = load(e["icon"])
		_name.text = e["name"]
		_name.add_theme_color_override("font_color", COLOR_EVO)
		_desc.text = e["desc"]
		if GameState.discover_evolution(evo):
			extra.append("¡Nueva evolución descubierta!")
		Audio.play_sfx("wave_clear")
	else:
		var pool: Array = []
		for c in Upgrades.CARDS:
			if Upgrades.is_eligible(player, c["id"]):
				pool.append(c["id"])
		_title.text = "¡COFRE!"
		if pool.is_empty():
			_icon.texture = load("res://assets/ui/rpg/chest.png")
			_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			_name.text = "Tesoro"
			_desc.text = "Ya tienes todo al máximo."
		else:
			var id: String = pool[randi() % pool.size()]
			var c := Upgrades.card(id)
			# El título con nivel se calcula ANTES de aplicarla.
			_name.text = Upgrades.title_for(player, id)
			_icon.texture = load(c["icon"])
			_desc.text = c["desc"]
			player.apply_upgrade(id)
	GameState.add_run_currency(CHEST_COINS)
	extra.append("+%d monedas" % CHEST_COINS)
	_extra.text = "\n".join(extra)

func _close() -> void:
	Audio.play_sfx("card_selected")
	remove_from_group("modal")
	# Si justo quedó abierto otro modal (level-up), la pausa sigue.
	if get_tree().get_nodes_in_group("modal").is_empty():
		get_tree().paused = false
	queue_free()
