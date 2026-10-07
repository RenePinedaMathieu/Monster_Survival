extends Node2D

## QA Room — sandbox de testing con hotkeys de teclado + panel táctil
## para probar desde el teléfono. F6 sobre qa_room.tscn en el editor,
## o desde el menú principal → Opciones → QA ROOM (DEV).
##
## Controles teclado:
##   WASD          — moverte (o joystick táctil izquierda en móvil)
##   Q / E         — zoom out / in
##   L             — trigger level-up modal (Espacio = habilidad activa)
##   H / J / T     — cambiar héroe (GAROTH, ELARA, DOREN) / color / forma
##   1..6          — spawn 1 monster: rat, imp, lizardman, slime, ghost, beholder
##   Shift+1..3    — spawn boss: demon1 / demon2 / demon3
##   F / R / M     — unlock flying swords / ranged / meteoros
##   C             — spawnear el pollo acompañante (sin comprarlo)
##   G             — +500 monedas para probar la tienda
##   K             — kill all monsters
##   X / Shift+X   — poner un blanco de práctica / quitar los blancos
##                   (training_dummy.gd: no se mueve ni muere y muestra
##                   el daño por segundo de cada arma)
##   +/-           — ±10 hp al player
##   Esc           — volver al menú
##
## En móvil todas esas acciones tienen su botón en el panel de la
## derecha. Los bosses aparecen normalmente en el gameplay real cada
## 10 waves (main.gd), acá los podemos meter cuando queramos.

const LEVEL_UP_MENU_SCENE := preload("res://scenes/level_up_menu.tscn")
const MONSTER_SCENE := preload("res://scenes/monster.tscn")
const TOUCH_CONTROLS_SCENE := preload("res://scenes/touch_controls.tscn")
const RpgTheme := preload("res://scenes/rpg_theme.gd")
const Upgrades := preload("res://scenes/upgrades.gd")
const CHEST_SCRIPT := preload("res://scenes/chest.gd")
const CharSelect := preload("res://scenes/character_select.gd")
const PlayerScript := preload("res://scenes/player.gd")
const DummyScript := preload("res://scenes/training_dummy.gd")
const Weapons := preload("res://scenes/weapons.gd")

const SPAWN_KEYS: Dictionary = {
	KEY_1: "rat",
	KEY_2: "imp",
	KEY_3: "lizardman",
	KEY_4: "slime_1",
	KEY_5: "ghost_1",
	KEY_6: "beholder_1",
}
const BOSS_KEYS: Dictionary = {
	KEY_1: "demon1",
	KEY_2: "demon2",
	KEY_3: "demon3",
}

@onready var _player: CharacterBody2D = $Player
@onready var _monsters_container: Node2D = $Monsters
@onready var _help_label: Label = $UI/HelpLabel
@onready var _touch_panel: Control = $UI/TouchPanel

var _hero_label: Label
## Daño por segundo de cada arma, sumado entre los blancos.
var _dummy_stats: Label
var _stats_t: float = 0.0
var _color_i: int = 0

func _ready() -> void:
	# Sin los \r del archivo (fin de línea de Windows): cada uno se veía
	# como un salto de línea más.
	_help_label.text = _help_text().replace("\r", "")
	_build_hero_controls()

	# Joystick táctil izquierdo — mismo que se usa en el gameplay real
	var tc = TOUCH_CONTROLS_SCENE.instantiate()
	add_child(tc)
	if _player.has_method("set_touch_input"):
		tc.move_input.connect(_player.set_touch_input)

	_wire_touch_buttons()
	_make_panel_scroll()
	_style_panels()

	_dummy_stats = Label.new()
	RpgTheme.style_light_label(_dummy_stats, 14)
	_dummy_stats.anchor_top = 1.0
	_dummy_stats.anchor_bottom = 1.0
	_dummy_stats.offset_left = 16.0
	_dummy_stats.offset_top = -40.0
	_dummy_stats.offset_bottom = -12.0
	_dummy_stats.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_dummy_stats.visible = false
	$UI.add_child(_dummy_stats)

	Screen.layout_changed.connect(_apply_layout)
	_apply_layout(Screen.compact)

