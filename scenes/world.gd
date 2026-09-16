extends Node2D

## Mundo del survival — dividido en biomas para variar el paisaje
## dentro de la misma run:
##
##   - CORE GRASS: la mayor parte del mundo. Grass con 4 variantes del
##     tileset_florest.png, sampleadas deterministamente por posición.
##   - LAKE: un lago en el noroeste, con transición grass↔water hecha
##     con wang tiles (pretty_grass_to_water). El agua bloquea al
##     player con StaticBody2D en las celdas donde la mayoría de
##     esquinas es agua.
##   - RUINAS DE PIEDRA: un macizo rocoso en el sureste con transición
##     grass↔stone (pretty_grass_3F9B0B_to_stone). Transitable, sólo
##     cambia el vibe visual y concentra props tipo skulls/chests.
##
## Los bordes del mundo siguen siendo paredes invisibles a WORLD_BOUND
## (no cambié esto para no romper el minimap que hardcodea 950.0).
##
## Los props se scatteean POR BIOMA — árboles y trees_couple sólo en
## grass, skulls/chests/piedras grandes en las ruinas. Nada de props
## en agua.
##
## Todo el layout usa un seed fijo (MAP_SEED) — el mapa es el mismo
## en cada run, así los players aprenden dónde está cada bioma.
##
## Wang tile bit ordering — corner-based, 16 tiles:
##   bit 0 = NW corner, bit 1 = NE, bit 2 = SW, bit 3 = SE
## Y el atlas está indexado COLUMN-MAJOR según HANDOFF.md §4:
##   tile mask N está en col=N/4, row=N%4.
## Si al ver el mapa las transiciones se ven cruzadas/rotadas,
## ese mapping es lo primero a tocar (ver _wang_atlas_pos).

const TILE_SIZE := 24
const WORLD_HALF_TILES := 40   # 80×80 tiles
const WORLD_BOUND := 950.0

# ── Biomas ───────────────────────────────────────────────────────

const BIOME_GRASS := 0
const BIOME_WATER := 1
const BIOME_STONE := 2

# Coords TILE (no world) — el centro del mapa es (0,0)
const LAKE_CENTER := Vector2(-24, -20)
const LAKE_RADIUS := 12.0
const RUINS_CENTER := Vector2(22, 15)
const RUINS_RADIUS := 11.0

# El ruido perturba el borde de cada blob para que no sean círculos
# perfectos — le da forma orgánica.
const BIOME_NOISE_FREQ := 0.08
const BIOME_NOISE_STRENGTH := 4.0

const MAP_SEED := 42

# ── Tilesets ─────────────────────────────────────────────────────

const GRASS_TILESET_PATH := "res://assets/tiles/tileset_florest.png"
# 4 regiones del florest que usamos como grass base + subtle variants.
# tileset_florest.png es 288×168 = 12×7 tiles de 24×24. La región (48,24)
# es la que se venía usando; las otras 3 son variantes cercanas para
# romper la repetición sin que se vea disparatado.
const GRASS_REGIONS: Array[Rect2] = [
	Rect2(48, 24, 24, 24),
	Rect2(48, 48, 24, 24),
	Rect2(72, 24, 24, 24),
	Rect2(72, 48, 24, 24),
]
# Peso relativo por variante — sesgamos fuerte hacia la primera para
# que el grass se sienta consistente y las variantes sean "acentos".
const GRASS_WEIGHTS: Array[int] = [72, 10, 10, 8]

# Wang tilesets — 4×4 grid de 96×72 con 1px gap. Ver HANDOFF.md §4.
const WANG_TO_WATER_PATH := "res://assets/tiles/pretty_grass_to_water._grass_color_3F9B0B.png"
const WANG_TO_STONE_PATH := "res://assets/tiles/pretty_grass_3F9B0B_to_stone.png"
const WANG_TILE_SIZE := Vector2(96, 72)
const WANG_GAP := 1

# ── Props ────────────────────────────────────────────────────────

