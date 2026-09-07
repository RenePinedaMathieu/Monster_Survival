extends Node2D

## Mundo del survival. Genera el fondo de grass (tileado) y esparce
## props (árboles, piedras, calaveras, señales, cofres) al azar
## alrededor del origen. Los props se ordenan por y para que los que
## están más al sur se dibujen encima (efecto de perfil).

const TILE_SIZE := 24
const WORLD_HALF_TILES := 40   # 80×80 tiles → ~1920×1920 px de mundo

# Región del tileset que usamos como grass base. Elegí una zona
# central del sheet donde hay grass sólido sin path.
const GRASS_TILE_REGION := Rect2(48, 24, 24, 24)

# Props que scatteamos. Cada tuple: (path, cantidad).
const PROP_SPAWNS: Array = [
	["res://assets/props/props_tree.png",             40],
	["res://assets/props/props_tree_couple.png",      15],
	["res://assets/props/props_tree_goup.png",        15],
	["res://assets/props/props_big_stone.png",        12],
	["res://assets/props/props_mid_stone.png",        14],
	["res://assets/props/props_small_stone.png",      18],
	["res://assets/props/props_skull.png",             6],
	["res://assets/props/props_sign.png",              3],
	["res://assets/props/props_chest_closed.png",      4],
	["res://assets/props/props_grasschest_closed.png", 3],
]

const SCATTER_RADIUS := 900.0
const NO_SPAWN_RADIUS := 120.0   # zona limpia alrededor del spawn

func _ready() -> void:
	_build_ground()
	_scatter_props()

func _build_ground() -> void:
	# Un solo Sprite2D repetido no queda tan lindo en Godot 4 sin
	# shader; con 80×80 = 6400 sprites Godot vuela igual y queda
	# perfecto sin fisuras.
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
	container.y_sort_enabled = true   # y-sort — próximos al sur van arriba
	add_child(container)
	for entry in PROP_SPAWNS:
		var path: String = entry[0]
		var count: int = entry[1]
		var tex: Texture2D = load(path)
		for i in range(count):
			var p := _random_spot()
			var sprite := Sprite2D.new()
			sprite.texture = tex
			sprite.position = p
			container.add_child(sprite)

func _random_spot() -> Vector2:
	# Rechaza si cae muy cerca del centro para no aparecerle al
	# player un árbol encima al spawnear.
	for _try in range(20):
		var p := Vector2(
			randf_range(-SCATTER_RADIUS, SCATTER_RADIUS),
			randf_range(-SCATTER_RADIUS, SCATTER_RADIUS),
		)
		if p.length() > NO_SPAWN_RADIUS:
			return p
	return Vector2(SCATTER_RADIUS, 0)
