extends Node2D

## Plaza del pueblo: la portada de la tienda, que crece con lo que el
## jugador logra (arte del pack "Market Square" de Craftpix, armado con
## tools/build_plaza.py). Coordenadas en píxeles de base.png (560x320);
## la escala la pone shop_menu.gd.
##   Compras  -> los puestos se llenan: el mago (MEJORAS) con los niveles
##               del árbol, el armero (PODERES) con los poderes comprados y
##               la frutera (ACOMPAÑANTES) con los animales que tienes.
##   Logros   -> más ciudadanos caminando (de 1 a 5).
##   Mapas    -> Pradera: músicos; Desierto: panadería con mesas;
##               Pantano: estandartes en el muro y velas.
##   Héroes   -> GAROTH siempre; ELARA y DOREN cuando los ganas, en su color.

const BASE := "res://assets/ui/plaza/base.png"
const PIECES := "res://assets/ui/plaza/pieces/%s.png"
const NPC := "res://assets/ui/plaza/npc/%s.png"
const SIZE := Vector2(560, 320)

## Etapas de cada puesto: piezas [nombre, x, y] (esquina sup. izq.).
const STAGES: Dictionary = {
	"magic": [
		[["magic_table", 62, 100]],
		[["tent_empty", 44, 30], ["magic_table", 62, 100]],
		[["tent_full", 40, 20]],
		[["tent_full", 40, 20]],
	],
	"weapon": [
		[["weapon_table", 430, 100]],
		[["awning_blue", 414, 24], ["weapon_table", 430, 100]],
		[["weapon_full", 400, 14]],
		[["weapon_full", 400, 14], ["armor_a", 362, 100]],
	],
	"fruit": [
		[["fruit_crates", 46, 214]],
		[["fruit_frame", 56, 196]],
		[["fruit_full", 50, 182]],
		[["fruit_full", 50, 182], ["cart", 156, 222]],
	],
}
## Desde cuánto sube cada etapa: niveles del árbol, poderes comprados,
## acompañantes que tienes.
const THRESHOLDS: Dictionary = {"magic": [1, 6, 15], "weapon": [1, 3, 5], "fruit": [1, 3, 6]}
## Mercader de cada puesto: [hoja, cuadros, ancho, alto, x, y de los pies].
const TRADERS: Dictionary = {
	"magic": ["magic", 8, 48, 48, 162, 134],
	"weapon": ["weapon", 8, 32, 32, 412, 140],
	"fruit": ["fruits", 9, 32, 32, 108, 226],
}
## La frutera se dibuja sentada tras el mostrador: su lugar depende de
## cómo está armado el puesto en cada etapa.
const FRUIT_FEET: Array = [Vector2(118, 246), Vector2(94, 238), Vector2(92, 236), Vector2(92, 236)]
## Zona clickeable de cada puesto (abre su sección de la tienda).
const STALL_RECTS: Dictionary = {
	"magic": Rect2(30, 14, 160, 130), "weapon": Rect2(356, 10, 180, 140), "fruit": Rect2(40, 176, 130, 110),
}
## Por dónde caminan los ciudadanos (sin pisar los puestos).
const WALK_AREA := Rect2(170, 120, 210, 130)
const CITIZEN_SPEED := 20.0
const NPC_FPS := 7.0

var _stage: Dictionary = {}
var _anims: Array = []        # [Sprite2D, cuadros, fps, desfase]
var _citizens: Array = []     # {sprite, target, wait, walk_tex, idle_tex}
var _candles: Array = []
var _t: float = 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	refresh()

## Rearma la plaza según el progreso (se llama al volver de la tienda).
func refresh() -> void:
	for c in get_children():
		c.queue_free()
	_anims.clear()
	_citizens.clear()
	_candles.clear()
	var base := Sprite2D.new()
	base.texture = load(BASE)
	base.centered = false
	add_child(base)
	# Lo pegado al suelo y al muro va antes que el mundo con orden por
	# altura (mismo z: manda el orden en el árbol; un z negativo lo
	# dejaba detrás del fondo de la tienda).
	var flat := Node2D.new()
	add_child(flat)
	var world := Node2D.new()
	world.y_sort_enabled = true
	add_child(world)
	_stage = {
		"magic": _stage_for("magic", _skill_levels()),
		"weapon": _stage_for("weapon", _powers_bought()),
		"fruit": _stage_for("fruit", _companions_owned()),
	}
	var wins := func(map_id: String) -> bool: return int(GameState.stats.get("wins_" + map_id, 0)) > 0
	# Pantano: estandartes colgando del muro.
	if wins.call("pantano"):
		for b in [[80, "banner_a"], [160, "banner_b"], [370, "banner_a"], [470, "banner_b"]]:
			flat.add_child(_piece(b[1], b[0], 4))
	if _stage["magic"] >= 3:
		flat.add_child(_piece("rug", 64, 92))
	for stall in STAGES:
		for p in STAGES[stall][_stage[stall]]:
			world.add_child(_piece(p[0], p[1], p[2]))
		var trader: Array = TRADERS[stall]
		var feet := Vector2(trader[4], trader[5])
		if stall == "fruit":
			feet = FRUIT_FEET[_stage["fruit"]]
		world.add_child(_npc(trader[0], trader[1], trader[2], trader[3], feet))
	world.add_child(_piece("crates", 234, 46))
	world.add_child(_piece("barrels", 512, 150))
	if wins.call("pradera"):
		world.add_child(_npc("lute", 6, 32, 32, Vector2(254, 208)))
		world.add_child(_npc("flute", 6, 32, 48, Vector2(312, 208)))
	if wins.call("desierto"):
		world.add_child(_piece("bakery", 420, 192))
		world.add_child(_npc("bread", 12, 32, 32, Vector2(456, 252)))
		world.add_child(_piece("tables", 330, 262))
		var eater := _npc("eater", 8, 32, 32, Vector2(372, 286))
		eater.hframes = 4
		eater.vframes = 2
		world.add_child(eater)
	if wins.call("pantano") or _stage["magic"] >= 3:
		for pos in [Vector2(40, 144), Vector2(156, 156)]:
			_add_candle(world, pos)
	# Ciudadanos: 1 + uno cada 4 logros, hasta 5.
	var n_citizens: int = clampi(1 + GameState.achievements_unlocked.size() / 4, 1, 5)
	for i in range(n_citizens):
		_add_citizen(world, i + 1)
	# Héroes en la entrada de la plaza, cada uno en su color elegido.
	var heroes: Array = ["swordman"]
	for id in ["elara", "doren"]:
		if GameState.is_character_unlocked(id):
			heroes.append(id)
	for i in range(heroes.size()):
		var spr := _hero_sprite(heroes[i])
		if spr != null:
			spr.position = Vector2(272 + (i - (heroes.size() - 1) / 2.0) * 44, 100)
			world.add_child(spr)

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

