extends Control

## Tienda — todo se compra con la moneda banqueada de runs anteriores
## (GameState.total_currency). Tres pestañas:
##   MEJORAS       bonos permanentes por nivel (GameState.SHOP_ITEMS),
##                 player.gd los aplica al arrancar cada run.
##   PODERES       compra única que habilita que la carta del poder
##                 salga en los level-ups (GameState.SHOP_POWERS).
##   ACOMPAÑANTES  mascotas que te siguen y atacan; se compran una vez
##                 y se lleva una equipada (GameState.COMPANIONS).
##
## Las tarjetas se arman por código desde los dicts de GameState, así
## sumar un ítem es tocar game_state.gd + su ícono acá. Estilo del pack
## pergamino/verde, ver rpg_theme.gd.

const RpgTheme := preload("res://scenes/rpg_theme.gd")
const PixelIconScript := preload("res://scenes/pixel_icon.gd")
const BACKGROUND_TEXTURE := "res://assets/layouts/background_home.png"
const COIN_TEXTURE := "res://assets/ui/rpg/coin.png"

enum Tab { UPGRADES, POWERS, COMPANIONS }

const TAB_HINTS: Dictionary = {
	Tab.UPGRADES: "Bonos permanentes: se aplican al arrancar cada partida.",
	Tab.POWERS: "Compra única: el poder empieza a salir como carta al subir de nivel durante las oleadas.",
	Tab.COMPANIONS: "Te acompañan en cada partida y atacan solos. Podés llevar uno a la vez.",
}

## Identidad visual — puramente cosmética de esta pantalla, por eso no
## vive en GameState (que sólo tiene datos de balance).
const ITEM_STYLE: Dictionary = {
	"armor":  {"icon": "shield", "color": Color("6fa8dc")},
	"max_hp": {"icon": "heart",  "color": Color("e0645a")},
	"damage": {"icon": "fist",   "color": Color("e0a94c")},
	"regen":  {"icon": "spark",  "color": Color("6bcf6b")},
}
## Mismos íconos que las cartas de level-up que desbloquean.
const POWER_ICONS: Dictionary = {
	"meteors": "res://assets/ui/skill_icons/skill_22.png",
	"flying_swords": "res://assets/ui/skill_icons/skill_5.png",
}
## Primer frame del idle de frente, recortado al bicho (el frame de
## 32x32 trae mucho aire alrededor).
const COMPANION_ICONS: Dictionary = {
	"chicken": {"sheet": "res://assets/sprites/Chicken/Idle/Chicken_front_Idle.png", "region": Rect2(6, 9, 20, 20)},
}

@onready var _background: TextureRect = $Background
@onready var _window: Panel = $Window
@onready var _title_label: Label = $Window/Title
@onready var _tab_buttons: Dictionary = {
	Tab.UPGRADES: $Window/Body/TopRow/Tabs/UpgradesTab,
	Tab.POWERS: $Window/Body/TopRow/Tabs/PowersTab,
	Tab.COMPANIONS: $Window/Body/TopRow/Tabs/CompanionsTab,
}
@onready var _currency_box: PanelContainer = $Window/Body/TopRow/CurrencyBox
@onready var _coin_icon: TextureRect = $Window/Body/TopRow/CurrencyBox/Row/CoinIcon
@onready var _currency_label: Label = $Window/Body/TopRow/CurrencyBox/Row/Currency
@onready var _hint_label: Label = $Window/Body/TabHint
@onready var _grid: GridContainer = $Window/Body/Scroll/Grid
@onready var _back_button: Button = $Window/Body/BackButton

var _tab: int = Tab.UPGRADES
var _coin: Texture2D
var _compact: bool = false
var _tab_font: int = 16

func _ready() -> void:
	_background.texture = load(BACKGROUND_TEXTURE)
	_coin = load(COIN_TEXTURE)
	_window.add_theme_stylebox_override("panel", RpgTheme.window_box())
	RpgTheme.style_light_label(_title_label, 26)
	_currency_box.add_theme_stylebox_override("panel", RpgTheme.slot_box(true, 8.0))
	_coin_icon.texture = _coin
	RpgTheme.style_light_label(_currency_label, 22)
	RpgTheme.style_ink_label(_hint_label, 14, false, true)
	RpgTheme.style_button(_back_button, 18)
	_back_button.pressed.connect(_on_back_pressed)
	for tab in _tab_buttons:
		var b: Button = _tab_buttons[tab]
		b.pressed.connect(_select_tab.bind(tab, true))
		b.mouse_entered.connect(func(): Audio.play_sfx("ui_hover"))
	Screen.layout_changed.connect(_apply_layout)
	_apply_layout(Screen.compact)
	_back_button.grab_focus()

