extends Node2D

## El pueblo: la pantalla de inicio (reemplazó al menú). Se camina con
## el héroe elegido (WASD / flechas / control, o tocando el suelo) y
## cada cosa es un lugar; E / Enter / A (o tocarlo) lo usa:
##   Portones del norte  los mapas (Desierto, Pradera, Pantano): al
##                       cruzarlo se elige dificultad y se juega. Un mapa
##                       bloqueado tiene el portón tapado.
##   Portón del sur      el reto diario (también el pregonero de al lado).
##   Toldo rayado        el ranking.
##   Puestos             la tienda: el mago (MEJORAS), el armero
##                       (PODERES) y la frutera (ACOMPAÑANTES).
##   Héroes de la plaza  hablarles cambia de héroe (y se elige su color).
##   Arena               el entrenador da los desafíos; el palco de los
##                       nobles, los logros.
##   Engranaje           opciones, tutorial, créditos (y QA en desarrollo).
## El pueblo crece con el progreso: los puestos se llenan con las
## compras, hay más gente con los logros y cada mapa ganado suma algo
## (Pradera: músicos; Desierto: panadería con mesas; Pantano:
## estandartes y velas).
## Arte: tools/build_village.py (suelo, muros, arena) y
## tools/build_plaza.py (puestos y gente). Interfaz: village_ui.gd.

const Layout := preload("res://assets/ui/village/village_layout.gd")
const HeroScript := preload("res://scenes/village_hero.gd")
const UIScript := preload("res://scenes/village_ui.gd")
const SelectScript := preload("res://scenes/character_select.gd")
const TUTORIAL_SCENE := preload("res://scenes/tutorial_overlay.tscn")

const BASE := "res://assets/ui/village/base.png"
const VPROPS := "res://assets/ui/village/props/%s.png"
const VPIECES := "res://assets/ui/village/pieces/%s.png"
const VNPC := "res://assets/ui/village/npc/%s.png"
const PIECES := "res://assets/ui/plaza/pieces/%s.png"
const NPC := "res://assets/ui/plaza/npc/%s.png"

const GAME_SCENE := "res://scenes/main.tscn"
const SHOP_SCENE := "res://scenes/shop_menu.tscn"
const TRIALS_SCENE := "res://scenes/trials_menu.tscn"
const DAILY_SCENE := "res://scenes/daily_menu.tscn"
const ACHIEVEMENTS_SCENE := "res://scenes/achievements_menu.tscn"
const RANKING_SCENE := "res://scenes/leaderboard_menu.tscn"
const SELF_SCENE := "res://scenes/village.tscn"

## Mapa de cada portón del norte, de izquierda a derecha (Layout.GATES).
const GATE_MAPS: Array = ["desierto", "pradera", "pantano"]
const SPAWN := Vector2(520, 214)