# Cada tupla: [path, cantidad, es_solido, biomas_aceptados]
# biomas_aceptados vacío = sólo grass. Con [BIOME_STONE] sólo ruinas.
const PROP_SPAWNS: Array = [
	# Bosque en la zona de grass
	["res://assets/props/props_tree.png",             55, true,  [BIOME_GRASS]],
	["res://assets/props/props_tree_couple.png",      15, true,  [BIOME_GRASS]],
	["res://assets/props/props_tree_goup.png",        18, true,  [BIOME_GRASS]],
	["res://assets/props/props_grasschest_closed.png", 3, false, [BIOME_GRASS]],
	["res://assets/props/props_sign.png",              3, false, [BIOME_GRASS]],
	# Ruinas: piedras y skulls concentrados acá
	["res://assets/props/props_big_stone.png",        14, true,  [BIOME_STONE]],
	["res://assets/props/props_mid_stone.png",        18, true,  [BIOME_STONE]],
	["res://assets/props/props_small_stone.png",      22, false, [BIOME_STONE]],
	["res://assets/props/props_skull.png",             8, false, [BIOME_STONE]],
	["res://assets/props/props_chest_closed.png",      4, false, [BIOME_STONE]],
]

const NO_SPAWN_RADIUS := 140.0
const SCATTER_RADIUS := 900.0

# ── State ───────────────────────────────────────────────────────

var _cell_biome: Dictionary = {}   # Vector2i(x,y) -> int (BIOME_*)
var _rng: RandomNumberGenerator
var _noise_water: FastNoiseLite
var _noise_stone: FastNoiseLite

func _ready() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = MAP_SEED
	_noise_water = FastNoiseLite.new()
	_noise_water.seed = MAP_SEED
	_noise_water.frequency = BIOME_NOISE_FREQ
	_noise_stone = FastNoiseLite.new()
	# Semilla distinta así lago y ruinas tienen bordes independientes
	_noise_stone.seed = MAP_SEED + 999
	_noise_stone.frequency = BIOME_NOISE_FREQ

	_build_cell_biomes()
	_build_ground()
	_build_water_collision()
	_scatter_props()
	_build_borders()

# ── Biome map ───────────────────────────────────────────────────

## Cell biome usado para: colisión de agua, decidir qué prop puede
## spawnear ahí, y como fallback si un tile queda sin transición.
## La APARIENCIA del tile la decide _wang_mask() por esquinas, no
## por celda — ese es el truco para que las orillas se vean fluidas.
func _build_cell_biomes() -> void:
	for y in range(-WORLD_HALF_TILES, WORLD_HALF_TILES):
		for x in range(-WORLD_HALF_TILES, WORLD_HALF_TILES):
			# Una celda cuenta como water/stone sólo si su CENTRO cae
			# adentro del blob (más estricto que las esquinas).
			var cx := x + 0.5
			var cy := y + 0.5
			if _is_water_at(cx, cy):
				_cell_biome[Vector2i(x, y)] = BIOME_WATER
			elif _is_stone_at(cx, cy):
				_cell_biome[Vector2i(x, y)] = BIOME_STONE
			else:
				_cell_biome[Vector2i(x, y)] = BIOME_GRASS

func _is_water_at(x: float, y: float) -> bool:
	var d := Vector2(x, y).distance_to(LAKE_CENTER)
	var perturb := _noise_water.get_noise_2d(x, y) * BIOME_NOISE_STRENGTH
	return d + perturb < LAKE_RADIUS

func _is_stone_at(x: float, y: float) -> bool:
	var d := Vector2(x, y).distance_to(RUINS_CENTER)
	var perturb := _noise_stone.get_noise_2d(x, y) * BIOME_NOISE_STRENGTH
	return d + perturb < RUINS_RADIUS

# ── Ground rendering ────────────────────────────────────────────

