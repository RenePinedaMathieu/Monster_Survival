extends Control

## Reto diario: el mismo héroe, mapa y modificador para todos durante
## el día (GameState.daily_info), 10 oleadas y un ranking con los
## mejores puntajes de hoy (tabla "runs" de Supabase). El héroe y el
## mapa del día se pueden jugar aunque todavía estén bloqueados — sirve
## de adelanto de lo que se desbloquea.

const RpgTheme := preload("res://scenes/rpg_theme.gd")
const SELECT_SCRIPT := preload("res://scenes/character_select.gd")
const NamePrompt := preload("res://scenes/name_prompt.gd")
const BACKGROUND_TEXTURE := "res://assets/layouts/background_home.png"
const MENU_SCENE := "res://scenes/main_menu.tscn"
const GAME_SCENE := "res://scenes/main.tscn"
const TOP := 10

@onready var _window: PanelContainer = $Center/Window
@onready var _title: Label = $Center/Window/VBox/Title
@onready var _main: BoxContainer = $Center/Window/VBox/Main
@onready var _challenge: VBoxContainer = $Center/Window/VBox/Main/Challenge
@onready var _board: VBoxContainer = $Center/Window/VBox/Main/Board
@onready var _back_button: Button = $Center/Window/VBox/Buttons/BackButton
@onready var _play_button: Button = $Center/Window/VBox/Buttons/PlayButton

var _info: Dictionary = {}
var _hero: Dictionary = {}
var _name_edit: LineEdit
var _board_status: Label

func _ready() -> void:
	$Background.texture = load(BACKGROUND_TEXTURE)
	_info = GameState.daily_info()
	for c in SELECT_SCRIPT.CHARACTERS:
		if c["id"] == _info["hero"]:
			_hero = c
	_window.add_theme_stylebox_override("panel", RpgTheme.window_box_titled(26.0, 22.0))
	RpgTheme.style_header_title(_title, 24)
	_title.text = "RETO DIARIO · " + _info["date"]
	RpgTheme.style_button(_back_button, 18)
	RpgTheme.style_button(_play_button, 20)
	_back_button.pressed.connect(func(): get_tree().change_scene_to_file(MENU_SCENE))
	_play_button.pressed.connect(_on_play)
	_build_challenge()
	_build_board()
	Screen.layout_changed.connect(_apply_layout)
	_apply_layout(Screen.compact)
	_play_button.grab_focus()
	# Con la sesión guardada se sabe tu user_id y se marca tu fila.
	if FileAccess.file_exists(Supabase.SESSION_PATH):
		Supabase.ensure_session(GameState.ensure_player_name())
	_fetch_board()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(MENU_SCENE)

func _apply_layout(compact: bool) -> void:
	_main.vertical = compact
	_window.custom_minimum_size.x = minf(900.0, Screen.view_size().x - 20.0)

func _label(parent: Node, text: String, size: int, bold: bool = false, soft: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	RpgTheme.style_ink_label(l, size, bold, soft)
	parent.add_child(l)
	return l

func _build_challenge() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_challenge.add_child(row)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", RpgTheme.slot_box(true, 6.0))
	row.add_child(frame)
	var portrait := TextureRect.new()
	portrait.texture = SELECT_SCRIPT.portrait_texture(_hero)
	portrait.custom_minimum_size = Vector2(110, 140)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.add_child(portrait)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	row.add_child(col)
	var map: Dictionary = GameState.MAPS[_info["map"]]
	var mod: Dictionary = GameState.DAILY_MODIFIERS[_info["modifier"]]
	_label(col, "HÉROE: " + _hero.get("name", "?"), 17, true)
	_label(col, "MAPA: " + map["name"].to_upper(), 17, true)
	_label(col, "%d OLEADAS" % GameState.DAILY_WAVES, 15, true, true)
	var mod_label := _label(col, mod["name"].to_upper() + ": " + mod["desc"], 15, true)
	mod_label.add_theme_color_override("font_color", Color("b8551e"))
	var best: int = int(GameState.daily_best.get(_info["date"], 0))
	_label(_challenge, "Tu mejor puntaje de hoy: %s" % (str(best) if best > 0 else "—"), 15, true)
	_label(_challenge, "Todos juegan lo mismo hoy. Mañana cambia.", 13, false, true)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	_challenge.add_child(name_row)
	var name_label := _label(name_row, "Tu nombre:", 15, true)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_name_edit = LineEdit.new()
	_name_edit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_name_edit.custom_minimum_size.y = 38.0
	_name_edit.text = GameState.ensure_player_name()
	_name_edit.max_length = 16
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.add_theme_stylebox_override("normal", RpgTheme.slot_box(false, 6.0))
	_name_edit.add_theme_stylebox_override("focus", RpgTheme.slot_box(false, 6.0))
	_name_edit.add_theme_color_override("font_color", RpgTheme.COLOR_INK)
	_name_edit.text_submitted.connect(func(t): GameState.set_player_name(t))
	_name_edit.focus_exited.connect(func(): GameState.set_player_name(_name_edit.text))
	NamePrompt.attach(_name_edit)
	name_row.add_child(_name_edit)

func _build_board() -> void:
	_label(_board, "RANKING DE HOY", 17, true)
	_board_status = _label(_board, "Cargando...", 14, false, true)

## Top de hoy: se piden los mejores 50 y se deja el mejor de cada
## jugador (una misma persona puede haber jugado varias veces).
func _fetch_board() -> void:
	var path := "/runs?select=player_name,hero,score,wave,victory,user_id&daily_date=eq.%s&order=score.desc&limit=50" % _info["date"]
	Supabase.rest_get(path, _on_board)

func _on_board(code: int, body: String) -> void:
	if not is_inside_tree():
		return
	if code < 200 or code >= 300:
		_board_status.text = "El ranking todavía no está activado." if code == 404 \
			else "No se pudo cargar el ranking. Revisa tu conexión."
		return
	var rows = JSON.parse_string(body)
	if typeof(rows) != TYPE_ARRAY or rows.is_empty():
		_board_status.text = "Nadie jugó hoy todavía: ¡sé el primero!"
		return
	_board_status.queue_free()
	var seen := {}
	var place := 0
	for r in rows:
		var who: String = str(r.get("user_id", r.get("player_name", "")))
		if seen.has(who):
			continue
		seen[who] = true
		place += 1
		var l := _label(_board, "%d. %s — %d  (oleada %d%s)" % [place, r.get("player_name", "?"), int(r.get("score", 0)),
			int(r.get("wave", 0)), ", ganó" if r.get("victory", false) else ""], 14, place <= 3)
		if who == Supabase.user_id:
			l.add_theme_color_override("font_color", RpgTheme.COLOR_INK_GOOD)
		if place >= TOP:
			break

func _on_play() -> void:
	GameState.set_player_name(_name_edit.text)
	GameState.daily_active = true
	GameState.selected_character_id = _info["hero"]
	GameState.pending_character = _hero
	GameState.selected_map = _info["map"]
	GameState.selected_difficulty = "normal"
	Audio.play_sfx("ui_click")
	get_tree().change_scene_to_file(GAME_SCENE)
