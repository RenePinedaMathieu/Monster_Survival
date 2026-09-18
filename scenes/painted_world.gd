extends Node2D

## Envoltorio del mapa pintado a mano (Grass1.tscn desde Tiled) que
## expone la API que main.gd espera del "world":
##
##   is_spawnable_at(pos) -> bool
##
## Reemplaza el world.gd procedural (grass core + lago + ruinas
## generados con noise). Ahora el mundo es un único mapa fijo, hecho
## a mano.
##
## - El mapa se instancia con scale 2x así los tiles de 16px se ven
##   como 32px (proporcional al personaje).
## - El mapa se offsetea (-map_size/2) para que (0,0) mundo caiga en
##   el CENTRO del mapa, no en la esquina — así el player spawnea
##   centrado y los monstruos spawnean alrededor.
## - Los tiles no-caminables (agua + árboles) YA tienen colisión al
##   layer 4 desde Grass1.tscn (agregada por script).
## - Se agregan 4 paredes invisibles en el borde del mapa para que
##   el player no se escape del área jugable.

const TILE_SIZE := 16.0
const MAP_SCALE := 2.0

# Tiles del atlas que NO son caminables. Se sincroniza con la lista
# usada al inyectar las colisiones en Grass1.tscn.
const NON_SPAWNABLE_COORDS: Array = [
	# water
	Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4), Vector2i(0, 5), 
	Vector2i(1, 5), Vector2i(2, 5), Vector2i(0, 6), Vector2i(1, 6), 
	Vector2i(2, 6), Vector2i(0, 7), Vector2i(1, 7), Vector2i(0, 9), 
	Vector2i(0, 10), Vector2i(1, 10), Vector2i(2, 10), 
	# trees
	Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4), Vector2i(3, 5), 
	Vector2i(4, 5), Vector2i(5, 5), Vector2i(3, 6), Vector2i(4, 6), 
	Vector2i(5, 6), Vector2i(9, 4), Vector2i(10, 4), Vector2i(11, 4), 
	Vector2i(9, 5), Vector2i(10, 5), Vector2i(11, 5), Vector2i(9, 6), 
	Vector2i(10, 6), Vector2i(11, 6), Vector2i(3, 7), Vector2i(4, 7), 
	Vector2i(5, 7), Vector2i(9, 7), Vector2i(10, 7), Vector2i(11, 7), 
	Vector2i(9, 10), Vector2i(11, 10), Vector2i(5, 15), 
]

@onready var _grass: Node2D = $Grass1
var _tilemap: TileMap = null
var _map_rect_tiles: Rect2i = Rect2i(0, 0, 100, 80)   # se sobrescribe con used_rect real
var _map_origin_world: Vector2 = Vector2.ZERO   # top-left del mapa en world coords

func _ready() -> void:
	# Encontrar el TileMap dentro del Grass1
	_tilemap = _find_tilemap(_grass)
	if _tilemap:
		_map_rect_tiles = _tilemap.get_used_rect()
	# Centrar el mapa en (0,0) del mundo — se corre después del ready
	# porque necesitamos _map_rect_tiles ya cargado.
	var map_w := _map_rect_tiles.size.x * TILE_SIZE * MAP_SCALE
	var map_h := _map_rect_tiles.size.y * TILE_SIZE * MAP_SCALE
	_grass.position = Vector2(-map_w * 0.5, -map_h * 0.5)
	_map_origin_world = _grass.position
	# Paredes invisibles en el perímetro del mapa
	_build_borders(map_w, map_h)

func _find_tilemap(root: Node) -> TileMap:
	for c in root.get_children():
		if c is TileMap:
			return c
	return null

## Consultada por main.gd para decidir si un monster puede spawnear en
## esta posición. Rechaza fuera del mapa y encima de agua/árboles.
func is_spawnable_at(world_pos: Vector2) -> bool:
	var effective := TILE_SIZE * MAP_SCALE
	var tx := int(floor((world_pos.x - _map_origin_world.x) / effective))
	var ty := int(floor((world_pos.y - _map_origin_world.y) / effective))
	if tx < _map_rect_tiles.position.x or ty < _map_rect_tiles.position.y:
		return false
	if tx >= _map_rect_tiles.position.x + _map_rect_tiles.size.x: return false
	if ty >= _map_rect_tiles.position.y + _map_rect_tiles.size.y: return false
	if _tilemap == null:
		return true
	var coords: Vector2i = _tilemap.get_cell_atlas_coords(0, Vector2i(tx, ty))
	return not (coords in NON_SPAWNABLE_COORDS)

func _build_borders(map_w: float, map_h: float) -> void:
	var body := StaticBody2D.new()
	body.name = "Borders"
	body.collision_layer = 4
	body.collision_mask = 0
	add_child(body)
	# Le pegamos ~40px de grosor apenas afuera del mapa
	var thick := 40.0
	var half_w := map_w * 0.5
	var half_h := map_h * 0.5
	var walls: Array = [
		[Vector2( 0,           -half_h - thick * 0.5), Vector2(map_w + 2 * thick, thick)],  # top
		[Vector2( 0,            half_h + thick * 0.5), Vector2(map_w + 2 * thick, thick)],  # bottom
		[Vector2(-half_w - thick * 0.5, 0),            Vector2(thick, map_h + 2 * thick)],  # left
		[Vector2( half_w + thick * 0.5, 0),            Vector2(thick, map_h + 2 * thick)],  # right
	]
	for wall in walls:
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = wall[1]
		col.shape = shape
		col.position = wall[0]
		body.add_child(col)
