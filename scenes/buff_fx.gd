extends Sprite2D

## Efecto del pack Magic Buff (tools/import_buff_fx.py) en los pies del
## héroe: un aro en el piso y luces que suben. Lo crea player.play_buff():
## va de hijo del player (lo sigue) y detrás de su dibujo. Se borra solo
## al terminar, salvo con `hold` (el Escudo de fuerza cargado): ahí queda
## en ese cuadro, latiendo, hasta que lo sacan.
##   "life"      agarrar vida (pickup.gd)
##   "immunity"  inmune: al revivir y el Escudo de fuerza

## Tira, cuadros y altura del centro del aro en el cuadro.
const SHEETS := {
	"life": ["res://assets/sprites/fx/buffs/life_recovery.png", 12, 64.0],
	"immunity": ["res://assets/sprites/fx/buffs/immunity.png", 16, 59.0],
}
## Los pies del héroe respecto de su centro (su choque está en y=10).
const FEET_Y := 12.0

var fps: float = 14.0
var hold: int = -1
var _t: float = 0.0

func setup(kind: String, fps_: float, hold_: int = -1) -> void:
	var data: Array = SHEETS[kind]
	texture = load(data[0])
	hframes = int(data[1])
	fps = fps_
	hold = hold_
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# El centro del aro, en los pies.
	offset = Vector2(0.0, texture.get_height() / 2.0 - float(data[2]))
	position = Vector2(0.0, FEET_Y)
	frame = 0

## Vuelve a empezar (el escudo recargado).
func restart() -> void:
	_t = 0.0
	modulate.a = 1.0

func _process(delta: float) -> void:
	_t += delta
	var f := int(_t * fps)
	if f < hframes:
		frame = f
		return
	if hold < 0:
		queue_free()
		return
	frame = hold
	modulate.a = 0.7 + 0.25 * sin(_t * 3.0)
