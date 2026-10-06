extends Control

## DESAFÍOS: partidas cortas con reglas fijas (GameState.TRIALS). A la
## izquierda la lista; a la derecha el elegido, con su mapa, sus reglas,
## el premio y con qué héroe jugarlo (cualquiera de los desbloqueados).
## El premio se da una sola vez: los héroes EDRIC y SIRA y las cartas de
## upgrades.gd LOCKED_CARDS se consiguen acá.

const RpgTheme := preload("res://scenes/rpg_theme.gd")
const SELECT_SCRIPT := preload("res://scenes/character_select.gd")
const BACKGROUND_TEXTURE := "res://assets/layouts/background_home.png"
const MENU_SCENE := "res://scenes/village.tscn"
const GAME_SCENE := "res://scenes/main.tscn"
const COLOR_RULE := Color("b8551e")

var _window: PanelContainer
var _main: BoxContainer
var _list: VBoxContainer
var _detail: VBoxContainer
var _play: Button
var _selected: String = ""
var _heroes: Array = []   # entradas de CHARACTERS desbloqueadas
var _hero_index: int = 0
var _list_buttons: Dictionary = {}

func _ready() -> void:
	var bg := TextureRect.new()
	bg.texture = load(BACKGROUND_TEXTURE)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_window = PanelContainer.new()
	_window.add_theme_stylebox_override("panel", RpgTheme.window_box_titled(26.0, 22.0))
	center.add_child(_window)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_window.add_child(vbox)
	var title := Label.new()
	title.text = "DESAFÍOS"
	RpgTheme.style_header_title(title, 24)
	vbox.add_child(title)
	_main = BoxContainer.new()
	_main.add_theme_constant_override("separation", 18)
	vbox.add_child(_main)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.custom_minimum_size.x = 300.0
	_main.add_child(_list)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 8)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main.add_child(_detail)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	vbox.add_child(buttons)
	var back := Button.new()
	back.text = "VOLVER"
	back.custom_minimum_size = Vector2(150, 52)
	RpgTheme.style_button(back, 18)
	back.pressed.connect(_on_back)
	buttons.add_child(back)
	_play = Button.new()
	_play.text = "JUGAR"
	_play.custom_minimum_size = Vector2(220, 52)
	RpgTheme.style_button(_play, 20)
	_play.pressed.connect(_on_play)
	buttons.add_child(_play)

	for c in SELECT_SCRIPT.CHARACTERS:
		if GameState.is_character_unlocked(c["id"]):
			_heroes.append(c)
			if c["id"] == GameState.selected_character_id:
				_hero_index = _heroes.size() - 1
	_build_list()
	# Arranca en el primer desafío sin superar.
	var first: String = GameState.TRIALS[0]["id"]
	for t in GameState.TRIALS:
		if not GameState.is_trial_cleared(t["id"]):
			first = t["id"]
			break
	_select(first)
	Screen.layout_changed.connect(_apply_layout)
	_apply_layout(Screen.compact)
	_play.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()

func _apply_layout(compact: bool) -> void:
	_main.vertical = compact
	_list.custom_minimum_size.x = 0.0 if compact else 300.0
	_window.custom_minimum_size.x = minf(940.0, Screen.view_size().x - 20.0)

func _label(parent: Node, text: String, size: int, bold: bool = false, soft: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	RpgTheme.style_ink_label(l, size, bold, soft)
	parent.add_child(l)
	return l

func _build_list() -> void:
	for t in GameState.TRIALS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 44)
		b.text = t["name"].to_upper() + ("   · SUPERADO" if GameState.is_trial_cleared(t["id"]) else "")
		b.pressed.connect(_select.bind(t["id"]))
		_list.add_child(b)
		_list_buttons[t["id"]] = b

func _select(id: String) -> void:
	_selected = id
	Audio.play_sfx("ui_click")
	for tid in _list_buttons:
		RpgTheme.style_tab(_list_buttons[tid], tid == id, 15)
	for c in _detail.get_children():
		c.queue_free()
	var t: Dictionary = GameState.trial_data(id)
	var map: Dictionary = GameState.MAPS[t["map"]]
	_label(_detail, t["name"].to_upper(), 20, true)
	_label(_detail, tr("MAPA: %s  ·  %d OLEADAS") % [tr(map["name"]).to_upper(), t["waves"]], 15, true, true)
	for mod in t["mods"]:
		var m: Dictionary = GameState.DAILY_MODIFIERS[mod]
		var rule := _label(_detail, m["name"].to_upper() + ": " + m["desc"], 15, true)
		rule.add_theme_color_override("font_color", COLOR_RULE)
	var cleared: bool = GameState.is_trial_cleared(id)
	var prize := _label(_detail, ("Premio conseguido: " if cleared else "Premio: ") + GameState.reward_text(t["reward"]), 15, true)
	if cleared:
		prize.add_theme_color_override("font_color", RpgTheme.COLOR_INK_GOOD)
	_label(_detail, "Se juega con el héroe que elijas. No cuenta para el ranking.", 13, false, true)
	_build_hero_row()

## "HÉROE: < GAROTH >" con su retrato chico — sólo los desbloqueados.
func _build_hero_row() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_detail.add_child(row)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", RpgTheme.slot_box(true, 4.0))
	row.add_child(frame)
	var hero: Dictionary = _heroes[_hero_index]
	var portrait := TextureRect.new()
	portrait.texture = SELECT_SCRIPT.portrait_texture(hero)
	portrait.custom_minimum_size = Vector2(64, 80)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.add_child(portrait)
	var prev := Button.new()
	prev.text = "<"
	prev.custom_minimum_size = Vector2(44, 44)
	prev.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	RpgTheme.style_button(prev, 18)
	prev.pressed.connect(_cycle_hero.bind(-1))
	row.add_child(prev)
	var name_label := _label(row, tr("HÉROE: ") + hero["name"], 17, true)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var next := Button.new()
	next.text = ">"
	next.custom_minimum_size = Vector2(44, 44)
	next.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	RpgTheme.style_button(next, 18)
	next.pressed.connect(_cycle_hero.bind(1))
	row.add_child(next)
	prev.disabled = _heroes.size() < 2
	next.disabled = _heroes.size() < 2

func _cycle_hero(step: int) -> void:
	_hero_index = (_hero_index + step + _heroes.size()) % _heroes.size()
	_select(_selected)

func _on_back() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)

func _on_play() -> void:
	var t: Dictionary = GameState.trial_data(_selected)
	var hero: Dictionary = _heroes[_hero_index]
	GameState.trial_active = _selected
	GameState.daily_active = false
	GameState.selected_character_id = hero["id"]
	GameState.pending_character = hero
	GameState.selected_map = t["map"]
	GameState.selected_difficulty = "normal"
	Audio.play_sfx("ui_click")
	get_tree().change_scene_to_file(GAME_SCENE)
