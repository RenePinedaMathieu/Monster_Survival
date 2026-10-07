extends SceneTree

## Banco de DPS: compara el daño de los héroes y sus armas. Lo corre
## tools/dps_bench.bat (los tres héroes, tres semillas, y el resumen de
## report.py). A mano:
##   godot --headless --fixed-fps 60 --path . --script res://tools/dps_bench/dps_bench.gd -- hero=doren mode=dummy out=x.jsonl
## Con --fixed-fps el juego corre sin esperar al reloj: 30 s de pelea
## tardan menos de un segundo.
##   hero   swordman / elara / doren
##   mode   dummy  blancos quietos (training_dummy.gd): daño bruto de cada
##                 arma por nivel, en 5 posiciones (1 cerca, 1 lejos, 9
##                 juntos cerca y lejos, rodeado de 12)
##          horde  40 monstruos de una (ratas, lagartos, fantasmas) con la
##                 vida de la oleada de cada etapa: cuánto tarda en
##                 limpiarlos el kit completo
##          boss   demon1 con la vida de la oleada 10: daño por segundo
##   seed   semilla base (las posiciones de la horda y del jefe)
##   only   sólo la etapa con ese nombre (p. ej. only="final nv25")
## El héroe no se mueve ni recibe daño, y usa su habilidad apenas puede
## (salvo la voltereta de DOREN, que sólo mueve). Ojo: escribe el
## guardado del juego (estadísticas, logros): el .bat lo respalda antes.

# load() en _initialize: con --script los autoloads todavía no existen
# cuando se compila este archivo.
var QA: PackedScene
var MONSTER: PackedScene
var Upgrades
var CHEST: Script

const WAVE_SPEED := 1.315
const BOSS_HP := 900.0 * 1.72
const HORDE_KINDS := ["rat_2", "lizardman_2", "ghost_2"]
const HORDE_COUNT := 40
const HORDE_CAP := 3600           # 60 s como mucho

var DummyRec: Script
var GS
var hero := "swordman"
var mode := "dummy"
var out_path := ""
var jobs: Array = []
var ji := -1
var job: Dictionary
var scene = null
var player = null
var frame := 0
var state := "next"
var warm := 120
var measure := 1200
var sink := {}
var dmg0 := {}
var kills0 := 0
var boss = null
var boss_dmg := 0.0
var boss_prev := 0.0
var lines: Array = []
var t_start := 0
var only := ""
var seed_base := 1000

func _initialize() -> void:
	QA = load("res://scenes/qa_room.tscn")
	MONSTER = load("res://scenes/monster.tscn")
	Upgrades = load("res://scenes/upgrades.gd")
	CHEST = load("res://scenes/chest.gd")
	DummyRec = load(get_script().resource_path.get_base_dir() + "/dummy_rec.gd")
	GS = root.get_node("GameState")
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=", true, 1)
		match kv[0]:
			"hero": hero = kv[1]
			"mode": mode = kv[1]
			"out": out_path = kv[1]
			"only": only = kv[1]
			"seed": seed_base = int(kv[1])
	_build_jobs()
	if only != "":
		jobs = jobs.filter(func(j): return j["stage"] == only)
	t_start = Time.get_ticks_msec()
	print("jobs: ", jobs.size())

# ── Configuraciones ─────────────────────────────────────────────

func _evo_of(w: String) -> String:
	for e in Upgrades.EVOLUTIONS:
		if Upgrades.EVOLUTIONS[e]["weapon"] == w:
			return e
	return ""

## Cartas para dejar el arma `w` en la etapa: L1, L2, L3, L5, MAX (L5 +
## sus cartas extra) o EVO (L5 + evolución, sin la pasiva compañera).
func _weapon_cards(w: String, stage: String) -> Array:
	var d: Dictionary = Upgrades.WEAPONS[w]
	var cards: Array = [d["unlock"]]
	var lv: int = {"L1": 1, "L2": 2, "L3": 3}.get(stage, 5)
	for i in range(lv - 1):
		cards.append(d["level"])
	if stage == "MAX":
		for x in d["extras"]:
			for i in range(4):
				cards.append(x)
	return cards