## Puestos: piezas [nombre, x, y] (esquina sup. izq.) por etapa, el
## mercader [hoja, cuadros, ancho, alto, pies] y la zona que se toca.
const STALLS: Dictionary = {
	"magic": {
		"tab": 0, "label": "MEJORAS", "rect": Rect2(90, 64, 160, 130), "use": Vector2(222, 202),
		"stages": [
			[["magic_table", 122, 150]],
			[["tent_empty", 104, 80], ["magic_table", 122, 150]],
			[["tent_full", 100, 70]],
			[["tent_full", 100, 70]],
		],
		"trader": ["magic", 8, 48, 48, Vector2(222, 184)],
	},
	"weapon": {
		"tab": 1, "label": "PODERES", "rect": Rect2(310, 70, 180, 140), "use": Vector2(366, 216),
		"stages": [
			[["weapon_table", 384, 160]],
			[["awning_blue", 368, 84], ["weapon_table", 384, 160]],
			[["weapon_full", 354, 74]],
			[["weapon_full", 354, 74], ["armor_a", 316, 160]],
		],
		"trader": ["weapon", 8, 32, 32, Vector2(366, 200)],
	},
	"fruit": {
		"tab": 2, "label": "ACOMPAÑANTES", "rect": Rect2(554, 74, 130, 110), "use": Vector2(614, 194),
		"stages": [
			[["fruit_crates", 560, 112]],
			[["fruit_frame", 570, 94]],
			[["fruit_full", 564, 80]],
			[["fruit_full", 564, 80], ["cart", 670, 120]],
		],
		"trader": ["fruits", 9, 32, 32, Vector2(632, 144)],
	},
}
## La frutera se dibuja sentada tras el mostrador: su lugar depende de
## cómo está armado el puesto en cada etapa.
const FRUIT_FEET: Array = [Vector2(632, 144), Vector2(608, 136), Vector2(606, 134), Vector2(606, 134)]
## Desde cuánto sube cada etapa: niveles del árbol, poderes comprados,
## acompañantes que tienes.
const THRESHOLDS: Dictionary = {"magic": [1, 6, 15], "weapon": [1, 3, 5], "fruit": [1, 3, 6]}
## Dónde esperan los otros héroes: el rincón libre junto a la arena
## (los puestos llenos tapan el resto de la plaza).
const HERO_SPOTS: Array = [Vector2(792, 172), Vector2(826, 204)]
## Por dónde pasean los ciudadanos.
const CITIZEN_AREA := Rect2(100, 100, 760, 180)
const CITIZEN_SPEED := 22.0
const NPC_FPS := 7.0
const USE_RADIUS := 30.0

var hero: CharacterBody2D
var ui: CanvasLayer
var _world: Node2D
var _flat: Node2D
var _sorted: Node2D
var _walls: StaticBody2D
var _astar := AStarGrid2D.new()
var _camera: Camera2D
var _cam_focus := Vector2.INF        # el tutorial mueve la cámara a un lugar
var _spots: Array = []               # lugares que se usan (ver _add_spot)
var _near: Dictionary = {}           # el lugar al lado del héroe
var _pending: Dictionary = {}        # lugar tocado: se usa al llegar
var _gate_armed: Array = []          # el portón se abre una vez por entrada
var _south_armed: bool = true
var _anims: Array = []               # [Sprite2D, cuadros, fps, desfase, fila]
var _citizens: Array = []
var _candles: Array = []
var _hero_npcs: Array = []
var _t: float = 0.0
var _leaving: bool = false
var _busy: bool = false              # tutorial abierto

func _ready() -> void:
	# Volver al pueblo corta el reto diario y los desafíos.
	GameState.daily_active = false
	GameState.trial_active = ""
	GameState.shop_return_scene = SELF_SCENE
	Audio.play_music("character_select", 1200)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_world = Node2D.new()
	add_child(_world)
	var base := Sprite2D.new()
	base.texture = load(BASE)
	base.centered = false
	_world.add_child(base)
	_flat = Node2D.new()
	_world.add_child(_flat)
	_sorted = Node2D.new()
	_sorted.y_sort_enabled = true
	_world.add_child(_sorted)
	_walls = StaticBody2D.new()
	_world.add_child(_walls)
	_build_grid()

	_build_arena()
	_build_plaza()
	_build_gates()

	hero = CharacterBody2D.new()
	hero.set_script(HeroScript)
	hero.hero_id = GameState.village_hero
	_sorted.add_child(hero)
	hero.global_position = SPAWN if GameState.village_spawn == Vector2.INF else GameState.village_spawn
	GameState.village_spawn = Vector2.INF
	hero.arrived.connect(_on_arrived)
	_place_hero_npcs()

	_camera = Camera2D.new()
	_world.add_child(_camera)
	_camera.make_current()

	ui = CanvasLayer.new()
	ui.name = "UI"
	ui.set_script(UIScript)
	add_child(ui)
	ui.setup(self)
	Screen.layout_changed.connect(func(_c): _fit_camera())
	_fit_camera()
	_camera.position = _camera_target()
	_camera.reset_smoothing()

	ui.show_title_if_needed(_maybe_tutorial)

