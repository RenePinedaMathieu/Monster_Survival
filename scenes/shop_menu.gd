extends Control

## Tienda de mejoras permanentes — comprás con la moneda ganada en
## runs anteriores (GameState.total_currency). Las filas se arman por
## código a partir de GameState.SHOP_ITEMS en vez de a mano en la
## escena, así agregar un ítem nuevo es sólo tocar game_state.gd.
##
## Los bonos comprados los aplica player.gd al arrancar cada run (ver
## GameState.get_bonus_*()) — esta pantalla sólo gasta moneda y guarda.
##
## Cada fila es una "tarjeta" con: ícono pixel-art + borde de color
## propios por categoría (ver ITEM_STYLE), una barra de nivel (no sólo
## el texto "Nivel X/Y"), y el botón de compra cambia de estilo según
## el estado — máximo / no alcanza la moneda / listo para comprar —
## en vez de ser siempre el mismo botón dorado con el texto cambiado.

const UITheme := preload("res://scenes/ui_theme.gd")
const PixelIconScript := preload("res://scenes/pixel_icon.gd")
const BACKGROUND_TEXTURE := "res://assets/layouts/background_home.png"

## Identidad visual por ítem — no vive en GameState porque es
## puramente cosmético de esta pantalla, GameState.SHOP_ITEMS sólo
## tiene los datos de balance (costo, nombre, etc).
const ITEM_STYLE: Dictionary = {
	"armor":  {"icon": "shield", "color": Color("6fa8dc")},
	"max_hp": {"icon": "heart",  "color": Color("e0645a")},
	"damage": {"icon": "fist",   "color": Color("e0a94c")},
	"regen":  {"icon": "spark",  "color": Color("6bcf6b")},
}

const COLOR_MAXED := Color(0.5, 0.5, 0.5)
const COLOR_LOCKED := Color(0.6, 0.35, 0.32)

@onready var _background: TextureRect = $Background
@onready var _title_label: Label = $Layout/Title
@onready var _currency_label: Label = $Layout/CurrencyRow/Currency
@onready var _currency_icon: Control = $Layout/CurrencyRow/CoinIcon
@onready var _item_list: VBoxContainer = $Layout/ItemList
@onready var _back_button: Button = $Layout/BackButton

var _row_refs: Dictionary = {}   # id -> {level_label, level_bar, buy_button, card_style}

func _ready() -> void:
	_background.texture = load(BACKGROUND_TEXTURE)
	UITheme.style_label(_title_label, 36, true)
	UITheme.style_label(_currency_label, 22, true)
	_currency_icon.queue_redraw()
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
		var style: Dictionary = ITEM_STYLE.get(id, {"icon": "spark", "color": UITheme.COLOR_BORDER})
		var accent: Color = style["color"]

		var card := PanelContainer.new()
		var card_style := UITheme.make_box(Color(0.09, 0.07, 0.06, 0.88), accent, 0.0, 3)
		card.add_theme_stylebox_override("panel", card_style)
		card.mouse_entered.connect(UITheme.pulse.bind(card, 1.015, 0.1))
		card.mouse_exited.connect(UITheme.pulse.bind(card, 1.0, 0.1))
		_item_list.add_child(card)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 18)
		card.add_child(hbox)

		# Insignia del ícono: un cuadrito oscuro teñido con el color de
		# la categoría, con el ícono pixel-art adentro.
		var badge := PanelContainer.new()
		var badge_style := UITheme.make_box(Color(accent, 0.16), Color(accent, 0.7), 0.0, 2)
		badge_style.content_margin_left = 0.0
		badge_style.content_margin_right = 0.0
		badge_style.content_margin_top = 0.0
		badge_style.content_margin_bottom = 0.0
		badge.add_theme_stylebox_override("panel", badge_style)
		badge.custom_minimum_size = Vector2(56, 56)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(badge)

		# Sin tipo explícito a propósito: el script del ícono se pega en
		# runtime con set_script(), y tiparlo como Control rompería la
		# build (warnings-as-errors) al asignarle icon_id/color, que no
		# existen en la clase base — mismo motivo que _swords_rig en
		# player.gd.
		var icon = Control.new()
		icon.set_script(PixelIconScript)
		icon.custom_minimum_size = Vector2(PixelIconScript.BOX, PixelIconScript.BOX)
		# Sin esto, el PanelContainer estira el ícono a los 56x56 de la
		# insignia entera y el dibujo (centrado para un box de 40x40)
		# queda pegado a la esquina en vez de centrado.
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.icon_id = style["icon"]
		icon.color = accent
		badge.add_child(icon)

		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 4)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(info)

		var name_label := Label.new()
		name_label.text = item["name"]
		UITheme.style_label(name_label, 20, true)
		name_label.add_theme_color_override("font_color", accent.lightened(0.15))
		info.add_child(name_label)

		var desc_label := Label.new()
		desc_label.text = item["desc"]
		UITheme.style_label(desc_label, 13)
		desc_label.modulate.a = 0.8
		info.add_child(desc_label)

		var level_row := HBoxContainer.new()
		level_row.add_theme_constant_override("separation", 10)
		info.add_child(level_row)

		var level_bar := ProgressBar.new()
		level_bar.min_value = 0
		level_bar.max_value = item["max_level"]
		level_bar.show_percentage = false
		level_bar.custom_minimum_size = Vector2(140, 12)
		level_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		UITheme.style_progress_bar(level_bar, accent)
		level_row.add_child(level_bar)

		var level_label := Label.new()
		UITheme.style_label(level_label, 13)
		level_label.modulate.a = 0.85
		level_row.add_child(level_label)

		var buy_button := Button.new()
		buy_button.custom_minimum_size = Vector2(150, 58)
		UITheme.style_button(buy_button, 15)
		buy_button.pressed.connect(_on_buy_pressed.bind(id))
		hbox.add_child(buy_button)

		_row_refs[id] = {
			"level_label": level_label, "level_bar": level_bar,
			"buy_button": buy_button, "card_style": card_style, "accent": accent,
		}