func _build_jobs() -> void:
	var weapons: Array = Upgrades.CLASS_WEAPONS[hero]
	if mode == "dummy":
		var configs: Array = [
			{"name": "ataque", "stage": "T1", "level": 1, "cards": [], "evos": []},
			{"name": "ataque", "stage": "Tmax", "level": 25, "cards": [], "evos": []},
		]
		for w in weapons:
			if w == "escudo_fuerza":
				continue
			var stages := ["L1", "L3", "L5"]
			if not Upgrades.WEAPONS[w]["extras"].is_empty():
				stages.append("MAX")
			stages.append("EVO")
			for st in stages:
				configs.append({"name": w, "stage": st, "level": 1 if st == "L1" else 25,
					"cards": _weapon_cards(w, st), "evos": [_evo_of(w)] if st == "EVO" else []})
		for c in configs:
			for sc in ["1 cerca", "1 lejos", "9 cerca", "9 lejos", "rodeado 12"]:
				var j: Dictionary = c.duplicate()
				j["scenario"] = sc
				jobs.append(j)
		warm = 120
		measure = 1200
	else:
		var free_w: Array = weapons.filter(func(w): return Upgrades.WEAPONS[w]["shop"] == "")
		var kits: Array = [
			{"name": "kit", "stage": "inicio nv1", "level": 1, "cards": [], "evos": [], "wave": 1},
			{"name": "kit", "stage": "temprano nv8", "level": 8, "cards": _many(free_w, "L2"), "evos": [], "wave": 5},
			{"name": "kit", "stage": "medio nv15", "level": 15, "cards": _many(weapons, "L3"), "evos": [], "wave": 10},
			# Las 4 armas a nivel 5 y nada más (20 cartas cada uno): las
			# cartas extra de un arma (más flechas, +1 proyectil, más
			# espadas) compiten con las pasivas, que también tienen todos.
			{"name": "kit", "stage": "final nv25", "level": 25, "cards": _many(weapons, "L5"), "evos": [], "wave": 20},
			{"name": "kit", "stage": "evolucionado", "level": 25, "cards": _many(weapons, "L5"),
				"evos": weapons.map(func(w): return _evo_of(w)), "wave": 20},
		]
		for k in kits:
			k["scenario"] = mode
			jobs.append(k)
		warm = 1
		measure = 1800

func _many(ws: Array, stage: String) -> Array:
	var out: Array = []
	for w in ws:
		out.append_array(_weapon_cards(w, stage))
	return out

# ── Bucle ───────────────────────────────────────────────────────

func _process(_delta: float) -> bool:
	paused = false
	match state:
		"next":
			if scene != null:
				scene.queue_free()
				scene = null
				return false
			ji += 1
			if ji >= jobs.size():
				_finish()
				return true
			_start_job()
			state = "run"
		"run":
			frame += 1
			_tick_job()
			if frame == warm:
				_mark()
			elif mode == "horde" and frame > 10 and (_alive_monsters().is_empty() or frame >= HORDE_CAP):
				_record()
				state = "next"
			elif mode != "horde" and frame >= warm + measure:
				_record()
				state = "next"
	return false

func _start_job() -> void:
	job = jobs[ji]
	seed(seed_base + ji)
	GS.selected_character_id = hero
	GS.start_run()
	scene = QA.instantiate()
	root.add_child(scene)
	current_scene = scene
	player = scene.get_node("Player")
	player.max_hp = 1.0e9
	player.hp = 1.0e9
	player.level = job["level"]
	player._load_swordman_textures()
	player.xp_to_next = 1 << 30
	player.magnet_radius = 0.0
	for c in job["cards"]:
		player.apply_upgrade(c)
	for e in job["evos"]:
		if e != "":
			player.evolve(e)
	frame = 0
	sink = {}
	boss = null
	boss_dmg = 0.0
	if mode == "dummy":
		_place_dummies(job["scenario"])
	elif mode == "horde":
		var w: int = job["wave"]
		var hp_mult: float = (1.0 + (w - 1) * 0.08) * 1.1
		for i in range(HORDE_COUNT):
			var m = _spawn(HORDE_KINDS[i % HORDE_KINDS.size()], randf_range(140.0, 280.0), hp_mult, false)
			m.speed_mult = minf(1.0 + (w - 1) * 0.035, 1.75)

