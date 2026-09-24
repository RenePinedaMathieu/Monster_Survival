extends Control

## Elegir mapa y dificultad antes de arrancar (después de confirmar el
## héroe). Los mapas y dificultades bloqueados muestran qué logro los
## abre (GameState.MAPS / DIFFICULTIES).

const RpgTheme := preload("res://scenes/rpg_theme.gd")
const BACKGROUND_TEXTURE := "res://assets/layouts/background_home.png"
const GAME_SCENE := "res://scenes/main.tscn"
const CONFIRM_SCENE := "res://scenes/character_confirm.tscn"
## Recorte del tileset que se usa de miniatura del mapa (pasto + laguna).
const PREVIEW_REGION := Rect2(0, 56, 96, 64)

@onready var _window: PanelContainer = $Center/Window
@onready var _title: Label = $Center/Window/VBox/Title
@onready var _maps: GridContainer = $Center/Window/VBox/Maps
@onready var _diff_label: Label = $Center/Window/VBox/DiffLabel
@onready var _diffs: HBoxContainer = $Center/Window/VBox/Diffs
@onready var _info: Label = $Center/Window/VBox/Info
@onready var _back_button: Button = $Center/Window/VBox/Buttons/BackButton
@onready var _play_button: Button = $Center/Window/VBox/Buttons/PlayButton

var _map_buttons: Dictionary = {}
var _diff_buttons: Dictionary = {}
var _card_styles: Dictionary = {}

func _ready() -> void:
	$Background.texture = load(BACKGROUND_TEXTURE)
	_window.add_theme_stylebox_override("panel", RpgTheme.window_box_titled(26.0, 22.0))
	RpgTheme.style_header_title(_title, 24)
	RpgTheme.style_ink_label(_diff_label, 16, true)
	RpgTheme.style_ink_label(_info, 14, false, true)
	RpgTheme.style_button(_back_button, 18)
	RpgTheme.style_button(_play_button, 20)
	_back_button.pressed.connect(func(): get_tree().change_scene_to_file(CONFIRM_SCENE))
	_play_button.pressed.connect(_on_play)
	if not GameState.is_map_unlocked(GameState.selected_map):
		GameState.selected_map = "pradera"
	if not GameState.is_difficulty_unlocked(GameState.selected_difficulty):
		GameState.selected_difficulty = "normal"
	for id in GameState.MAP_ORDER:
		_maps.add_child(_map_card(id))
	for id in GameState.DIFFICULTY_ORDER:
		var b := Button.new()
		b.custom_minimum_size = Vector2(130, 44)
		b.pressed.connect(_select_difficulty.bind(id))
		_diffs.add_child(b)
		_diff_buttons[id] = b
	_refresh()
	_play_button.grab_focus()
	Screen.layout_changed.connect(_apply_layout)
	_apply_layout(Screen.compact)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(CONFIRM_SCENE)

func _apply_layout(compact: bool) -> void:
	_maps.columns = 1 if compact else 3
	var w: float = minf(1000.0, Screen.view_size().x - 20.0)
	_window.custom_minimum_size.x = w
	for id in _map_buttons:
		var card: Button = _map_buttons[id]
		card.custom_minimum_size = Vector2(0, 118) if compact else Vector2(290, 250)
		var box: BoxContainer = card.get_node("Box")
		box.vertical = not compact
	for id in _diff_buttons:
		_diff_buttons[id].custom_minimum_size.x = 0.0 if compact else 130.0
		_diff_buttons[id].size_flags_horizontal = Control.SIZE_EXPAND_FILL if compact else Control.SIZE_FILL

