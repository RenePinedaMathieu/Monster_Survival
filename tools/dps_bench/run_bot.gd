extends SceneTree

## Partida automática para medir cómo se sube de nivel: juega una run
## real (main.tscn) con el héroe que no muere, va a buscar la
## experiencia más cercana y elige cartas al azar. Anota el nivel al
## terminar cada oleada.
##   godot --headless --fixed-fps 60 --path . --script res://tools/dps_bench/run_bot.gd -- hero=swordman map=pradera seed=1 out=x.jsonl
## Igual que dps_bench.gd escribe el guardado: tools/dps_bench.bat lo
## respalda antes.

const ORB_SEEK := 420.0
const MAX_MINUTES := 30.0

var GS
var hero := "swordman"
var map := "pradera"
var out_path := ""
var seed_v := 1
var _started := false
var _wave := 0
var _t := 0.0
var _rows: Array = []
var _wander := Vector2.RIGHT
var _wander_t := 0.0

func _initialize() -> void:
	GS = root.get_node("GameState")
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=", true, 1)
		match kv[0]:
			"hero": hero = kv[1]
			"map": map = kv[1]
			"out": out_path = kv[1]
			"seed": seed_v = int(kv[1])

func _process(delta: float) -> bool:
	if not _started:
		_started = true
		seed(seed_v)
		GS.tutorial_seen = true
		GS.selected_character_id = hero
		GS.selected_map = map
		GS.selected_difficulty = "normal"
		change_scene_to_file("res://scenes/main.tscn")
		return false
	var main = current_scene
	if main == null or not ("_player" in main) or main._player == null:
		return false
	var player = main._player
	_t += delta
	# Ventanas: la carta al azar y el cofre se cierra solo.
	for n in main.get_children():
		var s: Script = n.get_script()
		if s == null:
			continue
		var path: String = s.resource_path
		if path.ends_with("level_up_menu.gd") and not n._input_locked and not n._current_choices.is_empty():
			n._pick(randi() % n._current_choices.size())
		elif path.ends_with("chest_popup.gd") and n.has_method("_close"):
			n._close()
	player.hp = player.max_hp
	_steer(player, delta)
	if main._current_wave != _wave:
		if _wave > 0:
			_note(main, player, _wave)
		_wave = main._current_wave
	if main._run_over or _t > MAX_MINUTES * 60.0:
		_note(main, player, _wave)
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		f.store_string("\n".join(_rows) + "\n")
		f.close()
		return true
	return false

## Hacia el orbe de experiencia más cercano; si no hay, da vueltas.
func _steer(player, delta: float) -> void:
	var best: Node2D = null
	var best_d := ORB_SEEK
	for o in get_nodes_in_group("xp_orb"):
		if not is_instance_valid(o):
			continue
		var d: float = player.global_position.distance_to(o.global_position)
		if d < best_d:
			best_d = d
			best = o
	if best != null:
		player.set_touch_input((best.global_position - player.global_position).normalized())
		return
	_wander_t -= delta
	if _wander_t <= 0.0:
		_wander_t = 2.0
		_wander = _wander.rotated(randf_range(1.0, 2.5))
	player.set_touch_input(_wander * 0.6)

func _note(main, player, wave: int) -> void:
	var rec := {"hero": hero, "map": map, "wave": wave, "level": player.level,
		"time": snappedf(_t, 0.1), "kills": int(GS.run_stats.get("total_kills", 0)),
		"weapons": player.weapons_owned(), "passives": player.passives_owned()}
	_rows.append(JSON.stringify(rec))
	print("wave %d  level %d  t %.0fs  kills %d" % [wave, player.level, _t, rec["kills"]])