## En teléfono: panel más angosto y sin la ayuda de teclado (tapa el
## juego y en el celu no sirve).
func _apply_layout(compact: bool) -> void:
	_touch_panel.offset_left = -208.0 if compact else -260.0
	$UI/HelpBg.visible = not compact
	_help_label.visible = not compact
	_fit_help_bg.call_deferred()

## El fondo de la ayuda, del alto de su texto.
func _fit_help_bg() -> void:
	$UI/HelpBg.offset_bottom = _help_label.position.y + _help_label.get_combined_minimum_size().y + 8.0

func _process(delta: float) -> void:
	_stats_t -= delta
	if _stats_t > 0.0:
		return
	_stats_t = 0.25
	var dummies := get_tree().get_nodes_in_group("qa_dummy")
	_dummy_stats.visible = not dummies.is_empty()
	if dummies.is_empty():
		return
	var by := {}
	for d in dummies:
		var r: Dictionary = d.recent_damage()
		for id in r:
			by[id] = float(by.get(id, 0.0)) + r[id]
	var total := 0.0
	for v in by.values():
		total += v
	var ids: Array = by.keys()
	ids.sort_custom(func(a, b): return by[a] > by[b])
	var lines: Array = ["BLANCOS · daño por segundo (últimos %d s): %d" % [int(DummyScript.WINDOW), roundi(total / DummyScript.WINDOW)]]
	for id in ids:
		lines.append("  %s  %d" % [Weapons.display_name(id), roundi(by[id] / DummyScript.WINDOW)])
	_dummy_stats.text = "\n".join(lines)

## Con la fila de héroes el panel no entra en 720 de alto: va dentro de
## un ScrollContainer (rueda del mouse o arrastrar con el dedo).
func _make_panel_scroll() -> void:
	var content: Control = _touch_panel.get_node("Content")
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 8.0
	scroll.offset_top = 8.0
	scroll.offset_right = -8.0
	scroll.offset_bottom = -8.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_touch_panel.add_child(scroll)
	content.reparent(scroll, false)
	content.set_anchors_preset(Control.PRESET_TOP_LEFT)
	content.offset_left = 0.0
	content.offset_top = 0.0
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_help_label.offset_bottom = 258.0

## Mismo estilo que el resto de la UI (rpg_theme.gd): madera + verdes.
func _style_panels() -> void:
	_touch_panel.add_theme_stylebox_override("panel", RpgTheme.wood_box(9.0, 9.0))
	$UI/HelpBg.color = Color(0.227, 0.157, 0.114, 0.85)
	RpgTheme.style_light_label(_help_label, 12)
	_touch_panel.find_child("Content", true, false).add_theme_constant_override("separation", 4)
	for node in _touch_panel.find_children("*", "", true, false):
		if node is Button:
			RpgTheme.style_button(node, 13)
			# Bajitos: con todos los botones de prueba el panel no entraba
			# en 720 de alto.
			node.custom_minimum_size.y = 29.0
		elif node is Label:
			RpgTheme.style_light_label(node, 12)