## Teléfono: ventana a pantalla completa, pestañas repartidas a lo
## ancho, la moneda en su propia fila y tarjetas en una sola columna.
func _apply_layout(compact: bool) -> void:
	_compact = compact
	var vp := Screen.view_size()
	var w: float = minf(1120.0, vp.x - 16.0)
	var h: float = minf(680.0, vp.y - 24.0)
	_window.offset_left = -w / 2.0
	_window.offset_right = w / 2.0
	_window.offset_top = -h / 2.0
	_window.offset_bottom = h / 2.0
	var body: Control = $Window/Body
	body.offset_left = 18.0 if compact else 30.0
	body.offset_right = -18.0 if compact else -30.0

	var top_row: BoxContainer = $Window/Body/TopRow
	top_row.vertical = compact
	var tabs: HBoxContainer = $Window/Body/TopRow/Tabs
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL if compact else Control.SIZE_FILL
	_tab_font = 13 if compact else 16
	var widths: Dictionary = {Tab.UPGRADES: 180.0, Tab.POWERS: 180.0, Tab.COMPANIONS: 220.0}
	# "ACOMPAÑANTES" no entra en un tercio de pantalla de teléfono.
	_tab_buttons[Tab.COMPANIONS].text = "MASCOTAS" if compact else "ACOMPAÑANTES"
	for t in _tab_buttons:
		var b: Button = _tab_buttons[t]
		b.custom_minimum_size.x = 0.0 if compact else widths[t]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL if compact else Control.SIZE_FILL
	_currency_box.size_flags_horizontal = Control.SIZE_SHRINK_END if compact else Control.SIZE_FILL
	_grid.columns = 1 if compact else 2
	_select_tab(_tab, false)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()

func _select_tab(tab: int, sound: bool = true) -> void:
	if sound and tab != _tab:
		Audio.play_sfx("ui_click")
	_tab = tab
	for t in _tab_buttons:
		RpgTheme.style_tab(_tab_buttons[t], t == tab, _tab_font)
	_hint_label.text = TAB_HINTS[tab]
	_rebuild()

## Rearma todas las tarjetas de la pestaña actual — son pocas, así
## que después de cada compra es más simple rearmar que parchear.
func _rebuild() -> void:
	_currency_label.text = "%d" % GameState.total_currency
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	match _tab:
		Tab.UPGRADES: _build_upgrades()
		Tab.POWERS: _build_powers()
		Tab.COMPANIONS: _build_companions()

func _build_upgrades() -> void:
	for id in GameState.SHOP_ITEMS:
		var item: Dictionary = GameState.SHOP_ITEMS[id]
		var style: Dictionary = ITEM_STYLE.get(id, {"icon": "spark", "color": RpgTheme.COLOR_INK_GOOD})
		var card := _make_card(_pixel_icon(style), item["name"], item["desc"])
		var level: int = GameState.get_shop_level(id)

		var bar := ProgressBar.new()
		bar.max_value = item["max_level"]
		bar.value = level
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(100 if _compact else 140, 12)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		RpgTheme.style_level_bar(bar, style["color"])
		card["status"].add_child(bar)
		card["status"].add_child(_status_label("%d / %d" % [level, item["max_level"]], false))

		var button: Button = card["button"]
		if level >= item["max_level"]:
			_set_plain(button, "MÁXIMO", false)
		else:
			_set_price(button, GameState.get_shop_cost(id), GameState.can_afford(id))
		button.pressed.connect(_on_buy_upgrade.bind(id))

func _build_powers() -> void:
	for id in GameState.SHOP_POWERS:
		var power: Dictionary = GameState.SHOP_POWERS[id]
		var card := _make_card(_texture_icon(load(POWER_ICONS[id]), true), power["name"], power["desc"])
		var owned: bool = GameState.is_power_unlocked(id)
		card["status"].add_child(_status_label("DESBLOQUEADO" if owned else "BLOQUEADO", owned))
		var button: Button = card["button"]
		if owned:
			_set_plain(button, "COMPRADO", false)
		else:
			_set_price(button, power["cost"], GameState.total_currency >= power["cost"])
		button.pressed.connect(_on_buy_power.bind(id))