func _build_ground() -> void:
	var grass_tex: Texture2D = load(GRASS_TILESET_PATH)
	var water_tex: Texture2D = load(WANG_TO_WATER_PATH)
	var stone_tex: Texture2D = load(WANG_TO_STONE_PATH)
	var container := Node2D.new()
	container.name = "Ground"
	add_child(container)

	for y in range(-WORLD_HALF_TILES, WORLD_HALF_TILES):
		for x in range(-WORLD_HALF_TILES, WORLD_HALF_TILES):
			var water_mask := _wang_mask(x, y, WATER_CORNER_CHECK)
			var stone_mask := _wang_mask(x, y, STONE_CORNER_CHECK)
			var pos := Vector2(x * TILE_SIZE, y * TILE_SIZE)

			if water_mask > 0:
				var s := _make_wang_sprite(water_tex, water_mask)
				s.position = pos
				container.add_child(s)
			elif stone_mask > 0:
				var s := _make_wang_sprite(stone_tex, stone_mask)
				s.position = pos
				container.add_child(s)
			else:
				var s := _make_grass_sprite(grass_tex, x, y)
				s.position = pos
				container.add_child(s)

# Los "check functions" para las esquinas — se pasan como Callable
# al mask builder para reusar la misma lógica para water y stone.
const WATER_CORNER_CHECK := 0
const STONE_CORNER_CHECK := 1

func _wang_mask(cell_x: int, cell_y: int, kind: int) -> int:
	# Esquinas de la celda en coords de vertex (ints)
	# NW = (cell_x, cell_y), NE = (cell_x+1, cell_y),
	# SW = (cell_x, cell_y+1), SE = (cell_x+1, cell_y+1)
	var mask := 0
	if _corner_is(cell_x,     cell_y,     kind): mask |= 1   # NW
	if _corner_is(cell_x + 1, cell_y,     kind): mask |= 2   # NE
	if _corner_is(cell_x,     cell_y + 1, kind): mask |= 4   # SW
	if _corner_is(cell_x + 1, cell_y + 1, kind): mask |= 8   # SE
	return mask

func _corner_is(vx: int, vy: int, kind: int) -> bool:
	# Un vertex cae en el bioma si el mismo test que usamos para las
	# celdas da true en ese punto. Coords enteras porque los vertices
	# son la esquina exacta entre celdas.
	if kind == WATER_CORNER_CHECK:
		return _is_water_at(float(vx), float(vy))
	return _is_stone_at(float(vx), float(vy))

func _make_wang_sprite(tex: Texture2D, mask: int) -> Sprite2D:
	# HANDOFF.md §4: PixelLab wang tiles son COLUMN-MAJOR:
	# tile mask N en col=N/4, row=N%4.
	var col := mask / 4
	var row := mask % 4
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(
		col * (WANG_TILE_SIZE.x + WANG_GAP),
		row * (WANG_TILE_SIZE.y + WANG_GAP),
		WANG_TILE_SIZE.x,
		WANG_TILE_SIZE.y,
	)
	var s := Sprite2D.new()
	s.texture = atlas
	s.centered = false
	# Los wang tiles son 96×72 y los renderizamos a 24×24 (mismo grid
	# que el florest). Escala no-uniforme (0.25 h, 0.333 v) — genera un
	# aplastamiento vertical leve que en pixel art se tolera bien. Si
	# se ve mal, considerar cambiar el grid a 24×18 acá abajo y en
	# TILE_SIZE — pero ojo que afecta cámara, minimap y todo el resto.
	s.scale = Vector2(
		float(TILE_SIZE) / WANG_TILE_SIZE.x,
		float(TILE_SIZE) / WANG_TILE_SIZE.y,
	)
	return s

func _make_grass_sprite(tex: Texture2D, x: int, y: int) -> Sprite2D:
	# Elegimos la variante con hash determinista de la posición: el
	# mismo tile siempre agarra la misma variante entre runs (útil
	# para debug), y no depende del RNG que también usa el prop
	# scatter (así podemos re-seedear eso sin cambiar el ground).
	var h := (hash(Vector2i(x, y)) & 0x7fffffff)
	var total := 0
	for w in GRASS_WEIGHTS:
		total += w
	var pick := h % total
	var acc := 0
	var idx := 0
	for i in range(GRASS_WEIGHTS.size()):
		acc += GRASS_WEIGHTS[i]
		if pick < acc:
			idx = i
			break
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = GRASS_REGIONS[idx]
	var s := Sprite2D.new()
	s.texture = atlas
	s.centered = false
	return s

