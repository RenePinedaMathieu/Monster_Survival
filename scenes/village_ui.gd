extends CanvasLayer

## Interfaz del pueblo (village.gd):
##   arriba     la moneda, tu héroe (abre su ficha) y el engranaje
##   en el mundo  el nombre de cada portón (y si está tapado), la arena
##              y el reto diario; y el cartel del lugar que tienes al
##              lado, que también se toca para usarlo
##   ventanas   portón (dificultad y a jugar), ficha del héroe (jugar
##              con él y su color) y opciones
##   portada    el fondo con el logo, la primera vez de cada sesión
## "Marks/*" son recuadros que siguen a lugares del mundo: el tutorial
## los usa de blanco (tutorial_overlay.gd).

const RpgTheme := preload("res://scenes/rpg_theme.gd")
const UITheme := preload("res://scenes/ui_theme.gd")
const BuildInfo := preload("res://scenes/build_info.gd")
const SelectScript := preload("res://scenes/character_select.gd")
const Layout := preload("res://assets/ui/village/village_layout.gd")
const OptionsScript := preload("res://scenes/options_controls.gd")
const COIN_TEXTURE := "res://assets/ui/rpg/coin.png"
const ICONS := "res://assets/ui/rpg_pack/Icons.png"
const GEAR_REGION := Rect2(80, 48, 16, 16)
const TITLE_TEXTURE := "res://assets/layouts/background_home.png"
const CREDITS_SCENE := "res://scenes/credits_menu.tscn"
const QA_SCENE := "res://scenes/qa_room.tscn"
const CATALOG_SCENE := "res://scenes/catalog.tscn"
## Lugares del mundo que marca el tutorial.
const MARKS: Dictionary = {"Gate": "gate:pradera", "Shop": "magic", "Arena": "trials"}

var _village: Node2D
var _hud: Control
var _coins: Label
var _hero_button: Button
var _gear: Button
var _record: Label
var _prompt: Button
var _prompt_spot: Dictionary = {}
var _labels: Array = []          # [Label, posición en el mundo]
var _marks: Control
var _dim: ColorRect
var _panel: Control              # ventana abierta (o null)
var _title: Control
var _touch: bool = false

func setup(village: Node2D) -> void:
	_village = village
	_touch = DisplayServer.is_touchscreen_available()
	_hud = Control.new()
	_hud.name = "Hud"
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud)
	_marks = Control.new()
	_marks.name = "Marks"
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_marks)
	for m in MARKS:
		var c := Control.new()
		c.name = m
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_marks.add_child(c)
	_build_world_labels()
	_build_top_bar()
	_prompt = Button.new()
	_prompt.visible = false
	_prompt.focus_mode = Control.FOCUS_NONE
	_prompt.pressed.connect(func():
		if not _prompt_spot.is_empty():
			_village._use(_prompt_spot))
	_hud.add_child(_prompt)
	var version := Label.new()
	version.text = "v " + BuildInfo.COMMIT
	RpgTheme.style_light_label(version, 12)
	version.modulate.a = 0.55
	version.mouse_filter = Control.MOUSE_FILTER_IGNORE
	version.anchor_top = 1.0
	version.anchor_bottom = 1.0
	version.offset_left = 8.0
	version.offset_top = -22.0
	version.offset_bottom = -4.0
	_hud.add_child(version)
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.55)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.visible = false
	add_child(_dim)
	Settings.changed.connect(_refresh_top_bar)
	_refresh_top_bar()

# ── Barra de arriba ───────────────────────────────────────────────

