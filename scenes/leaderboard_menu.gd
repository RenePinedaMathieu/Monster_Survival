extends Control

## RANKING (menú principal). Dos pestañas sobre la tabla "runs" de
## Supabase (docs/supabase_runs.sql):
##   - RETO DE HOY: partidas del reto diario de hoy (daily_date = hoy).
##   - HISTÓRICO: todas las partidas normales (daily_date null); el
##     puntaje ya viene multiplicado por mapa y dificultad
##     (GameState.submit_run), así jugar difícil sube más.
## Se muestra el mejor puntaje de cada jugador (user_id), tu puesto y
## se puede cambiar el nombre con el que apareces.

const RpgTheme := preload("res://scenes/rpg_theme.gd")
const SELECT_SCRIPT := preload("res://scenes/character_select.gd")
const NamePrompt := preload("res://scenes/name_prompt.gd")
const BACKGROUND_TEXTURE := "res://assets/layouts/background_home.png"
const MENU_SCENE := "res://scenes/main_menu.tscn"
const DAILY_SCENE := "res://scenes/daily_menu.tscn"
const TOP := 25
const FETCH_LIMIT := 200
const COLOR_GOLD := Color("b8860b")

enum Tab { DAILY, ALL_TIME }

const HINTS := {
	Tab.DAILY: "Todos juegan el mismo héroe, mapa y modificador hoy. Mañana se reinicia.",
	Tab.ALL_TIME: "Partidas normales de siempre. Mapas y dificultades más duras multiplican el puntaje.",
}

@onready var _window: Panel = $Window
@onready var _title: Label = $Window/Title
@onready var _body: VBoxContainer = $Window/Body
@onready var _daily_tab: Button = $Window/Body/Tabs/DailyTab
@onready var _all_tab: Button = $Window/Body/Tabs/AllTimeTab
@onready var _hint: Label = $Window/Body/Hint
@onready var _list: VBoxContainer = $Window/Body/Scroll/List
@onready var _mine: Label = $Window/Body/Mine
@onready var _name_label: Label = $Window/Body/NameRow/NameLabel
@onready var _name_edit: LineEdit = $Window/Body/NameRow/NameEdit
@onready var _back_button: Button = $Window/Body/Buttons/BackButton
@onready var _daily_button: Button = $Window/Body/Buttons/DailyButton

var _tab: int = Tab.DAILY
var _compact: bool = false
## Filas ya bajadas por pestaña (se rearma al llegar la sesión para
## marcar las tuyas sin volver a pedirlas).
var _rows: Dictionary = {}
var _errors: Dictionary = {}
var _hero_names: Dictionary = {}

func _ready() -> void:
	$Background.texture = load(BACKGROUND_TEXTURE)
	for c in SELECT_SCRIPT.CHARACTERS:
		_hero_names[c["id"]] = String(c.get("name", c["id"])).capitalize()
	_window.add_theme_stylebox_override("panel", RpgTheme.window_box())
	RpgTheme.style_light_label(_title, 26)
	RpgTheme.style_ink_label(_hint, 14, false, true)
	RpgTheme.style_ink_label(_mine, 15, true)
	_mine.add_theme_color_override("font_color", RpgTheme.COLOR_INK_GOOD)
	RpgTheme.style_ink_label(_name_label, 15, true)
	_name_edit.text = GameState.ensure_player_name()
	_name_edit.add_theme_stylebox_override("normal", RpgTheme.slot_box(false, 6.0))
	_name_edit.add_theme_stylebox_override("focus", RpgTheme.slot_box(false, 6.0))
	_name_edit.add_theme_color_override("font_color", RpgTheme.COLOR_INK)
	_name_edit.text_submitted.connect(func(t): GameState.set_player_name(t))
	_name_edit.focus_exited.connect(func(): GameState.set_player_name(_name_edit.text))
	NamePrompt.attach(_name_edit)
	# Con el nombre nuevo ya guardado en tus partidas, se vuelve a pedir
	# el ranking para verlo.
	GameState.player_renamed.connect(_on_renamed)
	RpgTheme.style_button(_back_button, 17)
	RpgTheme.style_button(_daily_button, 17)
	_back_button.pressed.connect(_on_back)
	_daily_button.pressed.connect(func():
		Audio.play_sfx("ui_click")
		_save_name()
		get_tree().change_scene_to_file(DAILY_SCENE))
	_daily_tab.pressed.connect(_select_tab.bind(Tab.DAILY))
	_all_tab.pressed.connect(_select_tab.bind(Tab.ALL_TIME))
	# La sesión (si ya jugaste) dice cuál es tu user_id para marcar tus
	# filas; sin sesión igual se puede leer el ranking con la anon key.
	Supabase.auth_ready.connect(_render)
	if FileAccess.file_exists(Supabase.SESSION_PATH):
		Supabase.ensure_session(GameState.ensure_player_name())
	Screen.layout_changed.connect(_apply_layout)
	_apply_layout(Screen.compact)
	_select_tab(Tab.DAILY, false)
	_fetch(Tab.DAILY)
	_fetch(Tab.ALL_TIME)
	_back_button.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()

func _apply_layout(compact: bool) -> void:
	_compact = compact
	var vp := Screen.view_size()
	var w: float = minf(820.0, vp.x - 16.0)
	# En vertical sobra altura: más filas a la vista.
	var h: float = minf(900.0 if vp.y > vp.x * 1.2 else 660.0, vp.y - 20.0)
	_window.offset_left = -w / 2.0
	_window.offset_right = w / 2.0
	_window.offset_top = -h / 2.0
	_window.offset_bottom = h / 2.0
	_body.offset_left = 16.0 if compact else 30.0
	_body.offset_right = -_body.offset_left
	# Con poca altura (teléfono acostado) la explicación sobra.
	_hint.visible = vp.y >= 560.0
	_render()

