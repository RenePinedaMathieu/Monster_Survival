extends Control

## Minimap top-down. Dibuja en cada frame:
##   - Fondo semitransparente
##   - Contorno del mundo (WORLD_BOUND del world.gd)
##   - Puntos rojos por cada monstruo (grupo "monster")
##   - Punto verde por el player (grupo "player")
##   - Puntos celestes por remote players
##
## Es "top-down" en coordenadas de mundo, no rota con la cámara.

const WORLD_BOUND := 950.0    # match world.gd
const SIZE := 150.0
# Escala mundo → minimap. WORLD_BOUND es medio-mundo, así que
# lo pasamos a [0..SIZE].
const SCALE := SIZE / (WORLD_BOUND * 2.0)

const BG_COLOR := Color(0, 0, 0, 0.55)
const BORDER_COLOR := Color(1, 1, 1, 0.7)
const WORLD_BORDER_COLOR := Color(0.9, 0.9, 0.5, 0.6)
const PLAYER_COLOR := Color(0.4, 1.0, 0.5)
const REMOTE_COLOR := Color(0.55, 0.85, 1.0)
const MONSTER_COLOR := Color(1.0, 0.35, 0.35)

func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	# Redibujar cada frame es barato con pocos monsters.
	set_process(true)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	# Fondo + marco
	draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE, SIZE)), BG_COLOR, true)
	draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE, SIZE)), BORDER_COLOR, false, 2.0)
	# Contorno del mundo (el borde real donde chocás)
	var world_side := WORLD_BOUND * 2.0 * SCALE
	var world_origin := (Vector2(SIZE, SIZE) - Vector2(world_side, world_side)) / 2.0
	draw_rect(Rect2(world_origin, Vector2(world_side, world_side)),
		WORLD_BORDER_COLOR, false, 1.5)

	# Player local
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty(): return
	var player: Node2D = players[0]
	var pcenter := _world_to_map(player.global_position)

	# Monsters — sólo dibujamos los que estén dentro de un radio
	# generoso del player para no saturar el minimap (y para que
	# se sienta como "radar").
	for m in get_tree().get_nodes_in_group("monster"):
		if not is_instance_valid(m): continue
		var d := _world_to_map(m.global_position)
		if _in_bounds(d):
			draw_circle(d, 2.2, MONSTER_COLOR)

	# Remote players (multiplayer)
	for rp in get_tree().get_nodes_in_group("remote_player"):
		if not is_instance_valid(rp): continue
		var d := _world_to_map(rp.global_position)
		if _in_bounds(d):
			draw_circle(d, 2.8, REMOTE_COLOR)

	# Player siempre encima
	draw_circle(pcenter, 3.4, PLAYER_COLOR)
	draw_circle(pcenter, 3.4, Color(1, 1, 1, 0.8), false, 1.0)

func _world_to_map(pos: Vector2) -> Vector2:
	# El player va en el centro del minimap; todo lo demás relativo.
	# Esto le da al minimap un feel de radar centrado.
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return Vector2(SIZE / 2.0, SIZE / 2.0)
	var player: Node2D = players[0]
	var rel: Vector2 = pos - player.global_position
	return Vector2(SIZE / 2.0, SIZE / 2.0) + rel * SCALE

func _in_bounds(p: Vector2) -> bool:
	return p.x >= 0 and p.x <= SIZE and p.y >= 0 and p.y <= SIZE