func _build_top_bar() -> void:
	var bar := HBoxContainer.new()
	bar.position = Vector2(12, 10)
	bar.add_theme_constant_override("separation", 10)
	_hud.add_child(bar)
	var coins := PanelContainer.new()
	coins.add_theme_stylebox_override("panel", RpgTheme.slot_box(true, 8.0))
	coins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	var icon := TextureRect.new()
	icon.texture = load(COIN_TEXTURE)
	icon.custom_minimum_size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	_coins = Label.new()
	RpgTheme.style_light_label(_coins, 18)
	row.add_child(_coins)
	coins.add_child(row)
	bar.add_child(coins)
	_hero_button = Button.new()
	_hero_button.focus_mode = Control.FOCUS_NONE
	RpgTheme.style_button(_hero_button, 15)
	_hero_button.pressed.connect(func(): _village._talk_hero(GameState.village_hero))
	bar.add_child(_hero_button)
	_record = Label.new()
	RpgTheme.style_light_label(_record, 13)
	_record.modulate.a = 0.85
	_record.position = Vector2(14, 60)
	_record.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_record)
	_gear = Button.new()
	_gear.name = "Gear"
	_gear.focus_mode = Control.FOCUS_NONE
	var gear_icon := AtlasTexture.new()
	gear_icon.atlas = load(ICONS)
	gear_icon.region = GEAR_REGION
	_gear.icon = gear_icon
	_gear.expand_icon = true
	_gear.custom_minimum_size = Vector2(48, 48)
	RpgTheme.style_button(_gear, 15)
	_gear.add_theme_constant_override("icon_max_width", 28)
	_gear.anchor_left = 1.0
	_gear.anchor_right = 1.0
	_gear.offset_left = -60.0
	_gear.offset_right = -12.0
	_gear.offset_top = 10.0
	_gear.offset_bottom = 58.0
	_gear.pressed.connect(show_options)
	_hud.add_child(_gear)

func _refresh_top_bar() -> void:
	_coins.text = " %d" % GameState.total_currency
	_hero_button.text = tr("HÉROE: %s") % GameState.CHARACTER_NAMES.get(GameState.village_hero, "GAROTH")
	if GameState.best_wave > 0:
		_record.text = tr("RÉCORD — Oleada %d · %02d:%02d") % [GameState.best_wave, int(GameState.best_time) / 60, int(GameState.best_time) % 60]
	else:
		_record.text = ""

# ── Sobre el mundo ────────────────────────────────────────────────

func _build_world_labels() -> void:
	for i in range(Layout.GATES.size()):
		var g: Dictionary = Layout.GATES[i]
		var map_id: String = _village.gate_maps()[i]
		var text: String = tr(GameState.MAPS[map_id]["name"]).to_upper()
		if not GameState.is_map_unlocked(map_id):
			text += "\n" + tr("(cerrado)")
		_add_world_label(text, Vector2(g["x"] + g["w"] / 2.0, 50.0))
		if g["south"]:
			_add_world_label(tr("RETO DIARIO"), Vector2(g["x"] + g["w"] / 2.0, Layout.SIZE.y - 30.0))
	_add_world_label(tr("ARENA"), Vector2(Layout.ARENA_GATE_X, 246.0))

func _add_world_label(text: String, world_pos: Vector2) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	RpgTheme.style_light_label(l, 14)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(l)
	_labels.append([l, world_pos])

func _process(_delta: float) -> void:
	for pair in _labels:
		var l: Label = pair[0]
		l.reset_size()
		l.position = _village.world_to_screen(pair[1]) - Vector2(l.size.x / 2.0, 0)
	for m in MARKS:
		var r: Rect2 = _spot_rect(MARKS[m])
		var c: Control = _marks.get_node(m)
		var a: Vector2 = _village.world_to_screen(r.position)
		c.position = a
		c.size = _village.world_to_screen(r.end) - a
	_coins.text = " %d" % GameState.total_currency

func _spot_rect(id: String) -> Rect2:
	for s in _village._spots:
		if s["id"] == id:
			return s["rect"]
	return Rect2()

## El tutorial pide la posición en el mundo de una marca ("UI/Marks/Gate").
func mark_world_position(target: String) -> Vector2:
	var name := target.get_file()
	if target.begins_with("UI/Marks/") and MARKS.has(name):
		return _spot_rect(MARKS[name]).get_center()
	return Vector2.INF

