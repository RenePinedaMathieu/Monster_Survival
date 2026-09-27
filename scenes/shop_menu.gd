extends Control

## Tienda — todo se compra con la moneda banqueada de runs anteriores
## (GameState.total_currency). Tres pestañas:
##   MEJORAS       árbol de habilidades permanentes en 3 ramas
##                 (GameState.SKILL_TREE); player.gd aplica los bonos
##                 al arrancar cada run.
##   PODERES       compra única que habilita que la carta del poder
##                 salga en los level-ups (GameState.SHOP_POWERS).
##   ACOMPAÑANTES  animales que te siguen y ayudan (GameState.COMPANIONS):
##                 se compran y se mejoran hasta el nivel 5, y las crías
##                 crecen. Se llevan tantos como espacios haya.
##
## Las tarjetas se arman por código desde los dicts de GameState, así
## sumar un ítem es tocar game_state.gd + su ícono acá. Estilo del pack
## pergamino/verde, ver rpg_theme.gd.

const RpgTheme := preload("res://scenes/rpg_theme.gd")
const BACKGROUND_TEXTURE := "res://assets/layouts/background_home.png"
const COIN_TEXTURE := "res://assets/ui/rpg/coin.png"

enum Tab { UPGRADES, POWERS, COMPANIONS }

const TAB_HINTS: Dictionary = {
	Tab.UPGRADES: "Árbol de habilidades permanentes: cada rama se abre mejorando el nodo anterior.",
	Tab.POWERS: "Compra única: el poder empieza a salir como carta al subir de nivel durante las oleadas.",
	Tab.COMPANIONS: "Te acompañan en cada partida. Mejóralos para que crezcan y se vuelvan más fuertes.",
}

## Mismos íconos que las cartas de level-up que desbloquean.
const POWER_ICONS: Dictionary = {
	"meteors": "res://assets/ui/skill_icons/skill_22.png",
	"flying_swords": "res://assets/ui/skill_icons/skill_5.png",
	"aura": "res://assets/ui/skill_icons/skill_23.png",
	"hacha": "res://assets/ui/skill_icons/skill_25.png",
	"rayo": "res://assets/ui/skill_icons/skill_70.png",
}
const CompanionScript := preload("res://scenes/companion.gd")

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
	# En vertical sobra altura: más tarjetas a la vista.
	var h: float = minf(1000.0 if vp.y > vp.x * 1.2 else 680.0, vp.y - 24.0)
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
	# El árbol usa una columna por rama; las otras pestañas, 2 tarjetas
	# por fila (1 en teléfono).
	if _tab == Tab.UPGRADES:
		_grid.columns = 1 if _compact else GameState.SKILL_BRANCHES.size()
	else:
		_grid.columns = 1 if _compact else 2
	match _tab:
		Tab.UPGRADES: _build_upgrades()
		Tab.POWERS: _build_powers()
		Tab.COMPANIONS: _build_companions()

## Árbol de habilidades: una columna por rama (ATAQUE / DEFENSA /
## UTILIDAD) con sus nodos en orden, unidos por un conector que se
## pinta del color de la rama cuando el siguiente ya está disponible.
func _build_upgrades() -> void:
	for branch in GameState.SKILL_BRANCHES:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_grid.add_child(col)
		var header := Label.new()
		header.text = branch["name"]
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		RpgTheme.style_ink_label(header, 17, true)
		header.add_theme_color_override("font_color", Color(branch["color"]).darkened(0.25))
		col.add_child(header)
		var ids: Array = GameState.SKILL_TREE.keys().filter(
			func(k): return GameState.SKILL_TREE[k]["branch"] == branch["id"])
		ids.sort_custom(func(a, b): return GameState.SKILL_TREE[a]["tier"] < GameState.SKILL_TREE[b]["tier"])
		for i in range(ids.size()):
			if i > 0:
				col.add_child(_connector(GameState.is_skill_available(ids[i]), branch["color"]))
			col.add_child(_skill_node(ids[i], branch["color"]))

func _connector(active: bool, color: Color) -> Control:
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(0, 14)
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(6, 14)
	line.color = color if active else Color("70492a")
	holder.add_child(line)
	return holder

