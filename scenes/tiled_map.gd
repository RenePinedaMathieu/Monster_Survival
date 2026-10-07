extends Node2D

## Mapa pintado en Tiled y llevado al juego con tools/import_tiled_map.gd
## (scenes/maps/<id>.scn). A escala x1: un cuadro de Tiled = 16 unidades
## del mundo. Adentro:
##   Suelo    las capas planas (suelo, agua, manchas, pasto), debajo de todo
##   Objetos  las capas "objects..." y las de más arriba, cada baldosa
##            ordenada por altura con el héroe y los monstruos (su
##            y_sort_origin apunta a la base del objeto)
##   Choque   rectángulos sólidos: agua, la base de los objetos y lo
##            pintado en la capa "choque" de Tiled
## `slow`: celdas de las capas "slow"/"lento" (p. ej. Pasto_slow del
## Pantano): lo que camina va a la mitad (is_slow_world).
## La grilla `solid` (celdas de `cell` px) sirve para no aparecer adentro
## de algo (painted_world.gd is_spawnable_at).

@export var map_size := Vector2.ZERO
@export var cell := 8
@export var grid_size := Vector2i.ZERO
@export var solid := PackedByteArray()
@export var slow := PackedByteArray()

func _ready() -> void:
	add_to_group("tiled_map")

## `local`: posición relativa a la esquina del mapa.
func is_solid_at(local: Vector2) -> bool:
	var c := Vector2i(int(floorf(local.x / cell)), int(floorf(local.y / cell)))
	if c.x < 0 or c.y < 0 or c.x >= grid_size.x or c.y >= grid_size.y:
		return true
	return solid[c.y * grid_size.x + c.x] != 0

## ¿Zona lenta en esta posición del mundo?
func is_slow_world(world_pos: Vector2) -> bool:
	if slow.is_empty():
		return false
	var local := world_pos - global_position
	var c := Vector2i(int(floorf(local.x / cell)), int(floorf(local.y / cell)))
	if c.x < 0 or c.y < 0 or c.x >= grid_size.x or c.y >= grid_size.y:
		return false
	return slow[c.y * grid_size.x + c.x] != 0