func _wire_touch_buttons() -> void:
	# Los botones cuelgan de UI/TouchPanel/Content/<Group>/<Btn> — la
	# ruta empieza con "Content/" porque el VBoxContainer intermedio
	# organiza todo el layout adentro del Panel.
	var root: Node = _touch_panel.get_node("Content")

	root.get_node("Actions/LevelUpBtn").pressed.connect(_trigger_level_up)
	root.get_node("Actions/KillAllBtn").pressed.connect(_kill_all)
	root.get_node("Actions/BackBtn").pressed.connect(_back_to_menu)
	# Blancos de práctica: para ver las armas sin monstruos encima.
	var actions: Node = root.get_node("Actions")
	for pair in [["Poner blanco", _spawn_dummy], ["Quitar blancos", _clear_dummies]]:
		var b := Button.new()
		b.text = pair[0]
		b.pressed.connect(pair[1])
		actions.add_child(b)
		actions.move_child(b, 2 if pair[0] == "Poner blanco" else 3)
	# Catálogo del universo: sprites, animaciones, íconos y efectos.
	root.get_node("Actions/CatalogBtn").pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/catalog.tscn"))

	root.get_node("Spawns/RatBtn").pressed.connect(_spawn_monster.bind("rat", false))
	root.get_node("Spawns/ImpBtn").pressed.connect(_spawn_monster.bind("imp", false))
	root.get_node("Spawns/LizardBtn").pressed.connect(_spawn_monster.bind("lizardman", false))
	root.get_node("Spawns/SlimeBtn").pressed.connect(_spawn_monster.bind("slime_1", false))
	root.get_node("Spawns/GhostBtn").pressed.connect(_spawn_monster.bind("ghost_1", false))
	root.get_node("Spawns/BeholderBtn").pressed.connect(_spawn_monster.bind("beholder_1", false))

	root.get_node("Bosses/Demon1Btn").pressed.connect(_spawn_monster.bind("demon1", true))
	root.get_node("Bosses/Demon2Btn").pressed.connect(_spawn_monster.bind("demon2", true))
	root.get_node("Bosses/Demon3Btn").pressed.connect(_spawn_monster.bind("demon3", true))

	root.get_node("Unlocks/SwordsBtn").pressed.connect(_unlock.bind("flying_swords"))
	root.get_node("Unlocks/RangedBtn").pressed.connect(_unlock.bind("ranged_bonus"))
	root.get_node("Unlocks/MeteorsBtn").pressed.connect(_unlock.bind("meteors"))
	root.get_node("Unlocks/ChickenBtn").pressed.connect(_next_companion)
	root.get_node("Unlocks/CoinsBtn").pressed.connect(GameState.grant_currency.bind(500))
	root.get_node("Unlocks/AuraBtn").pressed.connect(_unlock.bind("aura"))
	root.get_node("Unlocks/AxeBtn").pressed.connect(_unlock.bind("hacha"))
	root.get_node("Unlocks/BoltBtn").pressed.connect(_unlock.bind("rayo"))
	root.get_node("Unlocks/EliteBtn").pressed.connect(_spawn_elite)
	root.get_node("Unlocks/ChestBtn").pressed.connect(_spawn_chest)
	root.get_node("Unlocks/MaxBtn").pressed.connect(_max_weapons)

	root.get_node("HP/HealBtn").pressed.connect(func(): _player.heal(10.0))
	root.get_node("HP/DamageBtn").pressed.connect(func(): _player.take_damage(10.0))

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: int = event.keycode

	if key == KEY_ESCAPE:
		_back_to_menu()
		return
	if key == KEY_L:
		_trigger_level_up()
		return
	if key == KEY_H:
		_next_hero()
		return
	if key == KEY_J:
		_next_color()
		return
	if key == KEY_T:
		_next_form()
		return
	if event.shift_pressed and BOSS_KEYS.has(key):
		_spawn_monster(BOSS_KEYS[key], true)
		return
	if SPAWN_KEYS.has(key):
		_spawn_monster(SPAWN_KEYS[key], false)
		return
	if key == KEY_F:
		_unlock("flying_swords")
	elif key == KEY_R:
		_unlock("ranged_bonus")
	elif key == KEY_M:
		_unlock("meteors")
	elif key == KEY_C:
		_next_companion()
	elif key == KEY_V:
		_spawn_chest()
	elif key == KEY_B:
		_spawn_elite()
	elif key == KEY_N:
		_max_weapons()
	elif key == KEY_G:
		GameState.grant_currency(500)
	elif key == KEY_K:
		_kill_all()
	elif key == KEY_X:
		if event.shift_pressed:
			_clear_dummies()
		else:
			_spawn_dummy()
	elif key == KEY_EQUAL or key == KEY_PLUS:
		_player.heal(10.0)
	elif key == KEY_MINUS:
		_player.take_damage(10.0)