## Pieza fija; su punto de orden (y-sort) es el borde de abajo.
func _piece(name: String, x: float, y: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(PIECES % name)
	s.centered = false
	s.offset = Vector2(0, -s.texture.get_height())
	s.position = Vector2(x, y + s.texture.get_height())
	return s

## Personaje animado con los pies en `feet`.
func _npc(sheet: String, frames: int, w: int, h: int, feet: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(NPC % sheet)
	s.hframes = frames
	s.centered = false
	s.offset = Vector2(-w / 2.0, -h)
	s.position = feet
	_anims.append([s, frames, NPC_FPS, randf() * 3.0])
	return s

## Vela mágica del pack: 3 cuadros separados 96 px en la hoja.
func _add_candle(world: Node2D, feet: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = load(NPC % "candles")
	s.region_enabled = true
	s.region_rect = Rect2(0, 0, 32, 32)
	s.centered = false
	s.offset = Vector2(-16, -32)
	s.position = feet
	world.add_child(s)
	_candles.append(s)

func _add_citizen(world: Node2D, i: int) -> void:
	var s := Sprite2D.new()
	var walk: Texture2D = load(NPC % ("citizen%d_walk" % i))
	var idle: Texture2D = load(NPC % ("citizen%d_idle" % i))
	s.texture = idle
	s.hframes = 12
	s.vframes = 4
	s.centered = false
	s.offset = Vector2(-16, -30)
	s.position = WALK_AREA.position + Vector2(randf() * WALK_AREA.size.x, randf() * WALK_AREA.size.y)
	world.add_child(s)
	_citizens.append({"sprite": s, "target": s.position, "wait": randf() * 2.0, "walk": walk, "idle": idle, "row": 0})

func _hero_sprite(id: String) -> Sprite2D:
	var entry: Dictionary = load("res://scenes/character_select.gd").find_character(id)
	if not entry.has("idle_sheet"):
		return null
	var s := Sprite2D.new()
	s.texture = load(entry["idle_sheet"])
	s.hframes = maxi(1, s.texture.get_width() / 64)
	s.centered = false
	s.offset = Vector2(-32, -48)
	_anims.append([s, s.hframes, 8.0, randf() * 2.0])
	return s

func stall_at(local: Vector2) -> String:
	for stall in STALL_RECTS:
		if STALL_RECTS[stall].has_point(local):
			return stall
	return ""

func _process(delta: float) -> void:
	_t += delta
	for a in _anims:
		var s: Sprite2D = a[0]
		if is_instance_valid(s):
			s.frame = int((_t + a[3]) * a[2]) % (s.hframes * s.vframes)
	for c in _candles:
		if is_instance_valid(c):
			c.region_rect.position.x = 96.0 * (int(_t * 6.0) % 3)
	for c in _citizens:
		_tick_citizen(c, delta)

## Camina hacia un punto al azar, se queda un rato y elige otro.
func _tick_citizen(c: Dictionary, delta: float) -> void:
	var s: Sprite2D = c["sprite"]
	if not is_instance_valid(s):
		return
	if c["wait"] > 0.0:
		c["wait"] -= delta
		if s.texture != c["idle"]:
			s.texture = c["idle"]
			s.hframes = 12
		s.frame = c["row"] * 12 + int(_t * 6.0) % 12
		if c["wait"] <= 0.0:
			c["target"] = WALK_AREA.position + Vector2(randf() * WALK_AREA.size.x, randf() * WALK_AREA.size.y)
		return
	var to: Vector2 = c["target"] - s.position
	if to.length() < 2.0:
		c["wait"] = randf_range(1.0, 3.5)
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