## El cartel del lugar que está al lado (vacío = se oculta).
func set_prompt(spot: Dictionary, screen_pos: Vector2) -> void:
	if spot.is_empty():
		_prompt.visible = false
		_prompt_spot = {}
		return
	if spot != _prompt_spot:
		_prompt_spot = spot
		var name: String = tr(spot["label"])
		_prompt.text = name if _touch else "E · " + name
		RpgTheme.style_button(_prompt, 14)
		_prompt.reset_size()
	_prompt.visible = true
	_prompt.position = screen_pos - Vector2(_prompt.size.x / 2.0, _prompt.size.y + 4.0)
	var vp := get_viewport().get_visible_rect().size
	_prompt.position.x = clampf(_prompt.position.x, 4.0, vp.x - _prompt.size.x - 4.0)
	_prompt.position.y = clampf(_prompt.position.y, 70.0, vp.y - _prompt.size.y - 4.0)

func world_input_enabled() -> bool:
	return _title == null

# ── Ventanas ──────────────────────────────────────────────────────

func is_panel_open() -> bool:
	return _panel != null

func _open_panel(content: Control, width: float) -> void:
	close_panel(false)
	var vp := get_viewport().get_visible_rect().size
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", RpgTheme.window_box_titled(24.0, 20.0))
	panel.custom_minimum_size.x = minf(width, vp.x - 16.0)
	panel.add_child(content)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_child(panel)
	add_child(center)
	_panel = center
	_dim.visible = true
	_prompt.visible = false

func close_panel(notify: bool = true) -> void:
	if _panel == null:
		return
	_panel.queue_free()
	_panel = null
	_dim.visible = false
	if notify:
		Audio.play_sfx("ui_click")
		_village.panel_closed()

func _unhandled_input(event: InputEvent) -> void:
	if _title != null:
		if (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton or event is InputEventScreenTouch) and event.is_pressed():
			_close_title()
			get_viewport().set_input_as_handled()
		return
	if _panel != null and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		close_panel()
		get_viewport().set_input_as_handled()