func _skill_node(id: String, color: Color) -> Control:
	var item: Dictionary = GameState.SKILL_TREE[id]
	var level: int = GameState.get_shop_level(id)
	var available: bool = GameState.is_skill_available(id)
	var legend: String = item.get("legend", "")
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", RpgTheme.slot_box(false, 10.0))
	if not available:
		card.modulate = Color(0.75, 0.72, 0.7)
	elif legend != "":
		card.self_modulate = Color(1.15, 1.02, 0.7)   # legendaria: tinte dorado
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	vbox.add_child(top)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", RpgTheme.slot_box(true, 4.0))
	badge.custom_minimum_size = Vector2(52, 52)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(badge)
	var path: String = item["icon"]
	var icon := _texture_icon(load(path), not path.contains("/rpg/"))
	icon.custom_minimum_size = Vector2(42, 42)
	badge.add_child(icon)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(info)
	var name_label := Label.new()
	name_label.text = item["name"] + ("  (LEGENDARIA)" if legend != "" else "")
	RpgTheme.style_ink_label(name_label, 16, true)
	if legend != "":
		name_label.add_theme_color_override("font_color", Color("9a6a10"))
	info.add_child(name_label)
	var desc := Label.new()
	desc.text = item["desc"]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	RpgTheme.style_ink_label(desc, 12, false, true)
	info.add_child(desc)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	vbox.add_child(bottom)
	var bar := ProgressBar.new()
	bar.max_value = item["max_level"]
	bar.value = level
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(60, 12)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	RpgTheme.style_level_bar(bar, color)
	bottom.add_child(bar)
	bottom.add_child(_status_label("%d/%d" % [level, item["max_level"]], false))
	var button := Button.new()
	button.custom_minimum_size = Vector2(128, 40)
	RpgTheme.style_button(button, 13)
	button.mouse_entered.connect(func(): Audio.play_sfx("ui_hover"))
	bottom.add_child(button)
	if level >= item["max_level"]:
		_set_plain(button, "MÁXIMO", false)
	elif not available:
		_set_plain(button, "BLOQUEADO", false)
		var req_label := Label.new()
		if legend != "":
			req_label.text = "Supera la oleada %d en %s" % [GameState.CHALLENGE_WAVE, GameState.MAP_NAMES.get(legend, legend)]
		else:
			var req: Dictionary = GameState.SKILL_TREE[item["requires"]]
			req_label.text = "Requiere %s nivel %d" % [req["name"], item["req_level"]]
		RpgTheme.style_ink_label(req_label, 12, true)
		info.add_child(req_label)
	else:
		_set_price(button, GameState.get_shop_cost(id), GameState.can_afford(id))
		button.text = str(GameState.get_shop_cost(id))
	button.pressed.connect(_on_buy_upgrade.bind(id))
	return card

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

## Una tarjeta por línea: forma actual, nivel, qué hace ahora y en el
## próximo nivel, cuándo crece; botón de comprar/mejorar y de equipar.
func _build_companions() -> void:
	var slots := GameState.companion_slots()
	var names: Array = []
	for id in GameState.active_companions():
		names.append(GameState.companion_stage(id)[2])
	_hint_label.text = TAB_HINTS[Tab.COMPANIONS] + "  Llevas %d de %d: %s." % [names.size(), slots,
		", ".join(names) if not names.is_empty() else "ninguno"]
	for id in GameState.COMPANIONS:
		var comp: Dictionary = GameState.COMPANIONS[id]
		var lvl: int = GameState.companion_level(id)
		var owned: bool = lvl > 0
		var stage: Array = GameState.companion_stage(id)
		var form: String = stage[1]
		var atlas := AtlasTexture.new()
		atlas.atlas = load("res://assets/companions/%s/idle_front.png" % form)
		var fsize: Vector2 = CompanionScript.SPRITES[form]["frame"]
		atlas.region = Rect2(Vector2.ZERO, fsize)
		var title: String = stage[2] + ("  ·  Nv %d/%d" % [lvl, GameState.COMPANION_MAX_LEVEL] if owned else "")
		var lines: Array = [comp["role"] + "."]
		lines.append(("Ahora: " if owned else "Nivel 1: ") + CompanionScript.describe(id, maxi(1, lvl)))
		if owned and lvl < GameState.COMPANION_MAX_LEVEL:
			lines.append("Próximo: " + CompanionScript.describe(id, lvl + 1))
		var next_stage: Array = GameState.companion_next_stage(id)
		if not next_stage.is_empty():
			lines.append("Crece a %s en el nivel %d." % [next_stage[2], next_stage[0]])
		var card := _make_card(_texture_icon(atlas, false), title, "
".join(lines))
		if not owned:
			card["card"].modulate = Color(0.82, 0.8, 0.78)
		var bar := ProgressBar.new()
		bar.max_value = GameState.COMPANION_MAX_LEVEL
		bar.value = lvl
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(70, 12)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		RpgTheme.style_level_bar(bar, Color("44a13b"))
		card["status"].add_child(bar)
		var equipped: bool = id in GameState.active_companions()
		if owned:
			card["status"].add_child(_status_label("EQUIPADO" if equipped else "EN RESERVA", equipped))
		var button: Button = card["button"]
		var cost: int = GameState.companion_next_cost(id)
		if cost < 0:
			_set_plain(button, "MÁXIMO", false)
		else:
			_set_price(button, cost, GameState.total_currency >= cost)
			if owned:
				button.text = "MEJORAR %d" % cost
		button.pressed.connect(_on_companion_upgrade.bind(id))
		# Segundo botón (equipar) debajo del de comprar/mejorar.
		var equip := Button.new()
		equip.custom_minimum_size = Vector2(button.custom_minimum_size.x, 38)
		RpgTheme.style_button(equip, 14)
		_set_plain(equip, "QUITAR" if equipped else "EQUIPAR", owned)
		equip.visible = owned
		equip.pressed.connect(_on_companion_equip.bind(id))
		var holder := button.get_parent()
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", 6)
		stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		holder.add_child(stack)
		holder.move_child(stack, button.get_index())
		holder.remove_child(button)
		stack.add_child(button)
		stack.add_child(equip)

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

	return {"status": status, "button": button, "card": card}

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

func _on_companion_upgrade(id: String) -> void:
	if GameState.upgrade_companion(id):
		Audio.play_sfx("card_selected")
		_rebuild()

func _on_companion_equip(id: String) -> void:
	GameState.toggle_companion(id)
	Audio.play_sfx("ui_click")
	_rebuild()

func _on_back_pressed() -> void:
	# La tienda es accesible desde el menú principal Y desde la barra
	# superior de selección de personaje — vuelve a la que corresponda.
	get_tree().change_scene_to_file(GameState.shop_return_scene)
