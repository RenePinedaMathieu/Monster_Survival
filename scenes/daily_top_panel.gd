extends PanelContainer

## Panel "TOP DE HOY" de la portada: los mejores del reto diario de hoy
## (tabla runs de Supabase, misma consulta que leaderboard_menu.gd). Un
## clic abre el ranking completo. Sin conexión se esconde, para no dejar
## un cartel de error en la portada.

signal open_ranking

const RpgTheme := preload("res://scenes/rpg_theme.gd")
const TOP := 5
const WIDTH := 260.0
const COLOR_GOLD := Color("ffd24a")
const COLOR_MINE := Color("9be38f")

var _list: VBoxContainer
var _rows: Array = []

func _ready() -> void:
	add_theme_stylebox_override("panel", RpgTheme.wood_box(14.0, 10.0))
	custom_minimum_size.x = WIDTH
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "Ver el ranking completo"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	box.add_child(_label("TOP DE HOY", 18, true))
	var sub := _label("Reto diario · " + GameState.daily_date(), 12, true)
	sub.modulate.a = 0.75
	box.add_child(sub)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_list)
	var foot := _label("Ver ranking completo", 12, true)
	foot.modulate.a = 0.7
	box.add_child(foot)
	_status("Cargando...")
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(func(): self_modulate = Color(1.15, 1.15, 1.15))
	mouse_exited.connect(func(): self_modulate = Color.WHITE)
	# Con la sesión guardada se sabe cuál es tu fila.
	Supabase.auth_ready.connect(_render)
	if FileAccess.file_exists(Supabase.SESSION_PATH):
		Supabase.ensure_session(GameState.ensure_player_name())
	var path := "/runs?select=player_name,score,wave,victory,user_id&daily_date=eq.%s&order=score.desc&limit=50" % GameState.daily_date()
	Supabase.rest_get(path, _on_fetched)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		accept_event()
		Audio.play_sfx("ui_click")
		open_ranking.emit()

func _on_fetched(code: int, body: String) -> void:
	if not is_inside_tree():
		return
	if code < 200 or code >= 300:
		hide()
		return
	var rows = JSON.parse_string(body)
	# El mejor puntaje de cada jugador (vienen ordenadas por puntaje).
	var seen := {}
	_rows.clear()
	for r in (rows if typeof(rows) == TYPE_ARRAY else []):
		var who := str(r.get("user_id", r.get("player_name", "")))
		if not seen.has(who):
			seen[who] = true
			_rows.append(r)
	_render()

func _render() -> void:
	if _list == null:
		return
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	if _rows.is_empty():
		_status("Nadie jugó hoy.\n¡Sé el primero!")
		return
	for i in range(mini(TOP, _rows.size())):
		var r: Dictionary = _rows[i]
		var mine: bool = Supabase.user_id != "" and str(r.get("user_id", "")) == Supabase.user_id
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var place := _label("%d." % (i + 1), 15, false)
		place.custom_minimum_size.x = 22.0
		if i < 3:
			place.add_theme_color_override("font_color", COLOR_GOLD)
		row.add_child(place)
		var name_label := _label(str(r.get("player_name", "?")), 15, false)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.clip_text = true
		if mine:
			name_label.add_theme_color_override("font_color", COLOR_MINE)
		row.add_child(name_label)
		var score := _label(_thousands(int(r.get("score", 0))), 15, false)
		score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(score)
		_list.add_child(row)

func _status(text: String) -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var l := _label(text, 14, true)
	l.modulate.a = 0.85
	_list.add_child(l)

func _label(text: String, size: int, centered: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	RpgTheme.style_light_label(l, size)
	if centered:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

## 30930 -> "30.930"
static func _thousands(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
