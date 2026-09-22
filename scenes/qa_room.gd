extends Node2D

## QA Room — sandbox de testing con hotkeys de teclado + panel táctil
## para probar desde el teléfono. F6 sobre qa_room.tscn en el editor,
## o desde el menú principal → Opciones → QA ROOM (DEV).
##
## Controles teclado:
##   WASD          — moverte (o joystick táctil izquierda en móvil)
##   Q / E         — zoom out / in
##   Space         — trigger level-up modal
##   1..6          — spawn 1 monster: rat, imp, lizardman, slime, ghost, beholder
##   Shift+1..3    — spawn boss: demon1 / demon2 / demon3
##   F / R / M     — unlock flying swords / ranged / meteoros
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
	var cam: Camera2D = _player.get_node("Camera2D")
	cam.zoom = Vector2(2.0, 2.0)
	cam.make_current()
	_help_label.text = _help_text()

	# Joystick táctil izquierdo — mismo que se usa en el gameplay real
	var tc = TOUCH_CONTROLS_SCENE.instantiate()
	add_child(tc)
	if _player.has_method("set_touch_input"):
		tc.move_input.connect(_player.set_touch_input)

	_wire_touch_buttons()

func _wire_touch_buttons() -> void:
	# LEVEL UP / KILL ALL / BACK
	_touch_panel.get_node("Actions/LevelUpBtn").pressed.connect(_trigger_level_up)
	_touch_panel.get_node("Actions/KillAllBtn").pressed.connect(_kill_all)
	_touch_panel.get_node("Actions/BackBtn").pressed.connect(_back_to_menu)

	# Spawns regulares
	_touch_panel.get_node("Spawns/RatBtn").pressed.connect(_spawn_monster.bind("rat", false))
	_touch_panel.get_node("Spawns/ImpBtn").pressed.connect(_spawn_monster.bind("imp", false))
	_touch_panel.get_node("Spawns/LizardBtn").pressed.connect(_spawn_monster.bind("lizardman", false))
	_touch_panel.get_node("Spawns/SlimeBtn").pressed.connect(_spawn_monster.bind("slime_1", false))
	_touch_panel.get_node("Spawns/GhostBtn").pressed.connect(_spawn_monster.bind("ghost_1", false))
	_touch_panel.get_node("Spawns/BeholderBtn").pressed.connect(_spawn_monster.bind("beholder_1", false))

	# Bosses
	_touch_panel.get_node("Bosses/Demon1Btn").pressed.connect(_spawn_monster.bind("demon1", true))
	_touch_panel.get_node("Bosses/Demon2Btn").pressed.connect(_spawn_monster.bind("demon2", true))
	_touch_panel.get_node("Bosses/Demon3Btn").pressed.connect(_spawn_monster.bind("demon3", true))

	# Unlocks
	_touch_panel.get_node("Unlocks/SwordsBtn").pressed.connect(_unlock.bind("flying_swords"))
	_touch_panel.get_node("Unlocks/RangedBtn").pressed.connect(_unlock.bind("ranged_bonus"))
	_touch_panel.get_node("Unlocks/MeteorsBtn").pressed.connect(_unlock.bind("meteors"))

	# HP
	_touch_panel.get_node("HP/HealBtn").pressed.connect(func(): _player.heal(10.0))
	_touch_panel.get_node("HP/DamageBtn").pressed.connect(func(): _player.take_damage(10.0))

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: int = event.keycode

	if key == KEY_ESCAPE:
		_back_to_menu()
		return
	if key == KEY_SPACE:
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

func _kill_all() -> void:
	for m in get_tree().get_nodes_in_group("monster"):
		if m.has_method("take_damage"):
			m.take_damage(9999.0)

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
  WASD  mover · Space  level up
  1..6  spawn · Shift+1..3  boss
  F/R/M  unlock skills · K  matar todos
  +/-  ±10 hp · Esc  volver

Móvil: joystick izq. + panel dcha."""
