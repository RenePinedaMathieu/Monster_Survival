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

const BREAKABLE_SCRIPT := preload("res://scenes/breakable.gd")
const MUD_SCRIPT := preload("res://scenes/mud_puddle.gd")
const BREAKABLE_COUNT := 14
const BREAKABLE_RESPAWN := 40.0
const MUD_COUNT := 16
## Tormenta de arena del desierto: cada STORM_EVERY segundos, dura
## STORM_TIME — tapa la vista y frena al player.
const STORM_EVERY := 42.0
const STORM_TIME := 9.0

@onready var _grass: Node2D = $Grass1
var _tilemap: TileMap = null
var _map_rect_tiles: Rect2i = Rect2i(0, 0, 100, 80)   # se sobrescribe con used_rect real
var _map_origin_world: Vector2 = Vector2.ZERO   # top-left del mapa en world coords
var _map: Dictionary = {}

func _ready() -> void:
	# Mapa elegido en map_select: Pantano/Desierto son el mismo mapa
	# pintado con el tileset recoloreado (mismas colisiones).
	_map = GameState.map_data()
	if _map["scene"] != "res://scenes/Grass1.tscn":
		# Reemplazo a mano: replace_by() movería el TileMap de pasto adentro
		# del mapa nuevo y se seguiría dibujando encima.
		var other: Node2D = load(_map["scene"]).instantiate()
		other.scale = _grass.scale
		var idx := _grass.get_index()
		remove_child(_grass)
		_grass.queue_free()
		add_child(other)
		move_child(other, idx)
		_grass = other
	if _map["tint"] != Color(1, 1, 1):
		var tint := CanvasModulate.new()
		tint.color = _map["tint"]
		add_child(tint)
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
	# Diferido: los barriles/charcos van al padre (la escena), que
	# todavía está armándose mientras corre este _ready.
	_populate.call_deferred()

# ── Objetos y peligros del mapa ──────────────────────────────────

func _populate() -> void:
	for i in range(BREAKABLE_COUNT):
		_spawn_breakable()
	match _map["hazard"]:
		"mud":
			for i in range(MUD_COUNT):
				var mud := Area2D.new()
				mud.set_script(MUD_SCRIPT)
				mud.radius = randf_range(40.0, 70.0)
				mud.position = _random_spot(160.0)
				get_parent().add_child(mud)
		"sandstorm":
			_start_storm_cycle()

## Punto caminable al azar, lejos del centro (donde arranca el player).
func _random_spot(min_center_dist: float) -> Vector2:
	var map_w := _map_rect_tiles.size.x * TILE_SIZE * MAP_SCALE
	var map_h := _map_rect_tiles.size.y * TILE_SIZE * MAP_SCALE
	for i in range(30):
		var p := Vector2(randf_range(-map_w, map_w) * 0.45, randf_range(-map_h, map_h) * 0.45)
		if p.length() >= min_center_dist and is_spawnable_at(p):
			return p
	return Vector2(min_center_dist, 0)

func _spawn_breakable() -> void:
	var b := Area2D.new()
	b.set_script(BREAKABLE_SCRIPT)
	b.position = _random_spot(120.0)
	get_parent().add_child(b)
	b.broken.connect(func():
		get_tree().create_timer(BREAKABLE_RESPAWN).timeout.connect(_spawn_breakable))

var _storm_layer: CanvasLayer
var _storm_rect: ColorRect
var _storm_label: Label

func _start_storm_cycle() -> void:
	_storm_layer = CanvasLayer.new()
	_storm_layer.layer = 1
	add_child(_storm_layer)
	_storm_rect = ColorRect.new()
	_storm_rect.color = Color(0.86, 0.72, 0.45, 0.0)
	_storm_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_storm_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_storm_layer.add_child(_storm_rect)
	_storm_label = Label.new()
	_storm_label.text = "¡TORMENTA DE ARENA!"
	_storm_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_storm_label.offset_top = 150.0
	_storm_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_storm_label.modulate.a = 0.0
	_storm_label.add_theme_font_size_override("font_size", 30)
	_storm_label.add_theme_color_override("font_color", Color("fff0c8"))
	_storm_label.add_theme_color_override("font_outline_color", Color("5a3a18"))
	_storm_label.add_theme_constant_override("outline_size", 6)
	_storm_layer.add_child(_storm_label)
	get_tree().create_timer(STORM_EVERY * 0.6).timeout.connect(_storm)

func _storm() -> void:
	_set_storm_players(true)
	var tw := create_tween()
	tw.tween_property(_storm_rect, "color:a", 0.42, 1.2)
	tw.parallel().tween_property(_storm_label, "modulate:a", 1.0, 0.4)
	tw.tween_property(_storm_label, "modulate:a", 0.0, 0.8).set_delay(1.4)
	tw.tween_interval(STORM_TIME - 3.4)
	tw.tween_property(_storm_rect, "color:a", 0.0, 1.2)
	tw.tween_callback(_set_storm_players.bind(false))
	get_tree().create_timer(STORM_EVERY).timeout.connect(_storm)

func _set_storm_players(on: bool) -> void:
	for p in get_tree().get_nodes_in_group("player"):
		if "in_sandstorm" in p:
			p.in_sandstorm = on

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
