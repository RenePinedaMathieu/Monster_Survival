extends Node2D

## Mundo del survival: ground tileado + props scatter con colisión
## para árboles/piedras + paredes invisibles en el borde del mapa
## para que no puedas caer al vacío.

const TILE_SIZE := 24
const WORLD_HALF_TILES := 40   # 80×80 tiles

# Región del tileset que usamos como grass base.
const GRASS_TILE_REGION := Rect2(48, 24, 24, 24)

# Bordes del mundo — paredes invisibles a esta distancia del origen.
const WORLD_BOUND := 950.0

# Props que se esparcen. Cada tupla: (path, cantidad, es_solido)
# solido = agrega StaticBody2D con círculo en la base del sprite.
const PROP_SPAWNS: Array = [
	["res://assets/props/props_tree.png",             40, true],
	["res://assets/props/props_tree_couple.png",      15, true],
	["res://assets/props/props_tree_goup.png",        15, true],
	["res://assets/props/props_big_stone.png",        12, true],
	["res://assets/props/props_mid_stone.png",        14, true],
	["res://assets/props/props_small_stone.png",      18, false],
	["res://assets/props/props_skull.png",             6, false],
	["res://assets/props/props_sign.png",              3, false],
	["res://assets/props/props_chest_closed.png",      4, false],
	["res://assets/props/props_grasschest_closed.png", 3, false],
]

const SCATTER_RADIUS := 900.0
const NO_SPAWN_RADIUS := 140.0

func _ready() -> void:
	_build_ground()
	_scatter_props()
	_build_borders()

func _build_ground() -> void:
	var tileset := load("res://assets/tiles/tileset_florest.png") as Texture2D
	var atlas := AtlasTexture.new()
	atlas.atlas = tileset
	atlas.region = GRASS_TILE_REGION
	var container := Node2D.new()
	container.name = "Ground"
	add_child(container)
	for y in range(-WORLD_HALF_TILES, WORLD_HALF_TILES):
		for x in range(-WORLD_HALF_TILES, WORLD_HALF_TILES):
			var s := Sprite2D.new()
			s.texture = atlas
			s.centered = false
			s.position = Vector2(x * TILE_SIZE, y * TILE_SIZE)
			container.add_child(s)

func _scatter_props() -> void:
	var container := Node2D.new()
	container.name = "Props"
	container.y_sort_enabled = true
	add_child(container)
	for entry in PROP_SPAWNS:
		var path: String = entry[0]
		var count: int = entry[1]
		var solid: bool = entry[2]
		var tex: Texture2D = load(path)
		for i in range(count):
			var p := _random_spot()
			var prop_root := _make_prop(tex, solid)
			prop_root.position = p
			container.add_child(prop_root)

func _make_prop(tex: Texture2D, solid: bool) -> Node2D:
	# Node2D contenedor con Sprite2D como hijo, y opcionalmente
	# StaticBody2D con CollisionShape2D en la base para bloquear.
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
		# Radio en la base — chico para que puedas pasar entre árboles
		shape.radius = max(6.0, tex.get_width() * 0.20)
		col.shape = shape
		col.position = Vector2(0, -6)
		body.add_child(col)
		root.add_child(body)
	return root

func _build_borders() -> void:
	# 4 paredes que forman un cajón al alrededor de (0, 0).
	var container := StaticBody2D.new()
	container.name = "Borders"
	container.collision_layer = 4
	container.collision_mask = 0
	add_child(container)
	var walls: Array = [
		# [pos, size]
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

func _random_spot() -> Vector2:
	for _try in range(20):
		var p := Vector2(
			randf_range(-SCATTER_RADIUS, SCATTER_RADIUS),
			randf_range(-SCATTER_RADIUS, SCATTER_RADIUS),
		)
		if p.length() > NO_SPAWN_RADIUS:
			return p
	return Vector2(SCATTER_RADIUS, 0)