func _build_companions() -> void:
	for id in GameState.COMPANIONS:
		var comp: Dictionary = GameState.COMPANIONS[id]
		var icon_data: Dictionary = COMPANION_ICONS[id]
		var atlas := AtlasTexture.new()
		atlas.atlas = load(icon_data["sheet"])
		atlas.region = icon_data["region"]
		var card := _make_card(_texture_icon(atlas, false), comp["name"], comp["desc"])
		var owned: bool = GameState.owns_companion(id)
		var equipped: bool = GameState.equipped_companion == id
		var button: Button = card["button"]
		if equipped:
			card["status"].add_child(_status_label("EQUIPADO", true))
			_set_plain(button, "QUITAR", true)
		elif owned:
			card["status"].add_child(_status_label("EN RESERVA", false))
			_set_plain(button, "EQUIPAR", true)
		else:
			_set_price(button, comp["cost"], GameState.total_currency >= comp["cost"])
		button.pressed.connect(_on_companion_pressed.bind(id))

# ── Piezas de tarjeta ────────────────────────────────────────────

## Tarjeta: [insignia con ícono] [nombre / descripción / fila de estado] [botón]
func _make_card(icon: Control, title: String, desc: String) -> Dictionary:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", RpgTheme.slot_box(false, 12.0))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 0 if _compact else 108)
	_grid.add_child(card)

	# Compacto (teléfono): [insignia][nombre/desc] arriba y [estado][botón]
	# abajo — en una fila sola el texto quedaba de 80px de ancho.
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	card.add_child(outer)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12 if _compact else 14)
	outer.add_child(hbox)

	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", RpgTheme.slot_box(true, 6.0))
	badge.custom_minimum_size = Vector2(64, 64) if _compact else Vector2(76, 76)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(badge)
	badge.add_child(icon)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(info)

	var name_label := Label.new()
	name_label.text = title
	RpgTheme.style_ink_label(name_label, 19, true)
	info.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = desc
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	RpgTheme.style_ink_label(desc_label, 13, false, true)
	info.add_child(desc_label)

	var status := HBoxContainer.new()
	status.add_theme_constant_override("separation", 10)
	var button := Button.new()
	button.custom_minimum_size = Vector2(160, 54) if not _compact else Vector2(150, 46)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	RpgTheme.style_button(button, 15)
	button.mouse_entered.connect(func(): Audio.play_sfx("ui_hover"))
	if _compact:
		var bottom := HBoxContainer.new()
		outer.add_child(bottom)
		status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bottom.add_child(status)
		bottom.add_child(button)
	else:
		info.add_child(status)
		hbox.add_child(button)

	return {"status": status, "button": button}

func _pixel_icon(style: Dictionary) -> Control:
	# Sin tipo explícito: el script se pega en runtime (ver pixel_icon.gd)
	# y tiparlo como Control rompe al asignarle icon_id/color.
	var icon = Control.new()
	icon.set_script(PixelIconScript)
	icon.custom_minimum_size = Vector2(PixelIconScript.BOX, PixelIconScript.BOX)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.icon_id = style["icon"]
	icon.color = style["color"]
	return icon

## smooth: los skill_icons son ilustraciones de 256px achicadas — con
## filtro nearest (el default del proyecto) quedan con serrucho.
func _texture_icon(tex: Texture2D, smooth: bool) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(62, 62)
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if smooth else CanvasItem.TEXTURE_FILTER_NEAREST
	return rect

func _status_label(text: String, good: bool) -> Label:
	var label := Label.new()
	label.text = text
	RpgTheme.style_ink_label(label, 13, good, not good)
	if good:
		label.add_theme_color_override("font_color", RpgTheme.COLOR_INK_GOOD)
	return label

func _set_price(button: Button, cost: int, affordable: bool) -> void:
	button.text = "COMPRAR %d" % cost
	button.icon = _coin
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	button.add_theme_constant_override("icon_max_width", 20)
	button.disabled = not affordable

func _set_plain(button: Button, text: String, enabled: bool) -> void:
	button.text = text
	button.icon = null
	button.disabled = not enabled

# ── Acciones ─────────────────────────────────────────────────────

func _on_buy_upgrade(id: String) -> void:
	if GameState.buy_shop_item(id):
		Audio.play_sfx("card_selected")
		_rebuild()

func _on_buy_power(id: String) -> void:
	if GameState.buy_power(id):
		Audio.play_sfx("card_selected")
		_rebuild()

func _on_companion_pressed(id: String) -> void:
	if GameState.owns_companion(id):
		GameState.toggle_companion(id)
		Audio.play_sfx("ui_click")
	elif GameState.buy_companion(id):
		Audio.play_sfx("card_selected")
	_rebuild()

func _on_back_pressed() -> void:
	# La tienda es accesible desde el menú principal Y desde la barra
	# superior de selección de personaje — vuelve a la que corresponda.
	get_tree().change_scene_to_file(GameState.shop_return_scene)