# ── Mundo ─────────────────────────────────────────────────────────

## Choque y caminos desde la grilla del generador: filas de celdas
## sólidas seguidas se juntan en un solo rectángulo.
func _build_grid() -> void:
	var grid: PackedStringArray = Layout.GRID
	var c: int = Layout.CELL
	_astar.region = Rect2i(0, 0, grid[0].length(), grid.size())
	_astar.cell_size = Vector2(c, c)
	_astar.offset = Vector2(c / 2.0, c / 2.0)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	for y in range(grid.size()):
		var row: String = grid[y]
		var x := 0
		while x < row.length():
			if row[x] != "#":
				x += 1
				continue
			var x0 := x
			while x < row.length() and row[x] == "#":
				_astar.set_point_solid(Vector2i(x, y))
				x += 1
			_add_shape(Rect2(x0 * c, y * c, (x - x0) * c, c))

func _add_shape(r: Rect2) -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	shape.shape = rect
	shape.position = r.get_center()
	_walls.add_child(shape)

## Algo sólido puesto encima (puesto, barricada, alguien quieto).
func _add_solid(r: Rect2) -> void:
	_add_shape(r)
	var c: float = Layout.CELL
	for y in range(int(r.position.y / c), int(ceilf(r.end.y / c))):
		for x in range(int(r.position.x / c), int(ceilf(r.end.x / c))):
			if _astar.is_in_boundsv(Vector2i(x, y)):
				_astar.set_point_solid(Vector2i(x, y))

## Pieza fija ordenada por su borde de abajo; con `feet` su franja de
## abajo es sólida.
func _piece(path: String, x: float, y: float, feet: bool = true) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(path)
	s.centered = false
	var h: int = s.texture.get_height()
	s.offset = Vector2(0, -h)
	s.position = Vector2(x, y + h)
	_sorted.add_child(s)
	if feet:
		var fh: float = clampf(h / 3.0, 6.0, 14.0)
		_add_solid(Rect2(x + 2, y + h - fh, s.texture.get_width() - 4, fh))
	return s