# ── Héroe: clase, color y forma (sin candados: es para probar) ────

## Fila HÉROE arriba del panel: un botón por héroe, color y forma, y
## qué se está viendo.
func _build_hero_controls() -> void:
	var content: Node = _touch_panel.get_node("Content")
	var title := Label.new()
	title.text = "Héroe"
	content.add_child(title)
	content.move_child(title, 1)
	var grid := GridContainer.new()
	grid.columns = 3
	content.add_child(grid)
	content.move_child(grid, 2)
	for c in CharSelect.CHARACTERS:
		var b := Button.new()
		b.text = c["name"]
		b.pressed.connect(_switch_hero.bind(c["id"]))
		grid.add_child(b)
	for pair in [["Color >", _next_color], ["Forma >", _next_form]]:
		var b := Button.new()
		b.text = pair[0]
		b.pressed.connect(pair[1])
		grid.add_child(b)
	_hero_label = Label.new()
	content.add_child(_hero_label)
	content.move_child(_hero_label, 3)
	_color_i = GameState.selected_color(GameState.selected_character_id)
	_update_hero_label()

func _hero_class() -> Dictionary:
	return PlayerScript.HERO_CLASSES.get(GameState.selected_character_id, {})

func _update_hero_label() -> void:
	var hc := _hero_class()
	if hc.is_empty():
		_hero_label.text = GameState.CHARACTER_NAMES.get(GameState.selected_character_id, "?")
		return
	var entry: Dictionary = CharSelect.find_character(GameState.selected_character_id)
	var colors: Array = entry.get("colors", [])
	var cname: String = colors[_color_i]["color"] if _color_i < colors.size() else ""
	_hero_label.text = "%s · %s · forma %d/%d" % [entry.get("name", ""), cname, _player._swordman_tier, hc["max_tier"]]

## Otro héroe: se recarga la sala (el héroe se arma en su _ready).
func _switch_hero(id: String) -> void:
	GameState.selected_character_id = id
	get_tree().reload_current_scene()

func _next_hero() -> void:
	var ids: Array = CharSelect.CHARACTERS.map(func(c): return c["id"])
	var i: int = ids.find(GameState.selected_character_id)
	_switch_hero(ids[(i + 1) % ids.size()])

## Siguiente color en el mismo héroe, sin recargar (no se guarda).
func _next_color() -> void:
	var hc := _hero_class()
	if hc.is_empty():
		return
	_color_i = (_color_i + 1) % hc["colors"].size()
	_player._hero_color = hc["colors"][_color_i]
	_player._load_swordman_textures()
	_player._apply_idle()
	_update_hero_label()

## Siguiente forma: el nivel justo de esa forma (vuelve a la 1 al final).
func _next_form() -> void:
	var hc := _hero_class()
	if hc.is_empty():
		return
	var next_tier: int = _player._swordman_tier % int(hc["max_tier"]) + 1
	_player.level = 1 + (next_tier - 1) * int(hc["tier_every"])
	_player._load_swordman_textures()
	_player._apply_idle()
	_update_hero_label()

# ── Acciones (compartidas entre keyboard y botones táctiles) ─────

func _trigger_level_up() -> void:
	var menu = LEVEL_UP_MENU_SCENE.instantiate()
	add_child(menu)
	menu.show_for(_player)

func _unlock(id: String) -> void:
	if _player.has_method("apply_upgrade"):
		_player.apply_upgrade(id)