func _on_renamed() -> void:
	_fetch(Tab.DAILY)
	_fetch(Tab.ALL_TIME)

func _save_name() -> void:
	GameState.set_player_name(_name_edit.text)

func _on_back() -> void:
	_save_name()
	Audio.play_sfx("ui_click")
	get_tree().change_scene_to_file(MENU_SCENE)

func _select_tab(tab: int, sound: bool = true) -> void:
	if sound and tab != _tab:
		Audio.play_sfx("ui_click")
	# Tocar una pestaña la vuelve a pedir: si la pantalla quedó abierta,
	# así aparecen las partidas que se jugaron mientras tanto.
	if sound:
		_fetch(tab)
	_tab = tab
	RpgTheme.style_tab(_daily_tab, tab == Tab.DAILY, 15)
	RpgTheme.style_tab(_all_tab, tab == Tab.ALL_TIME, 15)
	_hint.text = HINTS[tab]
	_render()

# ── Datos ────────────────────────────────────────────────────────

func _fetch(tab: int) -> void:
	var filter := "daily_date=eq.%s" % GameState.daily_date() if tab == Tab.DAILY else "daily_date=is.null"
	var path := "/runs?select=player_name,hero,map,difficulty,score,wave,victory,user_id&%s&order=score.desc&limit=%d" % [filter, FETCH_LIMIT]
	Supabase.rest_get(path, _on_fetched.bind(tab))

func _on_fetched(code: int, body: String, tab: int) -> void:
	if not is_inside_tree():
		return
	if code < 200 or code >= 300:
		# 404 = la tabla todavía no existe (falta correr el SQL).
		_errors[tab] = "El ranking todavía no está activado." if code == 404 \
			else "No se pudo cargar el ranking. Revisa tu conexión."
	else:
		var rows = JSON.parse_string(body)
		_rows[tab] = _best_per_player(rows if typeof(rows) == TYPE_ARRAY else [])
	if tab == _tab:
		_render()

## Una misma persona puede tener muchas partidas: vale la mejor. Las
## filas ya vienen ordenadas por puntaje, así que basta la primera.
func _best_per_player(rows: Array) -> Array:
	var seen := {}
	var out: Array = []
	for r in rows:
		var who: String = str(r.get("user_id", r.get("player_name", "")))
		if seen.has(who):
			continue
		seen[who] = true
		out.append(r)
	return out

# ── Lista ────────────────────────────────────────────────────────

func _render() -> void:
	if _list == null:
		return
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_mine.text = ""
	if _errors.has(_tab):
		_status(_errors[_tab])
		return
	if not _rows.has(_tab):
		_status("Cargando...")
		return
	var rows: Array = _rows[_tab]
	if rows.is_empty():
		_status("Todavía no hay partidas: ¡sé el primero!" if _tab == Tab.ALL_TIME \
			else "Nadie jugó el reto de hoy todavía: ¡sé el primero!")
	var my_place := 0
	for i in range(rows.size()):
		var mine: bool = Supabase.user_id != "" and str(rows[i].get("user_id", "")) == Supabase.user_id
		if mine:
			my_place = i + 1
		if i < TOP:
			_list.add_child(_make_row(i + 1, rows[i], mine))
	if my_place > 0:
		_mine.text = "Tu puesto: #%d de %d — %d puntos" % [my_place, rows.size(), int(rows[my_place - 1].get("score", 0))]
	elif Supabase.user_id != "":
		_mine.text = "Todavía no apareces acá: ¡juega una partida!"

func _status(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	RpgTheme.style_ink_label(l, 15, true, true)
	_list.add_child(l)

func _make_row(place: int, r: Dictionary, mine: bool) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", RpgTheme.slot_box(false, 8.0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)

	var place_label := Label.new()
	place_label.text = "%d." % place
	place_label.custom_minimum_size.x = 34.0
	place_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	place_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	RpgTheme.style_ink_label(place_label, 18, true)
	if place <= 3:
		place_label.add_theme_color_override("font_color", COLOR_GOLD)
	row.add_child(place_label)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	var name_label := Label.new()
	name_label.text = str(r.get("player_name", "?")) + ("  (tú)" if mine else "")
	name_label.clip_text = true
	RpgTheme.style_ink_label(name_label, 16, true)
	if mine:
		name_label.add_theme_color_override("font_color", RpgTheme.COLOR_INK_GOOD)
	col.add_child(name_label)
	var detail := Label.new()
	detail.text = _detail_text(r)
	detail.clip_text = true
	RpgTheme.style_ink_label(detail, 14, false, true)
	col.add_child(detail)

	var score := Label.new()
	score.text = str(int(r.get("score", 0)))
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	RpgTheme.style_ink_label(score, 18, true)
	row.add_child(score)
	return panel

## "Oleada 14 · Axel · Pantano Difícil" (el reto diario es siempre el
## mismo mapa/dificultad: ahí basta la oleada y el héroe).
func _detail_text(r: Dictionary) -> String:
	var parts: Array[String] = []
	var wave_text := "Oleada %d" % int(r.get("wave", 0))
	if r.get("victory", false):
		wave_text += " (ganó)"
	parts.append(wave_text)
	parts.append(_hero_names.get(str(r.get("hero", "")), "?"))
	if _tab == Tab.ALL_TIME:
		var map: Dictionary = GameState.MAPS.get(str(r.get("map", "")), {})
		var diff: Dictionary = GameState.DIFFICULTIES.get(str(r.get("difficulty", "")), {})
		var where: String = String(map.get("name", "?"))
		if not diff.is_empty() and str(r.get("difficulty", "")) != "normal":
			where += " " + String(diff["name"]).capitalize()
		parts.append(where)
	return " · ".join(parts)