## Tarjeta de mapa: miniatura del tileset, nombre, descripción y
## multiplicador; bloqueada muestra el logro que la abre.
func _map_card(id: String) -> Button:
	var data: Dictionary = GameState.MAPS[id]
	var unlocked: bool = GameState.is_map_unlocked(id)
	var card := Button.new()
	RpgTheme.style_card_button(card, 14)
	# El elegido queda con el aro verde del hover (ver _refresh).
	_card_styles[id] = {"normal": card.get_theme_stylebox("normal"), "hover": card.get_theme_stylebox("hover")}
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.pressed.connect(_select_map.bind(id))
	var box := BoxContainer.new()
	box.name = "Box"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 12.0
	box.offset_top = 12.0
	box.offset_right = -12.0
	box.offset_bottom = -12.0
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	var thumb := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = load(data["tileset"])
	atlas.region = PREVIEW_REGION
	thumb.texture = atlas
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.custom_minimum_size = Vector2(140, 92)
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not unlocked:
		thumb.modulate = Color(0.25, 0.25, 0.28)
	box.add_child(thumb)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	box.add_child(col)
	var name_label := Label.new()
	name_label.text = data["name"].to_upper()
	RpgTheme.style_ink_label(name_label, 18, true)
	col.add_child(name_label)
	var desc := Label.new()
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.text = data["desc"] if unlocked else "BLOQUEADO: " + GameState.unlock_hint_for_map(id)
	RpgTheme.style_ink_label(desc, 13, not unlocked, unlocked)
	col.add_child(desc)
	var mult := Label.new()
	mult.text = "Enemigos y monedas x%.2f" % data["mult"]
	RpgTheme.style_ink_label(mult, 12, true)
	mult.add_theme_color_override("font_color", RpgTheme.COLOR_INK_GOOD)
	col.add_child(mult)
	_map_buttons[id] = card
	return card

func _select_map(id: String) -> void:
	if not GameState.is_map_unlocked(id):
		Audio.play_sfx("player_hurt")
		return
	Audio.play_sfx("ui_click")
	GameState.selected_map = id
	_refresh()

func _select_difficulty(id: String) -> void:
	if not GameState.is_difficulty_unlocked(id):
		Audio.play_sfx("player_hurt")
		return
	Audio.play_sfx("ui_click")
	GameState.selected_difficulty = id
	_refresh()

## Marca lo elegido: el mapa con aro verde (estilo hover fijo) y la
## dificultad como pestaña seleccionada.
func _refresh() -> void:
	for id in _map_buttons:
		var card: Button = _map_buttons[id]
		var styles: Dictionary = _card_styles[id]
		card.add_theme_stylebox_override("normal", styles["hover"] if id == GameState.selected_map else styles["normal"])
	for id in _diff_buttons:
		var b: Button = _diff_buttons[id]
		var data: Dictionary = GameState.DIFFICULTIES[id]
		var unlocked: bool = GameState.is_difficulty_unlocked(id)
		b.text = data["name"] if unlocked else data["name"] + " (bloq.)"
		RpgTheme.style_tab(b, id == GameState.selected_difficulty, 14)
		b.disabled = not unlocked
	var diff: Dictionary = GameState.difficulty_data()
	var map: Dictionary = GameState.map_data()
	var total: float = map["mult"] * diff["mult"]
	var coins: float = map["mult"] * diff["coins"]
	var locked_diffs: Array = []
	for id in GameState.DIFFICULTY_ORDER:
		if not GameState.is_difficulty_unlocked(id):
			var need: String = GameState.DIFFICULTIES[id]["unlock"]
			for a in GameState.ACHIEVEMENTS:
				if a["id"] == need:
					locked_diffs.append("%s: %s" % [GameState.DIFFICULTIES[id]["name"].capitalize(), a["desc"].to_lower()])
	_info.text = "%s en %s — enemigos x%.2f · monedas x%.2f" % [map["name"], diff["name"].capitalize(), total, coins]
	if not locked_diffs.is_empty():
		_info.text += "\n" + " · ".join(locked_diffs)

func _on_play() -> void:
	Audio.play_sfx("ui_click")
	get_tree().change_scene_to_file(GAME_SCENE)