## Crías de slime / ratas invocadas por jefes (ver monster._spawn_minion).
func register_monster(m) -> void:
	m.target = _player
	m.hit_player.connect(func(dmg): _player.take_damage(dmg))

func _spawn_elite() -> void:
	_spawn_monster("lizardman", false)
	var ms := _monsters_container.get_children()
	if not ms.is_empty():
		ms[-1].make_elite()

func _spawn_chest() -> void:
	var chest := Area2D.new()
	chest.set_script(CHEST_SCRIPT)
	add_child(chest)
	chest.global_position = _player.global_position + Vector2(60, 0)

## Sube al máximo las armas que tengas y te da la pasiva compañera de
## cada una — así el próximo cofre ya evoluciona.
func _max_weapons() -> void:
	for w in Upgrades.WEAPONS:
		var guard := 10
		while _player.weapon_level(w) > 0 and _player.weapon_level(w) < Upgrades.MAX_LEVEL and guard > 0:
			_player.apply_upgrade(Upgrades.WEAPONS[w]["level"])
			guard -= 1
	for evo in Upgrades.EVOLUTIONS:
		var e: Dictionary = Upgrades.EVOLUTIONS[evo]
		var owned: bool = _player.has_companion("chicken") if e["weapon"] == "pollo" else _player.weapon_level(e["weapon"]) > 0
		if owned and _player.passive_level(e["passive"]) == 0:
			_player.apply_upgrade(e["passive"])

## Un blanco al frente del héroe (cada uno más, en abanico).
func _spawn_dummy() -> void:
	var n := get_tree().get_nodes_in_group("qa_dummy").size()
	var d := CharacterBody2D.new()
	d.set_script(DummyScript)
	d.add_to_group("qa_dummy")
	d.position = _player.position + Vector2(110, 0).rotated(-0.5 + n * 0.5)
	_monsters_container.add_child(d)

func _clear_dummies() -> void:
	for d in get_tree().get_nodes_in_group("qa_dummy"):
		d.queue_free()

func _kill_all() -> void:
	for m in get_tree().get_nodes_in_group("monster"):
		if m.has_method("take_damage") and not m.is_in_group("qa_dummy"):
			m.take_damage(9999.0, "qa")

func _back_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/village.tscn")

func _spawn_monster(kind_id: String, is_boss: bool) -> void:
	var m = MONSTER_SCENE.instantiate()
	var ang := randf() * TAU
	m.position = _player.position + Vector2(cos(ang), sin(ang)) * 240.0
	if is_boss:
		m.max_hp = 80.0
		m.coin_reward = 25
	_monsters_container.add_child(m)
	m.set_kind(kind_id)
	m.target = _player
	if m.has_signal("hit_player"):
		m.hit_player.connect(func(dmg): _player.take_damage(dmg))

func _help_text() -> String:
	return """[QA ROOM]
Teclado:
  WASD  mover · L  level up · Espacio  habilidad
  H  héroe · J  color · T  forma
  1..6  spawn · Shift+1..3  boss
  F/R/M  unlock skills · K  matar todos
  X  blanco · Shift+X  quitar blancos
  C  pollo · G  +500 monedas
  V  cofre · B  élite · N  armas al máximo
  +/-  ±10 hp · Esc  volver

Móvil: joystick izq. + panel dcha."""

## Botón "Acompañante" / tecla C: va pasando por las 9 líneas a nivel 5.
var _companion_i: int = -1

func _next_companion() -> void:
	var ids: Array = GameState.COMPANIONS.keys()
	_companion_i = (_companion_i + 1) % ids.size()
	_player.spawn_companion(ids[_companion_i], GameState.COMPANION_MAX_LEVEL)
	var btn: Button = _touch_panel.find_child("ChickenBtn", true, false)
	if btn:
		btn.text = GameState.companion_stage(ids[_companion_i], GameState.COMPANION_MAX_LEVEL)[2]
