extends Node2D

## Playground para probar el mapa pintado a mano en Tiled
## (scenes/Grass1.tscn) con el personaje real.
##
## - Instancia el mapa exportado como hijo
## - Instancia el Player con zoom 2.0 y Q/E para zoomear
## - Sin monsters, sin waves — sólo caminar
##
## Corré con F6.
##
## Para agregar colisiones a tiles no-caminables (agua, montañas):
##   1. Abrí Grass1.tscn en el editor
##   2. Click en el nodo TileMap
##   3. En el Inspector, doble click en "Tile Set" para abrirlo
##   4. Solapa "Physics Layers" abajo → +
##      - Collision Layer: activá SÓLO el bit 3 (= mask 4)
##      - Collision Mask: dejá todos apagados
##   5. Solapa "TileMap" abajo (arriba del canvas) → Paint → Physics
##   6. Con el pincel de física, pintá los tiles que NO son caminables
##      (agua, borde de acantilado, etc.). El pincel dibuja un polígono
##      en cada tile del atlas — ese polígono se aplica a todas las
##      instancias de ese tile en el mapa.
##   7. Guardá el TileSet y el mapa.
##
## Al correr, el player choca con esos tiles.

## Arbitraria — dentro del mapa. Como escalé Grass1 2x, un tile es 32
## unidades. Si tu mapa parte en (0,0) top-left, (400, 400) cae más o
## menos donde antes hubiera sido (200, 200) sin escalar.
const START_POS := Vector2(400, 400)

const CAM_SPEED := 400.0
const ZOOM_MIN := 0.3
const ZOOM_MAX := 4.0

@onready var _player: CharacterBody2D = $Player

func _ready() -> void:
	_player.position = START_POS
	# La cámara del player ya llama make_current() en su _ready, así
	# que no hay conflicto con ninguna otra cámara escondida.
	print("[playground] WASD/flechas para mover · Q/E zoom · rueda del mouse")