## Personaje animado con los pies en `feet` (fila `row` de su hoja).
## `solid`: ocupa su lugar (no se lo atraviesa).
func _npc(path: String, frames: int, w: int, h: int, feet: Vector2, row: int = 0, solid: bool = true, foot_y: float = -1.0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(path)
	s.hframes = frames
	s.vframes = maxi(1, s.texture.get_height() / h)
	s.centered = false
	s.offset = Vector2(-w / 2.0, -h + (2.0 if foot_y < 0.0 else foot_y))
	s.position = feet
	_sorted.add_child(s)
	_anims.append([s, frames, NPC_FPS, randf() * 3.0, row])
	if solid:
		_add_solid(Rect2(feet.x - 7, feet.y - 6, 14, 7))
	return s

## Lugar que se usa: `rect` es lo que se toca, `use` donde se para el
## héroe, `face` hacia dónde mira y `action` lo que hace.
func _add_spot(id: String, label: String, rect: Rect2, use: Vector2, face: String, action: Callable) -> Dictionary:
	var spot := {"id": id, "label": label, "rect": rect, "use": use, "face": face, "action": action}
	_spots.append(spot)
	return spot

func _build_arena() -> void:
	for p in Layout.PROPS:
		var s := Sprite2D.new()
		s.texture = load(VPROPS % p["name"])
		s.centered = false
		s.offset = Vector2(0, -p["h"])
		s.position = Vector2(p["x"], p["y"] + p["h"])
		_sorted.add_child(s)
	# Arqueros tirándole a los blancos, muñecos de práctica, dos
	# luchadores en el ring y dos descansando en las bancas.
	_npc(VNPC % "archer1", 6, 32, 32, Vector2(1008, 126))
	_npc(VNPC % "archer2", 6, 32, 32, Vector2(1040, 126))
	_npc(VNPC % "mannequin1", 4, 32, 32, Vector2(1000, 178))
	_npc(VNPC % "mannequin3", 4, 32, 32, Vector2(1030, 178), 1)
	_npc(VNPC % "fighter1", 6, 64, 64, Vector2(1140, 140), 2, false, 18.0)
	_npc(VNPC % "fighter3", 6, 64, 64, Vector2(1178, 140), 0, false, 18.0)
	# Sentados: se ordenan después de las bancas para quedar encima.
	var sit1 := _npc(VNPC % "sit1", 2, 32, 32, Vector2(1184, 236), 0, false)
	sit1.offset.y -= 236 - 208
	var sit2 := _npc(VNPC % "sit2", 4, 32, 32, Vector2(1120, 236), 0, false)
	sit2.offset.y -= 236 - 224
	# Los nobles del palco (los logros).
	_npc(VNPC % "noble_man", 8, 32, 48, Vector2(1136, 80), 0, false)
	_npc(VNPC % "noble_old", 7, 48, 48, Vector2(1160, 80), 0, false)
	_npc(VNPC % "noble_woman", 8, 32, 48, Vector2(1184, 80), 0, false)
	_add_spot("achievements", "LOGROS", Rect2(1100, 6, 120, 76), Vector2(1160, 86), "back", _go.bind(ACHIEVEMENTS_SCENE))
	# El entrenador, recién entrando por la puerta de la cerca.
	_npc(VNPC % "trainer", 4, 32, 32, Vector2(1040, 196))
	_add_spot("trials", "DESAFÍOS", Rect2(1020, 160, 40, 40), Vector2(1040, 212), "back", _go.bind(TRIALS_SCENE))

func _build_plaza() -> void:
	var stage := {
		"magic": _stage_for("magic", _skill_levels()),
		"weapon": _stage_for("weapon", _powers_bought()),
		"fruit": _stage_for("fruit", _companions_owned()),
	}
	var wins := func(map_id: String) -> bool: return int(GameState.stats.get("wins_" + map_id, 0)) > 0
	for id in STALLS:
		var st: Dictionary = STALLS[id]
		for p in st["stages"][stage[id]]:
			_piece(PIECES % p[0], p[1], p[2])
		var tr: Array = st["trader"]
		var feet: Vector2 = tr[4] if id != "fruit" else FRUIT_FEET[stage["fruit"]]
		_npc(NPC % tr[0], tr[1], tr[2], tr[3], feet, 0, false)
		_add_spot(id, st["label"], st["rect"], st["use"], "back", _open_shop.bind(st["tab"]))
	if stage["magic"] >= 3:
		var rug := Sprite2D.new()
		rug.texture = load(PIECES % "rug")
		rug.centered = false
		rug.position = Vector2(124, 142)
		_flat.add_child(rug)
	_piece(PIECES % "barrels", 834, 84)
	_piece(PIECES % "crates", 770, 236)
	# Pradera: músicos junto al camino del medio.
	if wins.call("pradera"):
		_npc(NPC % "lute", 6, 32, 32, Vector2(380, 250))
		_npc(NPC % "flute", 6, 32, 48, Vector2(410, 252))
	# Desierto: panadería con mesas y un comensal.
	if wins.call("desierto"):
		_piece(PIECES % "bakery", 56, 200)
		_npc(NPC % "bread", 12, 32, 32, Vector2(92, 260), 0, false)
		_piece(PIECES % "tables", 140, 238)
		var eater := _npc(NPC % "eater", 8, 32, 32, Vector2(182, 262), 0, false)
		eater.hframes = 4
		eater.vframes = 2
	# Pantano: estandartes en el muro y velas.
	if wins.call("pantano"):
		var i := 0
		for x in [150, 214, 360, 440, 596, 676, 818]:
			var b := Sprite2D.new()
			b.texture = load(PIECES % ("banner_a" if i % 2 == 0 else "banner_b"))
			b.centered = false
			b.position = Vector2(x, 6)
			_flat.add_child(b)
			i += 1
	if wins.call("pantano") or stage["magic"] >= 3:
		for pos in [Vector2(100, 196), Vector2(214, 206)]:
			_add_candle(pos)
	# Ranking: el toldo rayado con su escribana, junto al portón sur.
	var awning := _piece(VPIECES % "awning", 584, 196)
	awning.z_index = 0
	_npc(VNPC % "servant", 7, 32, 48, Vector2(628, 270), 0, true, 4.0)
	_piece(VPIECES % "banner_tall", 680, 206, false)
	_add_spot("ranking", "RANKING", Rect2(580, 190, 96, 90), Vector2(628, 284), "back", _go.bind(RANKING_SCENE))
	# Reto diario: el pregonero junto al portón sur.
	_npc(VNPC % "noble_man", 8, 32, 48, Vector2(474, 280), 0, true, 4.0)
	_add_spot("daily", "RETO DIARIO", Rect2(456, 236, 36, 50), Vector2(474, 292) + Vector2(14, 0), "side_left", _go.bind(DAILY_SCENE))
	# Ciudadanos: 1 + uno cada 4 logros, hasta 5.
	var n_citizens: int = clampi(1 + GameState.achievements_unlocked.size() / 4, 1, 5)
	for i in range(n_citizens):
		_add_citizen(i + 1)

func _build_gates() -> void:
	for i in range(Layout.GATES.size()):
		var g: Dictionary = Layout.GATES[i]
		var map_id: String = GATE_MAPS[i]
		var cx: float = g["x"] + g["w"] / 2.0
		_gate_armed.append(true)
		if not GameState.is_map_unlocked(map_id):
			_piece(VPIECES % "barricade", cx - 18, 18, false)
			_add_solid(Rect2(g["x"], 30, g["w"], 16))
		var spot := _add_spot("gate:" + map_id, GameState.MAPS[map_id]["name"].to_upper(), Rect2(g["x"] - 8, 0, g["w"] + 16, 70),
			Vector2(cx, 60), "back", _open_gate.bind(map_id))
		spot["prompt"] = Vector2(cx, 100)   # abajo: arriba está el nombre del portón

func _add_candle(feet: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = load(NPC % "candles")
	s.region_enabled = true
	s.region_rect = Rect2(0, 0, 32, 32)
	s.centered = false
	s.offset = Vector2(-16, -32)
	s.position = feet
	_sorted.add_child(s)
	_candles.append(s)

func _add_citizen(i: int) -> void:
	var s := Sprite2D.new()
	var walk: Texture2D = load(NPC % ("citizen%d_walk" % i))
	var idle: Texture2D = load(NPC % ("citizen%d_idle" % i))
	s.texture = idle
	s.hframes = 12
	s.vframes = 4
	s.centered = false
	s.offset = Vector2(-16, -30)
	s.position = _random_free_point()
	_sorted.add_child(s)
	_citizens.append({"sprite": s, "path": PackedVector2Array(), "wait": randf() * 2.0, "walk": walk, "idle": idle, "row": 0})

func _random_free_point() -> Vector2:
	for _i in range(30):
		var p := CITIZEN_AREA.position + Vector2(randf() * CITIZEN_AREA.size.x, randf() * CITIZEN_AREA.size.y)
		var cell := Vector2i(p / Layout.CELL)
		if not _astar.is_point_solid(cell):
			return _astar.get_point_position(cell)
	return SPAWN

## Los héroes desbloqueados que no estás usando esperan en la plaza.
func _place_hero_npcs() -> void:
	for n in _hero_npcs:
		n.queue_free()
	_hero_npcs.clear()
	_spots = _spots.filter(func(s): return not String(s["id"]).begins_with("hero:"))
	var k := 0
	for c in SelectScript.CHARACTERS:
		var id: String = c["id"]
		if id == GameState.village_hero or not GameState.is_character_unlocked(id) or k >= HERO_SPOTS.size():
			continue
		var pos: Vector2 = HERO_SPOTS[k]
		k += 1
		var color: Dictionary = HeroScript.PLAYER_SCRIPT.HERO_CLASSES[id]["colors"][GameState.selected_color(id)]
		var s := Sprite2D.new()
		s.texture = load(HeroScript.sheet_path(color, "Idle", "front"))
		s.hframes = maxi(1, s.texture.get_width() / HeroScript.FRAME)
		s.centered = false
		s.offset = Vector2(-HeroScript.FRAME / 2.0, -46)
		s.position = pos
		_sorted.add_child(s)
		_anims.append([s, s.hframes, 8.0, randf() * 2.0, 0])
		_hero_npcs.append(s)
		_add_spot("hero:" + id, c["name"], Rect2(pos.x - 14, pos.y - 30, 28, 34), pos + Vector2(0, 16), "back", _talk_hero.bind(id))

# ── Progreso de los puestos ───────────────────────────────────────

func _stage_for(stall: String, value: int) -> int:
	var st := 0
	for th in THRESHOLDS[stall]:
		if value >= th:
			st += 1
	return st

func _skill_levels() -> int:
	var total := 0
	for k in GameState.shop_levels:
		total += int(GameState.shop_levels[k])
	return total

func _powers_bought() -> int:
	var n := 0
	for id in GameState.SHOP_POWERS:
		if GameState.is_power_unlocked(id):
			n += 1
	return n

func _companions_owned() -> int:
	var n := 0
	for id in GameState.companion_levels:
		if int(GameState.companion_levels[id]) > 0:
			n += 1
	return n

# ── Cámara ────────────────────────────────────────────────────────

## Zoom en medios pasos para que el alto del pueblo llene la pantalla.
func _fit_camera() -> void:
	var vp := get_viewport().get_visible_rect().size
	var z: float = maxf(1.0, floorf(vp.y / Layout.SIZE.y * 2.0) / 2.0)
	_camera.zoom = Vector2(z, z)

func _camera_target() -> Vector2:
	var focus: Vector2 = hero.global_position if _cam_focus == Vector2.INF else _cam_focus
	var half: Vector2 = get_viewport().get_visible_rect().size / _camera.zoom / 2.0
	var out := focus
	for axis in [0, 1]:
		if half[axis] * 2.0 >= Layout.SIZE[axis]:
			out[axis] = Layout.SIZE[axis] / 2.0
		else:
			out[axis] = clampf(focus[axis], half[axis], Layout.SIZE[axis] - half[axis])
	return out

## El tutorial muestra un lugar: la cámara va hasta él (INF = el héroe).
func focus_camera(world_pos: Vector2) -> void:
	_cam_focus = world_pos

func gate_maps() -> Array:
	return GATE_MAPS

func world_to_screen(p: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * p

func spot_position(id: String) -> Vector2:
	for s in _spots:
		if s["id"] == id:
			return s["rect"].get_center()
	return SPAWN

# ── Cada cuadro ───────────────────────────────────────────────────

func _process(delta: float) -> void:
	_t += delta
	_camera.position = _camera.position.lerp(_camera_target(), minf(1.0, delta * 8.0))
	for a in _anims:
		var s: Sprite2D = a[0]
		if is_instance_valid(s):
			s.frame = a[4] * s.hframes + int((_t + a[3]) * a[2]) % a[1]
	for c in _candles:
		c.region_rect.position.x = 96.0 * (int(_t * 6.0) % 3)
	for c in _citizens:
		_tick_citizen(c, delta)
	if _leaving or ui.is_panel_open():
		ui.set_prompt({}, Vector2.ZERO)
		return
	_check_gates()
	_near = _nearest_spot()
	ui.set_prompt(_near, world_to_screen(_near.get("prompt", _near["use"] - Vector2(0, 62))) if not _near.is_empty() else Vector2.ZERO)

func _nearest_spot() -> Dictionary:
	var best: Dictionary = {}
	var best_d := USE_RADIUS
	for s in _spots:
		var d: float = hero.global_position.distance_to(s["use"])
		if d < best_d:
			best_d = d
			best = s
	return best

## Cruzar un portón abre su ventana (una vez por entrada); el del sur
## lleva al reto diario.
func _check_gates() -> void:
	var p: Vector2 = hero.global_position
	for i in range(Layout.GATES.size()):
		var g: Dictionary = Layout.GATES[i]
		var inside: bool = p.y < 40.0 and p.x > g["x"] and p.x < g["x"] + g["w"]
		if inside and _gate_armed[i]:
			_gate_armed[i] = false
			hero.stop()
			_open_gate(GATE_MAPS[i])
		elif not inside and p.y > 52.0:
			_gate_armed[i] = true
		if g["south"]:
			var out: bool = p.y > Layout.SIZE.y - 26.0 and p.x > g["x"] and p.x < g["x"] + g["w"]
			if out and _south_armed:
				_south_armed = false
				_go(DAILY_SCENE, Vector2(g["x"] + g["w"] / 2.0, Layout.SIZE.y - 44.0))
			elif not out:
				_south_armed = true

## Pasea entre puntos al azar de la plaza; se queda un rato y sigue.
func _tick_citizen(c: Dictionary, delta: float) -> void:
	var s: Sprite2D = c["sprite"]
	if c["wait"] > 0.0:
		c["wait"] -= delta
		if s.texture != c["idle"]:
			s.texture = c["idle"]
			s.hframes = 12
		s.frame = c["row"] * 12 + int(_t * 6.0) % 12
		if c["wait"] <= 0.0:
			c["path"] = _path_between(s.position, _random_free_point())
		return
	var path: PackedVector2Array = c["path"]
	if path.is_empty():
		c["wait"] = randf_range(1.5, 4.0)
		return
	var to: Vector2 = path[0] - s.position
	if to.length() < 1.5:
		path.remove_at(0)
		c["path"] = path
		return
	s.position += to.normalized() * minf(CITIZEN_SPEED * delta, to.length())
	# Filas del pack: frente, izquierda, derecha, espalda.
	if absf(to.x) > absf(to.y):
		c["row"] = 1 if to.x < 0.0 else 2
	else:
		c["row"] = 3 if to.y < 0.0 else 0
	if s.texture != c["walk"]:
		s.texture = c["walk"]
		s.hframes = 6
	s.frame = c["row"] * 6 + int(_t * 9.0) % 6

# ── Caminar ───────────────────────────────────────────────────────

func _path_between(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a := _free_cell_near(Vector2i(from / Layout.CELL))
	var b := _free_cell_near(Vector2i(to / Layout.CELL))
	if a == Vector2i(-1, -1) or b == Vector2i(-1, -1):
		return PackedVector2Array()
	var path: PackedVector2Array = _astar.get_point_path(a, b)
	if path.is_empty():
		return path
	path.remove_at(0)   # la celda donde ya está
	# El último punto: el lugar exacto si está libre (no el centro de la celda).
	var end: Vector2 = to if b == Vector2i(to / Layout.CELL) else _astar.get_point_position(b)
	if path.is_empty():
		path.append(end)
	else:
		path[path.size() - 1] = end
	return path

func _free_cell_near(cell: Vector2i) -> Vector2i:
	if _astar.is_in_boundsv(cell) and not _astar.is_point_solid(cell):
		return cell
	for r in range(1, 6):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var c := cell + Vector2i(dx, dy)
				if _astar.is_in_boundsv(c) and not _astar.is_point_solid(c):
					return c
	return Vector2i(-1, -1)

func _unhandled_input(event: InputEvent) -> void:
	if _leaving or _busy or ui.is_panel_open() or not ui.world_input_enabled():
		return
	if event.is_action_pressed("interact") and not _near.is_empty():
		_use(_near)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		ui.show_options()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_walk_to(get_global_mouse_position())
		get_viewport().set_input_as_handled()

## Tocar el suelo: camina hasta ahí. Tocar un lugar: camina hasta su
## frente y lo usa al llegar.
func _walk_to(world_pos: Vector2) -> void:
	_pending = {}
	var target := world_pos
	for s in _spots:
		if s["rect"].has_point(world_pos):
			_pending = s
			target = s["use"]
			break
	if not _pending.is_empty() and hero.global_position.distance_to(target) < USE_RADIUS:
		_use(_pending)
		return
	var path := _path_between(hero.global_position, target)
	if path.is_empty():
		_pending = {}
		return
	hero.walk_path(path)

func _on_arrived() -> void:
	if not _pending.is_empty() and hero.global_position.distance_to(_pending["use"]) < USE_RADIUS:
		var s := _pending
		_pending = {}
		_use(s)

func _use(spot: Dictionary) -> void:
	_pending = {}
	hero.stop()
	hero.face(spot["face"])
	Audio.play_sfx("ui_click")
	spot["action"].call()

# ── Acciones ──────────────────────────────────────────────────────

## Sale a otra pantalla; al volver, el héroe aparece en `back_at` (o
## donde estaba).
func _go(scene: String, back_at: Vector2 = Vector2.INF) -> void:
	if _leaving:
		return
	_leaving = true
	GameState.village_spawn = hero.global_position if back_at == Vector2.INF else back_at
	get_tree().change_scene_to_file(scene)

func _open_shop(tab: int) -> void:
	GameState.shop_open_tab = tab
	_go(SHOP_SCENE)

func _open_gate(map_id: String) -> void:
	hero.controllable = false
	ui.show_gate(map_id)

func _talk_hero(id: String) -> void:
	hero.controllable = false
	ui.show_hero(id)

## Desde la ventana del portón: a jugar.
func play(map_id: String, difficulty: String) -> void:
	GameState.selected_character_id = GameState.village_hero
	GameState.selected_map = map_id
	GameState.selected_difficulty = difficulty
	GameState.pending_character = SelectScript.find_character(GameState.village_hero)
	var i: int = GATE_MAPS.find(map_id)
	var g: Dictionary = Layout.GATES[maxi(i, 0)]
	_go(GAME_SCENE, Vector2(g["x"] + g["w"] / 2.0, 70.0))

## La ficha del héroe eligió jugar con `id` (o cambió el color del actual).
func set_hero(id: String) -> void:
	GameState.set_village_hero(id)
	hero.set_hero(id)
	_place_hero_npcs()

## Se cerró una ventana: el héroe vuelve a moverse. Si estaba en un
## portón, da un paso atrás para no volver a abrirlo.
func panel_closed() -> void:
	hero.controllable = true
	if hero.global_position.y < 52.0:
		hero.walk_path(PackedVector2Array([Vector2(hero.global_position.x, 64.0)]))

## La primera vez, el tutorial (después de la portada).
func _maybe_tutorial() -> void:
	if GameState.tutorial_seen:
		return
	show_tutorial()

func show_tutorial() -> void:
	hero.stop()
	hero.controllable = false
	_busy = true
	var t = TUTORIAL_SCENE.instantiate()
	t.layer = 10
	t.page_shown.connect(func(target: String): focus_camera(ui.mark_world_position(target)))
	t.finished.connect(func():
		focus_camera(Vector2.INF)
		hero.controllable = true
		_busy = false)
	add_child(t)
