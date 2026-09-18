extends Control

## Tienda de mejoras permanentes — comprás con la moneda ganada en
## runs anteriores (GameState.total_currency). Las filas se arman por
## código a partir de GameState.SHOP_ITEMS en vez de a mano en la
## escena, así agregar un ítem nuevo es sólo tocar game_state.gd.
##
## Los bonos comprados los aplica player.gd al arrancar cada run (ver
## GameState.get_bonus_*()) — esta pantalla sólo gasta moneda y guarda.

const UITheme := preload("res://scenes/ui_theme.gd")
const MENU_SCENE := "res://scenes/main_menu.tscn"
const BACKGROUND_TEXTURE := "res://assets/layouts/background_home.png"

@onready var _background: TextureRect = $Background
@onready var _title_label: Label = $Layout/Title
@onready var _currency_label: Label = $Layout/Currency
@onready var _item_list: VBoxContainer = $Layout/ItemList
@onready var _back_button: Button = $Layout/BackButton

var _row_refs: Dictionary = {}   # id -> {level_label, buy_button}

func _ready() -> void:
	_background.texture = load(BACKGROUND_TEXTURE)
	UITheme.style_label(_title_label, 36, true)
	UITheme.style_label(_currency_label, 20)
	UITheme.style_button(_back_button)
	_back_button.mouse_entered.connect(UITheme.pulse.bind(_back_button, 1.05, 0.08))
	_back_button.mouse_exited.connect(UITheme.pulse.bind(_back_button, 1.0, 0.08))
	_back_button.pressed.connect(_on_back_pressed)

	_build_items()
	_refresh()
	_back_button.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()

func _build_items() -> void:
	for id in GameState.SHOP_ITEMS:
		var item: Dictionary = GameState.SHOP_ITEMS[id]

		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UITheme.make_panel_box())
		_item_list.add_child(row)

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 14)
		margin.add_theme_constant_override("margin_right", 14)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_bottom", 10)
		row.add_child(margin)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 16)
		margin.add_child(hbox)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = 3
		hbox.add_child(info)

		var name_label := Label.new()
		name_label.text = item["name"]
		UITheme.style_label(name_label, 20, true)
		info.add_child(name_label)

		var desc_label := Label.new()
		desc_label.text = item["desc"]
		UITheme.style_label(desc_label, 13)
		desc_label.modulate.a = 0.8
		info.add_child(desc_label)

		var level_label := Label.new()
		UITheme.style_label(level_label, 13)
		level_label.modulate.a = 0.85
		info.add_child(level_label)

		var buy_button := Button.new()
		buy_button.custom_minimum_size = Vector2(150, 54)
		UITheme.style_button(buy_button, 15)
		buy_button.pressed.connect(_on_buy_pressed.bind(id))
		hbox.add_child(buy_button)

		_row_refs[id] = {"level_label": level_label, "buy_button": buy_button}

func _refresh() -> void:
	_currency_label.text = "Monedas: %d" % GameState.total_currency
	for id in GameState.SHOP_ITEMS:
		var item: Dictionary = GameState.SHOP_ITEMS[id]
		var level: int = GameState.get_shop_level(id)
		var refs: Dictionary = _row_refs[id]
		var maxed: bool = level >= item["max_level"]
		refs["level_label"].text = "Nivel %d / %d" % [level, item["max_level"]]
		if maxed:
			refs["buy_button"].text = "MÁXIMO"
			refs["buy_button"].disabled = true
		else:
			refs["buy_button"].text = "COMPRAR\n%d monedas" % GameState.get_shop_cost(id)
			refs["buy_button"].disabled = not GameState.can_afford(id)

func _on_buy_pressed(id: String) -> void:
	if GameState.buy_shop_item(id):
		_refresh()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
