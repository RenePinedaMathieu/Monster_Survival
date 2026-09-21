extends Node2D

## QA Room — sandbox de testing con hotkeys para no tener que jugar
## runs enteras. F6 sobre qa_room.tscn.
##
## Controles:
##   WASD          — moverte
##   Q / E         — zoom out / in
##   Space         — trigger level-up modal (para probar las cartas)
##   1..6          — spawn 1 monster: rat, imp, lizardman, slime, ghost, beholder
##   Shift+1..3    — spawn boss: demon1 / demon2 / demon3
##   F             — desbloquear flying swords (5 espadas orbitando)
##   R             — desbloquear ranged attack (disparos)
##   M             — desbloquear meteoritos
##   K             — kill all monsters on screen
##   +/-           — +/- 10 hp al player
##   Esc           — volver al menú
##
## La lista de controles se dibuja en overlay arriba izquierda para
## que no tengas que memorizarla.

const LEVEL_UP_MENU_SCENE := preload("res://scenes/level_up_menu.tscn")
const MONSTER_SCENE := preload("res://scenes/monster.tscn")

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

func _ready() -> void:
	# Cámara del player como current (misma lógica que sandbox)
	var cam: Camera2D = _player.get_node("Camera2D")
	cam.zoom = Vector2(2.0, 2.0)
	cam.make_current()
	_help_label.text = _help_text()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: int = event.keycode

	if key == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return

	# Space → level up modal
	if key == KEY_SPACE:
		var menu = LEVEL_UP_MENU_SCENE.instantiate()
		add_child(menu)
		menu.show_for(_player)
		return

	# Shift+N → boss demon
	if event.shift_pressed and BOSS_KEYS.has(key):
		_spawn_monster(BOSS_KEYS[key], true)
		return
	# N → regular monster
	if SPAWN_KEYS.has(key):
		_spawn_monster(SPAWN_KEYS[key], false)
		return

	# Unlocks
	if key == KEY_F and _player.has_method("apply_upgrade"):
		_player.apply_upgrade("flying_swords")
	elif key == KEY_R and _player.has_method("apply_upgrade"):
		_player.apply_upgrade("ranged_bonus")
	elif key == KEY_M and _player.has_method("apply_upgrade"):
		_player.apply_upgrade("meteors")

	# Kill all monsters
	if key == KEY_K:
		for m in get_tree().get_nodes_in_group("monster"):
			if m.has_method("take_damage"):
				m.take_damage(9999.0)

	# HP tweak
	if key == KEY_EQUAL or key == KEY_PLUS:
		_player.heal(10.0)
	elif key == KEY_MINUS:
		_player.take_damage(10.0)

func _spawn_monster(kind_id: String, is_boss: bool) -> void:
	var m = MONSTER_SCENE.instantiate()
	# Spawn en ring alrededor del player, dirección random
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
	return """[QA ROOM — hotkeys]
WASD  mover
Q/E   zoom
Space level up modal
1..6  spawn: rat/imp/lizard/slime/ghost/beholder
Shift+1..3  spawn boss: demon1/2/3
F     unlock flying swords
R     unlock ranged
M     unlock meteoros
K     matar todos
+/-   +/- 10 hp
Esc   volver al menú"""