func _refresh() -> void:
	_currency_label.text = "%d" % GameState.total_currency
	for id in GameState.SHOP_ITEMS:
		var item: Dictionary = GameState.SHOP_ITEMS[id]
		var level: int = GameState.get_shop_level(id)
		var refs: Dictionary = _row_refs[id]
		var maxed: bool = level >= item["max_level"]
		var accent: Color = refs["accent"]

		refs["level_bar"].value = level
		refs["level_label"].text = "%d / %d" % [level, item["max_level"]]

		var buy_button: Button = refs["buy_button"]
		var card_style: StyleBoxFlat = refs["card_style"]
		if maxed:
			buy_button.text = "MÁXIMO"
			buy_button.disabled = true
			card_style.border_color = COLOR_MAXED
			_style_buy_button(buy_button, COLOR_MAXED, false)
		else:
			var affordable: bool = GameState.can_afford(id)
			buy_button.text = "COMPRAR\n%d monedas" % GameState.get_shop_cost(id)
			buy_button.disabled = not affordable
			card_style.border_color = accent if affordable else Color(accent, 0.35)
			_style_buy_button(buy_button, accent if affordable else COLOR_LOCKED, affordable)

## El mismo botón cambia de "personalidad" según si de verdad se
## puede comprar ahora — dorado y listo para hacer clic, apagado en
## gris si ya está al máximo, o con un borde apagado (se ve el costo
## pero no invita a tocarlo) si todavía no alcanza la moneda.
func _style_buy_button(button: Button, border: Color, ready_to_buy: bool) -> void:
	var fill: Color = UITheme.COLOR_FILL if ready_to_buy else Color(0.08, 0.07, 0.06)
	button.add_theme_stylebox_override("normal", UITheme.make_box(fill, border))
	button.add_theme_stylebox_override("disabled", UITheme.make_box(fill, border))
	if ready_to_buy:
		button.add_theme_stylebox_override("hover", UITheme.make_box(UITheme.COLOR_FILL_HOVER, UITheme.COLOR_BORDER_HOVER))
		button.add_theme_stylebox_override("pressed", UITheme.make_box(UITheme.COLOR_FILL_PRESSED, UITheme.COLOR_BORDER_HOVER, 3.0))
	button.add_theme_color_override("font_color", UITheme.COLOR_TEXT if ready_to_buy else Color(border, 0.9))
	button.add_theme_color_override("font_disabled_color", Color(border, 0.9))

func _on_buy_pressed(id: String) -> void:
	if GameState.buy_shop_item(id):
		Audio.play_sfx("card_selected")
		_refresh()

func _on_back_pressed() -> void:
	# La tienda es accesible desde el menú principal Y desde la barra
	# superior de selección de personaje — vuelve a la que corresponda.
	get_tree().change_scene_to_file(GameState.shop_return_scene)
