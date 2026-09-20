extends Control

## Ícono chico pixel-art dibujado a mano en bloques (mismo enfoque que
## xp_orb.gd/shot_projectile.gd) — usado en las filas de la tienda
## para darle identidad visual a cada mejora sin necesitar assets
## nuevos. Bitmap fijo por tipo, un "1" por bloque a dibujar.

const PIXEL := 4.0
const BOX := 40.0   # tamaño del cuadrito donde vive el ícono — fijo, no depende del layout

const BITMAPS: Dictionary = {
	"shield": [
		"01110",
		"11111",
		"11111",
		"11111",
		"01110",
		"00100",
	],
	"heart": [
		"01100110",
		"11111111",
		"11111111",
		"01111110",
		"00111100",
		"00011000",
	],
	"fist": [
		"00110",
		"01111",
		"11111",
		"01111",
		"00110",
		"00100",
	],
	"spark": [
		"00100",
		"00100",
		"10101",
		"01110",
		"10101",
		"00100",
	],
	"coin": [
		"01110",
		"11111",
		"11011",
		"11011",
		"11111",
		"01110",
	],
}

@export var icon_id: String = "shield"
@export var color: Color = Color.WHITE

func set_icon(id: String, c: Color) -> void:
	icon_id = id
	color = c
	queue_redraw()

func _draw() -> void:
	var rows: Array = BITMAPS.get(icon_id, [])
	if rows.is_empty():
		return
	var w: int = rows[0].length()
	var h: int = rows.size()
	var ox: float = (BOX - w * PIXEL) * 0.5
	var oy: float = (BOX - h * PIXEL) * 0.5
	for y in range(h):
		var row: String = rows[y]
		for x in range(w):
			if row[x] == "1":
				var pos := Vector2(ox + x * PIXEL, oy + y * PIXEL)
				draw_rect(Rect2(pos, Vector2(PIXEL, PIXEL) * 1.02), color)
