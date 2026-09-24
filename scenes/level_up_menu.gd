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
const RpgTheme := preload("res://scenes/rpg_theme.gd")

signal upgrade_chosen(id: String)

const Upgrades := preload("res://scenes/upgrades.gd")

## Las cartas, sus íconos y las reglas de qué puede salir (casillas de
## armas/pasivas, niveles máximos, poderes de la tienda) viven en
## upgrades.gd — este menú sólo arma las 3 opciones y las muestra.

var _player: Node = null
var _current_choices: Array = []

func _ready() -> void:
	add_to_group("modal")
	$Center/Window.add_theme_stylebox_override("panel", RpgTheme.window_box_titled(28.0, 26.0))
	RpgTheme.style_header_title($Center/Window/VBox/Title, 24)
	for card in _cards():
		RpgTheme.style_card_button(card, 16)
		card.text = ""
		_build_card_content(card)
		card.mouse_entered.connect(UITheme.pulse.bind(card, 1.04, 0.08))
		card.mouse_exited.connect(UITheme.pulse.bind(card, 1.0, 0.08))
	for i in range(3):
		_cards()[i].pressed.connect(_pick.bind(i))
	Screen.layout_changed.connect(_apply_layout)
	_apply_layout(Screen.compact)

## El botón sólo pone el fondo/hover/click; el contenido es un layout
## propio (ícono + título + descripción). Con el ícono y el texto del
## propio Button, un texto largo se montaba encima del ícono.
func _build_card_content(card: Button) -> void:
	var box := BoxContainer.new()
	box.name = "Content"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 14.0
	box.offset_top = 14.0
	box.offset_right = -14.0
	box.offset_bottom = -14.0
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Los skill_icons son ilustraciones de 256px achicadas — con el
	# filtro nearest del proyecto quedan con serrucho.
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	box.add_child(icon)

	var text := VBoxContainer.new()
	text.name = "Text"
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 4)
	box.add_child(text)

	var title := Label.new()
	title.name = "Title"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	RpgTheme.style_ink_label(title, 16, true)
	text.add_child(title)

	var desc := Label.new()
	desc.name = "Desc"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	RpgTheme.style_ink_label(desc, 14, false, true)
	text.add_child(desc)

## Teléfono: las 3 cartas apiladas, cada una con el ícono a la
## izquierda y el texto al lado. PC: 3 cartas en fila, ícono arriba.
func _apply_layout(compact: bool) -> void:
	var vp := Screen.view_size()
	($Center/Window/VBox/HBox as BoxContainer).vertical = compact
	for card in _cards():
		var b: Button = card
		var box: BoxContainer = b.get_node("Content")
		var icon: TextureRect = box.get_node("Icon")
		var text: VBoxContainer = box.get_node("Text")
		box.vertical = not compact
		box.alignment = BoxContainer.ALIGNMENT_BEGIN if compact else BoxContainer.ALIGNMENT_CENTER
		text.alignment = BoxContainer.ALIGNMENT_CENTER
		var align := HORIZONTAL_ALIGNMENT_LEFT if compact else HORIZONTAL_ALIGNMENT_CENTER
		for l in [text.get_node("Title"), text.get_node("Desc")]:
			(l as Label).horizontal_alignment = align
		if compact:
			b.custom_minimum_size = Vector2(vp.x - 90.0, 110.0)
			icon.custom_minimum_size = Vector2(64, 64)
			icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			text.size_flags_vertical = Control.SIZE_EXPAND_FILL
		else:
			b.custom_minimum_size = Vector2(260.0, 250.0)
			icon.custom_minimum_size = Vector2(84, 84)
			icon.size_flags_vertical = Control.SIZE_FILL
			text.size_flags_vertical = Control.SIZE_EXPAND_FILL

func _cards() -> Array:
	return [
		$Center/Window/VBox/HBox/Card1,
		$Center/Window/VBox/HBox/Card2,
		$Center/Window/VBox/HBox/Card3,
	]

func show_for(player: Node) -> void:
	_player = player
	_current_choices = _random_three()
	var cards := _cards()
	for i in range(3):
		var u = _current_choices[i]
		var text: Node = cards[i].get_node("Content/Text")
		text.get_node("Title").text = _title_for(u)
		text.get_node("Desc").text = Upgrades.desc_for(_player, u["id"])
		var icon: TextureRect = cards[i].get_node("Content/Icon")
		icon.texture = load(u["icon"]) if u.has("icon") and ResourceLoader.exists(u["icon"]) else null
	Audio.play_sfx("level_up")
	get_tree().paused = true

func _pick(idx: int) -> void:
	var u = _current_choices[idx]
	if _player and _player.has_method("apply_upgrade"):
		_player.apply_upgrade(u.id)
	Audio.play_sfx("card_selected")
	emit_signal("upgrade_chosen", u.id)
	remove_from_group("modal")
	# Si justo quedó abierto otro modal (un cofre), la pausa sigue.
	if get_tree().get_nodes_in_group("modal").is_empty():
		get_tree().paused = false
	queue_free()

## Arma las 3 opciones:
##   1. Sólo cartas que hoy harían algo (upgrades.gd is_eligible: tope
##      de nivel, casillas libres, poderes comprados en la tienda).
##   2. Si hay un arma para desbloquear todavía no tomada, GARANTIZA
##      que aparezca una entre las 3 — si no, se podía pasar la run
##      entera sin ver "espadas"/"meteoritos" por mala suerte.
##   3. El resto al azar; si no alcanzan (todo al máximo), relleno con
##      monedas / poción.
func _random_three() -> Array:
	var eligible: Array = Upgrades.CARDS.filter(
		func(c): return _player == null or Upgrades.is_eligible(_player, c["id"])
	)
	var chosen: Array = []
	var unlocks: Array = eligible.filter(func(c): return c["id"] in Upgrades.UNLOCK_IDS)
	if not unlocks.is_empty():
		var forced = unlocks[randi() % unlocks.size()]
		chosen.append(forced)
		eligible.erase(forced)
	eligible.shuffle()
	for c in eligible:
		if chosen.size() >= 3:
			break
		chosen.append(c)
	for filler in ["coins", "heal"]:
		if chosen.size() < 3:
			chosen.append(Upgrades.card(filler))
	while chosen.size() < 3:
		chosen.append(Upgrades.card("coins"))
	chosen.shuffle()   # que la carta forzada no quede siempre en Card1
	return chosen

func _title_for(u: Dictionary) -> String:
	return Upgrades.title_for(_player, u["id"])