# ── Water collision ─────────────────────────────────────────────

## Sólo bloqueamos las celdas cuyo centro cae dentro del lago (o sea,
## las que _build_cell_biomes clasificó como BIOME_WATER). Las celdas
## de orilla — que renderizan wang tile con transición pero cuyo
## centro está en grass — quedan caminables. Así el player puede
## pisar el borde sin frustración.
func _build_water_collision() -> void:
	var body := StaticBody2D.new()
	body.name = "WaterCollision"
	body.collision_layer = 4
	body.collision_mask = 0
	add_child(body)
	for pos in _cell_biome.keys():
		if _cell_biome[pos] != BIOME_WATER:
			continue
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(TILE_SIZE, TILE_SIZE)
		col.shape = shape
		col.position = Vector2(
			pos.x * TILE_SIZE + TILE_SIZE * 0.5,
			pos.y * TILE_SIZE + TILE_SIZE * 0.5,
		)
		body.add_child(col)

# ── Props ───────────────────────────────────────────────────────

func _scatter_props() -> void:
	var container := Node2D.new()
	container.name = "Props"
	container.y_sort_enabled = true
	add_child(container)
	for entry in PROP_SPAWNS:
		var path: String = entry[0]
		var count: int = entry[1]
		var solid: bool = entry[2]
		var target_biomes: Array = entry[3]
		var tex: Texture2D = load(path)
		var placed := 0
		var attempts := 0
		# Damos hasta 30 intentos por prop antes de descartar — si un
		# bioma es chico (ruinas) puede pasar que muchos intentos caigan
		# afuera, pero no queremos loopear infinito si un prop pide más
		# de los que caben.
		while placed < count and attempts < count * 30:
			attempts += 1
			var p := Vector2(
				_rng.randf_range(-SCATTER_RADIUS, SCATTER_RADIUS),
				_rng.randf_range(-SCATTER_RADIUS, SCATTER_RADIUS),
			)
			if p.length() < NO_SPAWN_RADIUS:
				continue
			var tx := int(round(p.x / TILE_SIZE))
			var ty := int(round(p.y / TILE_SIZE))
			var biome_here: int = _cell_biome.get(Vector2i(tx, ty), BIOME_GRASS)
			if not (biome_here in target_biomes):
				continue
			var prop_root := _make_prop(tex, solid)
			prop_root.position = p
			container.add_child(prop_root)
			placed += 1

func _make_prop(tex: Texture2D, solid: bool) -> Node2D:
	var root := Node2D.new()
	var sprite := Sprite2D.new()
	sprite.texture = tex
	# Ancla los sprites por la base para que el y-sort funcione bien
	# y no se solapen con la cabeza cortada.
	sprite.offset = Vector2(0, -tex.get_height() * 0.5)
	root.add_child(sprite)
	if solid:
		var body := StaticBody2D.new()
		body.collision_layer = 4
		body.collision_mask = 0
		var col := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = max(4.0, tex.get_width() * 0.12)
		col.shape = shape
		col.position = Vector2(0, -4)
		body.add_child(col)
		root.add_child(body)
	return root

# ── Border walls ────────────────────────────────────────────────

func _build_borders() -> void:
	var container := StaticBody2D.new()
	container.name = "Borders"
	container.collision_layer = 4
	container.collision_mask = 0
	add_child(container)
	var walls: Array = [
		[Vector2( 0,               -WORLD_BOUND - 20), Vector2(WORLD_BOUND * 2 + 80, 40)],  # top
		[Vector2( 0,                WORLD_BOUND + 20), Vector2(WORLD_BOUND * 2 + 80, 40)],  # bottom
		[Vector2(-WORLD_BOUND - 20, 0),                Vector2(40, WORLD_BOUND * 2 + 80)],  # left
		[Vector2( WORLD_BOUND + 20, 0),                Vector2(40, WORLD_BOUND * 2 + 80)],  # right
	]
	for wall in walls:
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = wall[1]
		col.shape = shape
		col.position = wall[0]
		container.add_child(col)