func _place_dummies(sc: String) -> void:
	var pos: Array = []
	match sc:
		"1 cerca": pos = [Vector2(40, 0)]
		"1 lejos": pos = [Vector2(170, 0)]
		"9 cerca", "9 lejos":
			var cx := 60.0 if sc == "9 cerca" else 170.0
			for gx in [-1, 0, 1]:
				for gy in [-1, 0, 1]:
					pos.append(Vector2(cx + gx * 22.0, gy * 22.0))
		"rodeado 12":
			for i in range(12):
				pos.append(Vector2(45, 0).rotated(TAU * i / 12.0))
	for p in pos:
		var d := CharacterBody2D.new()
		d.set_script(DummyRec)
		d.sink = sink
		d.position = player.position + p
		scene.get_node("Monsters").add_child(d)

func _alive_monsters() -> Array:
	return get_nodes_in_group("monster").filter(func(m): return is_instance_valid(m) and not m._dead)

func _spawn(kind: String, dist: float, hp: float, keep_hp: bool) -> Node:
	var m = MONSTER.instantiate()
	var ang := randf() * TAU
	m.position = player.position + Vector2(cos(ang), sin(ang)) * dist
	scene.get_node("Monsters").add_child(m)
	m.set_kind(kind)
	m.target = player
	if keep_hp:
		m.max_hp = hp
	else:
		m.max_hp *= hp
	m.hp = m.max_hp
	m.speed_mult = WAVE_SPEED
	return m

func _tick_job() -> void:
	# Sin cofres ni ventanas que pausen la prueba.
	for n in scene.get_children():
		if n.get_script() == CHEST:
			n.queue_free()
	player.hp = 1.0e9
	if mode != "dummy" and hero != "doren" and player.skill_ready():
		player.use_active_skill()
	if mode == "boss":
		for m in get_nodes_in_group("monster"):
			if is_instance_valid(m) and m._is_minion:
				m.queue_free()
		if boss == null or not is_instance_valid(boss) or boss._dead:
			boss = _spawn("demon1", 180.0, BOSS_HP, true)
			boss_prev = boss.hp
		else:
			var lost: float = boss_prev - boss.hp
			if lost > 0.0 and frame > warm:
				boss_dmg += lost
			boss_prev = boss.hp

func _mark() -> void:
	sink.clear()
	dmg0 = GS.run_stats["damage"].duplicate()
	kills0 = int(GS.run_stats["total_kills"])
	boss_dmg = 0.0

func _record() -> void:
	var secs := (frame - warm) / 60.0 if mode == "horde" else measure / 60.0
	var by := {}
	if mode == "dummy":
		for k in sink:
			by[k] = sink[k] / secs
	else:
		var d: Dictionary = GS.run_stats["damage"]
		for k in d:
			var v: float = float(d[k]) - float(dmg0.get(k, 0.0))
			if v > 0.0:
				by[k] = v / secs
	var total := 0.0
	for v in by.values():
		total += v
	var rec := {"hero": hero, "mode": mode, "config": job["name"], "stage": job["stage"],
		"scenario": job["scenario"], "by": by, "total": total}
	if mode == "horde":
		rec["clear_s"] = secs
		rec["left"] = _alive_monsters().size()
	if mode == "boss":
		rec["boss_dps"] = boss_dmg / secs
	lines.append(JSON.stringify(rec))
	if only != "":
		print("%s %s %s %s total %.1f" % [hero, job["name"], job["stage"], job["scenario"], total])

func _finish() -> void:
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("done in %.1f s" % ((Time.get_ticks_msec() - t_start) / 1000.0))
