extends Node2D

## Browser de los 100 weapon icons con su asignación actual a cartas
## de level-up. F6 sobre icon_browser.tscn para verlo.
##
## Layout: grid de 10 columnas. Cada icono se muestra a escala 3x
## con su número, y si está usado por alguna carta muestra qué carta
## en verde. Los NO asignados salen en gris.
##
## Cuando veas un icono mal asignado a una carta, decime el ID del
## icono nuevo (ej. "damage → 55") y lo cambio en upgrades.gd.

const Upgrades := preload("res://scenes/upgrades.gd")

const COLS := 10
const ICON_TILE := 96      # 32 * 3
const CELL_H := 130         # extra room for labels

func _ready() -> void:
	# Invertir mapping: path → carta_id
	var path_to_upgrade: Dictionary = {}
	for u in Upgrades.CARDS:
		if u.has("icon"):
			path_to_upgrade[u["icon"]] = u["id"]

	for n in range(1, 101):
		# Los archivos usan padding a 2 dígitos para 1-9 (icon_01.png..
		# icon_09.png), pero 10+ va sin padding extra (icon_10, icon_100).
		var path := "res://assets/ui/weapon_icons/icon_%02d.png" % n if n < 10 else "res://assets/ui/weapon_icons/icon_%d.png" % n
		if not ResourceLoader.exists(path):
			continue
		var col := (n - 1) % COLS
		var row := (n - 1) / COLS
		var x := col * (ICON_TILE + 20)
		var y := row * CELL_H

		# Icono
		var s := Sprite2D.new()
		s.texture = load(path)
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.scale = Vector2(3, 3)
		s.position = Vector2(x, y)
		add_child(s)

		# Número del icono
		var label := Label.new()
		label.text = "%d" % n
		label.position = Vector2(x, y + ICON_TILE)
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color.WHITE)
		add_child(label)

		# Si está usado, label verde con el nombre de la carta
		if path_to_upgrade.has(path):
			var used := Label.new()
			used.text = path_to_upgrade[path]
			used.position = Vector2(x + 22, y + ICON_TILE)
			used.add_theme_font_size_override("font_size", 12)
			used.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
			used.add_theme_color_override("font_outline_color", Color(0, 0, 0))
			used.add_theme_constant_override("outline_size", 3)
			add_child(used)

	# Cámara centrada en el grid
	var cam := Camera2D.new()
	cam.zoom = Vector2(0.7, 0.7)
	cam.position = Vector2(COLS * (ICON_TILE + 20) * 0.5, 10 * CELL_H * 0.4)
	add_child(cam)
	cam.make_current()
