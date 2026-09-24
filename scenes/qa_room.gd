extends Node2D

## QA Room — sandbox de testing con hotkeys de teclado + panel táctil
## para probar desde el teléfono. F6 sobre qa_room.tscn en el editor,
## o desde el menú principal → Opciones → QA ROOM (DEV).
##
## Controles teclado:
##   WASD          — moverte (o joystick táctil izquierda en móvil)
##   Q / E         — zoom out / in
##   L             — trigger level-up modal (Espacio = habilidad activa)
##   1..6          — spawn 1 monster: rat, imp, lizardman, slime, ghost, beholder
##   Shift+1..3    — spawn boss: demon1 / demon2 / demon3
##   F / R / M     — unlock flying swords / ranged / meteoros
##   C             — spawnear el pollo acompañante (sin comprarlo)
##   G             — +500 monedas para probar la tienda
##   K             — kill all monsters
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

func _ready() -> void:
	_help_label.text = _help_text()

	# Joystick táctil izquierdo — mismo que se usa en el gameplay real
	var tc = TOUCH_CONTROLS_SCENE.instantiate()
	add_child(tc)
	if _player.has_method("set_touch_input"):
		tc.move_input.connect(_player.set_touch_input)

	_wire_touch_buttons()
	_style_panels()

	Screen.layout_changed.connect(_apply_layout)
	_apply_layout(Screen.compact)

## En teléfono: panel más angosto y sin la ayuda de teclado (tapa el
## juego y en el celu no sirve).
func _apply_layout(compact: bool) -> void:
	_touch_panel.offset_left = -208.0 if compact else -260.0
	$UI/HelpBg.visible = not compact
	_help_label.visible = not compact

## Mismo estilo que el resto de la UI (rpg_theme.gd): madera + verdes.
func _style_panels() -> void:
	_touch_panel.add_theme_stylebox_override("panel", RpgTheme.wood_box(9.0, 9.0))
	$UI/HelpBg.color = Color(0.227, 0.157, 0.114, 0.85)
	RpgTheme.style_light_label(_help_label, 12)
	$UI/TouchPanel/Content.add_theme_constant_override("separation", 4)
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
	root.get_node("Unlocks/ChickenBtn").pressed.connect(_player.spawn_companion.bind("chicken"))
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
		_player.spawn_companion("chicken")
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
	elif key == KEY_EQUAL or key == KEY_PLUS:
		_player.heal(10.0)
	elif key == KEY_MINUS:
		_player.take_damage(10.0)

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

func _kill_all() -> void:
	for m in get_tree().get_nodes_in_group("monster"):
		if m.has_method("take_damage"):
			m.take_damage(9999.0, "qa")

func _back_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

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
  1..6  spawn · Shift+1..3  boss
  F/R/M  unlock skills · K  matar todos
  C  pollo · G  +500 monedas
  V  cofre · B  élite · N  armas al máximo
  +/-  ±10 hp · Esc  volver

Móvil: joystick izq. + panel dcha."""
