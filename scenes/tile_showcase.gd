extends Node2D

## Scene de exploración de tiles/props — muestra TODO lo que tenemos
## en assets/tiles/ y assets/props/ con sus coordenadas/masks/tamaños
## visibles al lado. Sirve para:
##
##   1. Decidir qué regiones del florest tileset son grass "buena"
##      (hoy en world.gd usamos 4 hardcodeadas — igual conviene ver
##      qué otras hay)
##   2. Confirmar que el mapeo de wang tiles (col/row/mask) es el que
##      calculamos empíricamente
##   3. Ver todos los props a escala natural con sus tamaños
##
## Controles:
##   WASD/flechas — panear cámara
##   Q — alejar, E — acercar (o rueda del mouse)
##
## Corré con F6 sobre tile_showcase.tscn.

const CAM_SPEED := 500.0
const ZOOM_MIN := 0.3
const ZOOM_MAX := 5.0
const ZOOM_KEY_STEP := 0.06
const ZOOM_WHEEL_STEP := 0.2

# Layout — cada sección tiene una Y de inicio para no pisarse
const Y_FLOREST := 40.0
const Y_WANG_WATER := 700.0
const Y_WANG_STONE := 1300.0
const Y_PROPS := 1900.0

@onready var _camera: Camera2D = $Camera2D

func _ready() -> void:
	_camera.make_current()
	_build_florest_section(Vector2(0, Y_FLOREST))
	_build_wang_section(
		Vector2(0, Y_WANG_WATER),
		"res://assets/tiles/pretty_grass_to_water._grass_color_3F9B0B.png",
		"WANG: GRASS ↔ WATER",
	)
	_build_wang_section(
		Vector2(0, Y_WANG_STONE),
		"res://assets/tiles/pretty_grass_3F9B0B_to_stone.png",
		"WANG: GRASS ↔ STONE",
	)
	_build_props_section(Vector2(0, Y_PROPS))
	_camera.position = Vector2(700, 400)

# ── Secciones ────────────────────────────────────────────────────

## Muestra todos los tiles 24×24 del florest tileset (12×7 = 84 tiles)
## a escala 3x, con coord (col,row) debajo de cada uno.
func _build_florest_section(origin: Vector2) -> void:
	_title(origin + Vector2(0, -30), "tileset_florest.png — 12×7 tiles de 24×24 (escala 3x)")
	var tex: Texture2D = load("res://assets/tiles/tileset_florest.png")
	var tile := 24
	var display_scale := 3
	var display := tile * display_scale     # 72px on-screen
	var gap := 24
	for row in range(7):
		for col in range(12):
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(col * tile, row * tile, tile, tile)
			var s := Sprite2D.new()
			s.texture = atlas
			s.centered = false
			s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			s.scale = Vector2(display_scale, display_scale)
			var cell := Vector2(col * (display + gap), row * (display + gap))
			s.position = origin + cell
			add_child(s)
			_coord_label(origin + cell + Vector2(0, display + 2), "(%d,%d)" % [col, row])

## Muestra los 16 wang tiles del atlas con su (col,row) y el MASK
## calculado por la fórmula empírica. Mask 15 debería estar en (0,0)
## y ser "todo other"; mask 0 en (3,3) y ser "todo grass".
func _build_wang_section(origin: Vector2, path: String, title: String) -> void:
	_title(origin + Vector2(0, -30), title + " — sólo top face (96×48)")
	var tex: Texture2D = load(path)
	var tile_w := 96
	var top_h := 48
	var full_h := 72
	var gap := 1
	var display_scale := 2
	var cell_gap := 40
	for row in range(4):
		for col in range(4):
			var mask := _pos_to_mask(col, row)
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(col * (tile_w + gap), row * (full_h + gap), tile_w, top_h)
			var s := Sprite2D.new()
			s.texture = atlas
			s.centered = false
			s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			s.scale = Vector2(display_scale, display_scale)
			var cell := Vector2(
				col * (tile_w * display_scale + cell_gap),
				row * (top_h * display_scale + cell_gap + 20),
			)
			s.position = origin + cell
			add_child(s)
			_coord_label(
				origin + cell + Vector2(0, top_h * display_scale + 4),
				"col=%d row=%d — mask %d" % [col, row, mask],
			)

## Muestra todos los props a tamaño natural con label del filename
## y dimensiones (para calibrar hitboxes).
func _build_props_section(origin: Vector2) -> void:
	_title(origin + Vector2(0, -30), "Props (assets/props/) — tamaño natural")
	var files: Array[String] = [
		"props_tree.png", "props_tree_couple.png", "props_tree_goup.png",
		"props_big_stone.png", "props_mid_stone.png", "props_small_stone.png",
		"props_skull.png", "props_sign.png",
		"props_chest_closed.png", "props_grasschest_closed.png",
	]
	var x := 0.0
	var y := 0.0
	var row_h := 0.0
	var wrap_x := 1400.0
	var gap := 40.0
	for f in files:
		var tex: Texture2D = load("res://assets/props/" + f)
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.position = origin + Vector2(x, y)
		add_child(s)
		var w: float = tex.get_width()
		var h: float = tex.get_height()
		_coord_label(
			origin + Vector2(x, y + h + 4),
			"%s (%d×%d)" % [f, int(w), int(h)],
		)
		x += w + gap
		row_h = max(row_h, h + 30)
		if x > wrap_x:
			x = 0
			y += row_h + gap
			row_h = 0

# ── Utilidades ───────────────────────────────────────────────────

## Inversa de la fórmula del wang mask que usamos en world.gd:
##   col = 3 - (SW*2 + SE), row = 3 - (NW*2 + NE)
func _pos_to_mask(col: int, row: int) -> int:
	var sw_se := 3 - col
	var nw_ne := 3 - row
	var sw := sw_se / 2
	var se := sw_se % 2
	var nw := nw_ne / 2
	var ne := nw_ne % 2
	return nw + (ne << 1) + (sw << 2) + (se << 3)

func _title(pos: Vector2, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 6)
	add_child(l)

func _coord_label(pos: Vector2, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 3)
	add_child(l)

# ── Input ────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(_camera.zoom.x + ZOOM_WHEEL_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(_camera.zoom.x - ZOOM_WHEEL_STEP)

func _process(delta: float) -> void:
	var input := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down"),
	)
	_camera.position += input * CAM_SPEED * delta / _camera.zoom.x
	if Input.is_key_pressed(KEY_Q):
		_set_zoom(_camera.zoom.x - ZOOM_KEY_STEP)
	elif Input.is_key_pressed(KEY_E):
		_set_zoom(_camera.zoom.x + ZOOM_KEY_STEP)

func _set_zoom(value: float) -> void:
	var c: float = clampf(value, ZOOM_MIN, ZOOM_MAX)
	_camera.zoom = Vector2(c, c)