func _vbox(sep: int = 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

func _label(text: String, size: int, bold: bool = false, soft: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	RpgTheme.style_ink_label(l, size, bold, soft)
	return l

func _button(text: String, size: int, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	RpgTheme.style_button(b, size)
	b.custom_minimum_size = Vector2(150, 44)
	b.pressed.connect(action)
	b.mouse_entered.connect(func(): Audio.play_sfx("ui_hover"))
	return b

func _header(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	RpgTheme.style_header_title(l, 24)
	return l

## Portón: el mapa, su dificultad y a jugar. Tapado: qué lo abre.
func show_gate(map_id: String) -> void:
	var data: Dictionary = GameState.MAPS[map_id]
	var box := _vbox()
	box.add_child(_header(tr(data["name"]).to_upper()))
	if not GameState.is_map_unlocked(map_id):
		box.add_child(_label(tr("Este portón está tapado. Se abre al lograr: ") + tr(GameState.unlock_hint_for_map(map_id)), 16))
		var close := _button(tr("VOLVER"), 16, close_panel)
		box.add_child(close)
		_open_panel(box, 460.0)
		close.grab_focus()
		return
	box.add_child(_label(tr(data["desc"]), 16))
	if not GameState.is_difficulty_unlocked(GameState.selected_difficulty):
		GameState.selected_difficulty = "normal"
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	box.add_child(tabs)
	var info := _label("", 14, false, true)
	box.add_child(info)
	var refresh := func():
		for b in tabs.get_children():
			var id: String = b.get_meta("id")
			RpgTheme.style_tab(b, id == GameState.selected_difficulty, 14)
		var diff: Dictionary = GameState.DIFFICULTIES[GameState.selected_difficulty]
		var text: String = tr("Enemigos x%.2f · monedas x%.2f") % [data["mult"] * diff["mult"], data["mult"] * diff["coins"]]
		for id in GameState.DIFFICULTY_ORDER:
			if not GameState.is_difficulty_unlocked(id):
				for a in GameState.ACHIEVEMENTS:
					if a["id"] == GameState.DIFFICULTIES[id]["unlock"]:
						text += "\n%s: %s" % [tr(GameState.DIFFICULTIES[id]["name"]).capitalize(), tr(a["desc"]).to_lower()]
		info.text = text
	for id in GameState.DIFFICULTY_ORDER:
		var b := Button.new()
		b.set_meta("id", id)
		var unlocked: bool = GameState.is_difficulty_unlocked(id)
		b.text = tr(GameState.DIFFICULTIES[id]["name"]) + ("" if unlocked else tr(" (bloq.)"))
		b.disabled = not unlocked
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			Audio.play_sfx("ui_click")
			GameState.selected_difficulty = id
			refresh.call())
		tabs.add_child(b)
	refresh.call()
	box.add_child(_label(tr("Con %s") % GameState.CHARACTER_NAMES.get(GameState.village_hero, ""), 14, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var play := _button(tr("¡A LUCHAR!"), 18, func(): _village.play(map_id, GameState.selected_difficulty))
	row.add_child(play)
	row.add_child(_button(tr("VOLVER"), 16, close_panel))
	box.add_child(row)
	_open_panel(box, 520.0)
	play.grab_focus()

## Ficha de un héroe: jugar con él (o, si ya es el tuyo, cambiar su color).
func show_hero(id: String) -> void:
	var entry: Dictionary = {}
	for c in SelectScript.CHARACTERS:
		if c["id"] == id:
			entry = c
	if entry.is_empty():
		return
	var mine: bool = id == GameState.village_hero
	var color := [GameState.selected_color(id)]   # en un Array: lo cambian los lambdas
	var n_colors: int = entry["colors"].size()
	var outer := _vbox(10)
	outer.add_child(_header(entry["name"]))
	# Pantalla angosta (teléfono vertical): retrato arriba, texto abajo.
	var narrow: bool = get_viewport().get_visible_rect().size.x < 640.0
	var row := BoxContainer.new()
	row.vertical = narrow
	outer.add_child(row)
	row.add_theme_constant_override("separation", 16)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", RpgTheme.slot_box(true, 8.0))
	var portrait := TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(150, 170) if narrow else Vector2(200, 260)
	frame.add_child(portrait)
	if narrow:
		frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_child(frame)
	var box := _vbox(8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(box)
	box.add_child(_label(tr(entry["role"]), 14, true))
	box.add_child(_label(tr(entry["blurb"]), 14))
	var picker := HBoxContainer.new()
	picker.add_theme_constant_override("separation", 8)
	box.add_child(picker)
	var hint := _label("", 13, false, true)
	box.add_child(hint)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	var confirm := _button(tr("LISTO") if mine else tr("JUGAR CON %s") % entry["name"], 15, func():
		GameState.set_selected_color(id, color[0])
		close_panel(false)
		_village.set_hero(id)
		_refresh_top_bar()
		_village.panel_closed())
	buttons.add_child(confirm)
	buttons.add_child(_button(tr("VOLVER"), 15, close_panel))
	box.add_child(buttons)
	var color_label := Label.new()
	RpgTheme.style_ink_label(color_label, 15, true)
	color_label.custom_minimum_size.x = 110
	color_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var show_color := func():
		var data: Dictionary = SelectScript.colored(entry, color[0])
		portrait.texture = SelectScript.portrait_texture(data)
		var unlocked: bool = GameState.is_color_unlocked(id, color[0])
		portrait.modulate = Color.WHITE if unlocked else Color(0.1, 0.1, 0.12)
		color_label.text = tr(data["color"]).to_upper()
		hint.text = "" if unlocked else tr("Se gana: ") + GameState.color_unlock_hint(id, color[0])
		confirm.disabled = not unlocked
	var step := func(d: int):
		Audio.play_sfx("ui_click")
		color[0] = posmod(color[0] + d, n_colors)
		show_color.call()
	var prev := _button("<", 15, step.bind(-1))
	prev.custom_minimum_size = Vector2(40, 36)
	var next := _button(">", 15, step.bind(1))
	next.custom_minimum_size = Vector2(40, 36)
	picker.add_child(prev)
	picker.add_child(color_label)
	picker.add_child(next)
	show_color.call()
	_open_panel(outer, 640.0)
	confirm.grab_focus()

func show_options() -> void:
	if _panel != null:
		return
	_village.hero.controllable = false
	var box := _vbox(10)
	box.add_child(_header(tr("OPCIONES")))
	var opts := VBoxContainer.new()
	opts.set_script(OptionsScript)
	box.add_child(opts)
	var extra := HBoxContainer.new()
	extra.add_theme_constant_override("separation", 10)
	extra.alignment = BoxContainer.ALIGNMENT_CENTER
	extra.add_child(_button(tr("TUTORIAL"), 15, func():
		close_panel(false)
		_village.show_tutorial()))
	extra.add_child(_button(tr("CRÉDITOS"), 15, func(): _village._go(CREDITS_SCENE)))
	box.add_child(extra)
	# QA Room y Catálogo son herramientas nuestras: no van en el build
	# de Steam (ver Settings.dev_tools_enabled).
	if Settings.dev_tools_enabled():
		var dev := HBoxContainer.new()
		dev.add_theme_constant_override("separation", 10)
		dev.alignment = BoxContainer.ALIGNMENT_CENTER
		dev.add_child(_button(tr("QA ROOM"), 15, func(): _village._go(QA_SCENE)))
		dev.add_child(_button(tr("CATÁLOGO"), 15, func(): _village._go(CATALOG_SCENE)))
		box.add_child(dev)
		# Mientras se pintan en Tiled: jugar con los mapas nuevos.
		var maps := _button("", 15, func(): pass)
		var show_maps := func(): maps.text = "MAPAS DE TILED: " + ("SÍ" if GameState.qa_tiled_maps else "NO")
		show_maps.call()
		maps.pressed.connect(func():
			GameState.qa_tiled_maps = not GameState.qa_tiled_maps
			show_maps.call())
		maps.custom_minimum_size.x = 310.0
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(maps)
		box.add_child(row)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	var back := _button(tr("VOLVER"), 16, close_panel)
	bottom.add_child(back)
	# En Web no hay forma confiable de cerrar la pestaña desde el juego.
	if not OS.has_feature("web"):
		bottom.add_child(_button(tr("SALIR"), 16, func(): get_tree().quit()))
	box.add_child(bottom)
	_open_panel(box, 460.0)
	var first: Control = opts.first_control()
	(first if first != null else back).grab_focus()

# ── Portada ───────────────────────────────────────────────────────

## La primera vez de la sesión: el fondo con el logo hasta que se toque
## algo (en Web, además, ese toque habilita el sonido). Después, `then`.
func show_title_if_needed(then: Callable) -> void:
	if GameState.title_shown:
		then.call_deferred()
		return
	# Todo ignora el mouse: el toque llega a _unhandled_input y la cierra.
	_title = Control.new()
	_title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.set_meta("then", then)
	add_child(_title)
	var bg := ColorRect.new()
	bg.color = Color("140d09")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_child(bg)
	var art := TextureRect.new()
	art.texture = load(TITLE_TEXTURE)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_child(art)
	var vp := get_viewport().get_visible_rect().size
	if vp.y > vp.x * 1.2:
		# Vertical: el logo entra a lo ancho, pegado arriba.
		var w: float = vp.x * 1280.0 / 470.0
		art.position = Vector2((vp.x - w) / 2.0, 0.0)
		art.size = Vector2(w, w * 720.0 / 1280.0)
	else:
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var press := Label.new()
	press.text = tr("TOCA PARA EMPEZAR") if _touch else tr("PRESIONA CUALQUIER TECLA")
	press.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	RpgTheme.style_light_label(press, 24)
	press.anchor_left = 0.5
	press.anchor_right = 0.5
	press.anchor_top = 1.0
	press.anchor_bottom = 1.0
	press.offset_left = -300.0
	press.offset_right = 300.0
	press.offset_top = -90.0
	press.offset_bottom = -50.0
	_title.add_child(press)
	var tw := press.create_tween().set_loops()
	tw.tween_property(press, "modulate:a", 0.35, 0.7)
	tw.tween_property(press, "modulate:a", 1.0, 0.7)

func _close_title() -> void:
	if _title == null:
		return
	var t := _title
	_title = null
	GameState.title_shown = true
	Audio.play_sfx("ui_click")
	var then: Callable = t.get_meta("then")
	var tw := t.create_tween()
	tw.tween_property(t, "modulate:a", 0.0, 0.35)
	tw.tween_callback(t.queue_free)
	tw.tween_callback(then)
