extends Control

## Pantalla de LOGROS (menú principal): % completado, la colección de
## evoluciones (las no descubiertas muestran sólo el arma — la pasiva
## que la completa es el misterio a descubrir) y la lista de logros con
## su progreso y premio (GameState.ACHIEVEMENTS).

const RpgTheme := preload("res://scenes/rpg_theme.gd")
const Upgrades := preload("res://scenes/upgrades.gd")
const BACKGROUND_TEXTURE := "res://assets/layouts/background_home.png"
const MENU_SCENE := "res://scenes/main_menu.tscn"
const COLOR_DONE := Color("57c767")

@onready var _window: Panel = $Window
@onready var _title: Label = $Window/Title
@onready var _progress_label: Label = $Window/Body/ProgressRow/ProgressLabel
@onready var _progress_bar: ProgressBar = $Window/Body/ProgressRow/ProgressBar
@onready var _list: VBoxContainer = $Window/Body/Scroll/List
@onready var _back_button: Button = $Window/Body/BackButton

var _compact: bool = false

func _ready() -> void:
	$Background.texture = load(BACKGROUND_TEXTURE)
	_window.add_theme_stylebox_override("panel", RpgTheme.window_box())
	RpgTheme.style_light_label(_title, 26)
	RpgTheme.style_ink_label(_progress_label, 16, true)
	RpgTheme.style_level_bar(_progress_bar, COLOR_DONE)
	RpgTheme.style_button(_back_button, 18)
	_back_button.pressed.connect(_on_back)
	_back_button.grab_focus()
	Screen.layout_changed.connect(_apply_layout)
	_apply_layout(Screen.compact)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()

func _apply_layout(compact: bool) -> void:
	_compact = compact
	var vp := Screen.view_size()
	var w: float = minf(1040.0, vp.x - 16.0)
	var h: float = minf(680.0, vp.y - 24.0)
	_window.offset_left = -w / 2.0
	_window.offset_right = w / 2.0
	_window.offset_top = -h / 2.0
	_window.offset_bottom = h / 2.0
	$Window/Body.offset_left = 16.0 if compact else 30.0
	$Window/Body.offset_right = -16.0 if compact else -30.0
	_rebuild()

func _rebuild() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var done: int = GameState.achievements_unlocked.size()
	var total: int = GameState.ACHIEVEMENTS.size()
	_progress_label.text = "%d / %d · %d%% completado" % [done, total, int(round(GameState.achievement_progress() * 100.0))]
	_progress_bar.max_value = total
	_progress_bar.value = done

	_list.add_child(_section("EVOLUCIONES  %d / %d" % [GameState.discovered_evolutions.size(), Upgrades.EVOLUTIONS.size()]))
	var grid := GridContainer.new()
	grid.columns = 1 if _compact else 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	_list.add_child(grid)
	for evo in Upgrades.EVOLUTIONS:
		grid.add_child(_evolution_card(evo))

	_list.add_child(_section("LOGROS"))
	var agrid := GridContainer.new()
	agrid.columns = 1 if _compact else 2
	agrid.add_theme_constant_override("h_separation", 10)
	agrid.add_theme_constant_override("v_separation", 8)
	_list.add_child(agrid)
	for a in GameState.ACHIEVEMENTS:
		agrid.add_child(_achievement_card(a))

func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	RpgTheme.style_ink_label(l, 17, true)
	return l

func _card(done: bool) -> Dictionary:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", RpgTheme.slot_box(false, 10.0))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not done:
		card.modulate = Color(0.82, 0.8, 0.78)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", RpgTheme.slot_box(true, 4.0))
	badge.custom_minimum_size = Vector2(56, 56)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(badge)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(46, 46)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.add_child(icon)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(col)
	return {"card": card, "icon": icon, "col": col}

func _line(parent: Node, text: String, size: int, bold: bool, soft: bool, color = null) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	RpgTheme.style_ink_label(l, size, bold, soft)
	if color != null:
		l.add_theme_color_override("font_color", color)
	parent.add_child(l)

func _evolution_card(evo: String) -> Control:
	var e: Dictionary = Upgrades.EVOLUTIONS[evo]
	var found: bool = GameState.is_evolution_discovered(evo)
	var parts := _card(found)
	var weapon_name: String = "Pollo (acompañante)" if e["weapon"] == "pollo" else Upgrades.WEAPONS[e["weapon"]]["name"]
	if found:
		parts["icon"].texture = load(e["icon"])
		parts["icon"].texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_line(parts["col"], e["name"], 16, true, false)
		var passive_title: String = Upgrades.card(e["passive"]).get("title", e["passive"])
		_line(parts["col"], "%s al máximo + %s" % [weapon_name, passive_title], 13, false, true)
	else:
		parts["icon"].texture = load("res://assets/ui/rpg/lock.png")
		parts["icon"].texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_line(parts["col"], "???", 16, true, false)
		_line(parts["col"], "%s al máximo + ???" % weapon_name, 13, false, true)
	return parts["card"]

func _achievement_card(a: Dictionary) -> Control:
	var done: bool = GameState.is_achievement_unlocked(a["id"])
	var parts := _card(done)
	parts["icon"].texture = load("res://assets/ui/rpg/trophy.png")
	parts["icon"].texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parts["icon"].modulate = Color(1.6, 1.3, 0.5) if done else Color(0.6, 0.55, 0.5)
	_line(parts["col"], a["name"], 16, true, false, COLOR_DONE.darkened(0.35) if done else null)
	_line(parts["col"], a["desc"], 13, false, true)
	var progress: int = mini(GameState.stat_value(a["stat"]), a["goal"])
	var status: String = "COMPLETADO" if done else "%d / %d" % [progress, a["goal"]]
	_line(parts["col"], "%s  ·  %s" % [status, GameState.reward_text(a["reward"])], 13, true, false,
		RpgTheme.COLOR_INK_GOOD if done else RpgTheme.COLOR_INK_SOFT)
	return parts["card"]

func _on_back() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
