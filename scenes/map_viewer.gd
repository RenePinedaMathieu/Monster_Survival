extends Node2D

## VISOR DE MAPAS (catálogo → MAPAS): cada mapa armado con el mismo
## mundo del juego (painted_world.tscn: tiles o imagen, barriles, barro,
## tormenta) para revisarlo y ajustarlo. Arrastrar = mover, rueda = zoom.
##
## Capas: zonas donde NO aparecen monstruos (agua/árboles, según
## painted_world.NON_SPAWNABLE_COORDS), grilla de tiles con coordenadas,
## anillo de aparición alrededor del héroe (main.gd SPAWN_INNER/OUTER) y
## bordes. La ficha muestra dificultad, peligro, jefes y los monstruos de
## cada tramo de oleadas con su sprite. TILESET abre la hoja de tiles con
## su grilla y los tiles que bloquean marcados en rojo.

const RpgTheme := preload("res://scenes/rpg_theme.gd")
const Monster := preload("res://scenes/monster.gd")
const World := preload("res://scenes/painted_world.gd")
const WORLD_SCENE := preload("res://scenes/painted_world.tscn")
const CATALOG_SCENE := "res://scenes/catalog.tscn"
const SPAWN_INNER := 500.0   # = main.gd
const SPAWN_OUTER := 800.0
const TILE_WORLD := World.TILE_SIZE * World.MAP_SCALE   # 32 unidades por tile
const POOL_NAMES := ["Oleadas 1-3", "Oleadas 4-6", "Oleadas 7+"]

var _map_id: String = ""
var _prev_selected_map: String = ""
var _world = null
var _camera: Camera2D
var _overlay: MapOverlay
var _info: VBoxContainer
var _layers := {"blocked": true, "solid": false, "grid": false, "ring": true, "bounds": true}
var _solid_polys: Array = []   # colisiones de los tiles en coordenadas del mundo
var _layer_buttons := {}
var _keep: Array = []
var _drag := false
var _tileset_panel: Control

func _ready() -> void:
	_prev_selected_map = GameState.selected_map
	var back := CanvasLayer.new()
	back.layer = -10
	add_child(back)
	var bg := ColorRect.new()
	bg.color = Color("111015")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.add_child(bg)
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	_overlay = MapOverlay.new()
	_overlay.viewer = self
	_overlay.z_index = 100
	add_child(_overlay)
	_build_ui()
	_keep = get_children()
	_show_map(GameState.MAP_ORDER[0])

func _exit_tree() -> void:
	# El visor cambia selected_map para armar cada mundo: se deja como estaba.
	GameState.selected_map = _prev_selected_map

# ── Interfaz ─────────────────────────────────────────────────────

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", RpgTheme.wood_box(10.0, 8.0))
	panel.anchor_bottom = 1.0
	panel.offset_left = 8.0
	panel.offset_top = 8.0
	panel.offset_bottom = -8.0
	panel.offset_right = 340.0
	ui.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	scroll.add_child(col)
	col.add_child(_label("MAPAS", 20))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	col.add_child(row)
	row.add_child(_button("VOLVER", 13, func(): get_tree().change_scene_to_file(CATALOG_SCENE)))
	row.add_child(_button("TILESET", 13, _toggle_tileset))
	row.add_child(_button("VER TODO", 13, _fit))
	var maps := HBoxContainer.new()
	maps.add_theme_constant_override("separation", 6)
	col.add_child(maps)
	for id in GameState.MAP_ORDER:
		maps.add_child(_button(GameState.MAPS[id]["name"].to_upper(), 13, _show_map.bind(id)))
	col.add_child(_label("Capas", 15))
	var layers := HFlowContainer.new()
	layers.add_theme_constant_override("h_separation", 6)
	layers.add_theme_constant_override("v_separation", 6)
	col.add_child(layers)
	for key in [["blocked", "NO APARECEN"], ["solid", "CHOCA"], ["grid", "GRILLA"], ["ring", "ANILLO"], ["bounds", "BORDES"]]:
		var b := _button(key[1], 12, _toggle_layer.bind(key[0]))
		_layer_buttons[key[0]] = b
		layers.add_child(b)
	_info = VBoxContainer.new()
	_info.add_theme_constant_override("separation", 4)
	col.add_child(_info)
	var help := _label("Arrastrar: mover · Rueda: zoom · Esc: volver", 12)
	help.modulate.a = 0.7
	col.add_child(help)
	_refresh_layer_buttons()

func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	RpgTheme.style_light_label(l, size)
	return l

func _button(text: String, size: int, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 32)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	RpgTheme.style_button(b, size)
	b.pressed.connect(cb)
	return b

func _toggle_layer(key: String) -> void:
	_layers[key] = not _layers[key]
	_refresh_layer_buttons()
	_overlay.queue_redraw()

func _refresh_layer_buttons() -> void:
	for key in _layer_buttons:
		RpgTheme.style_tab(_layer_buttons[key], _layers[key], 12)

# ── Mapa ─────────────────────────────────────────────────────────

func _show_map(id: String) -> void:
	_map_id = id
	for c in get_children():
		if not (c in _keep):
			c.queue_free()
	GameState.selected_map = id
	_world = WORLD_SCENE.instantiate()
	add_child(_world)
	move_child(_world, 0)
	_collect_solids()
	_build_info()
	_fit()
	_overlay.queue_redraw()
	if _tileset_panel != null:
		_toggle_tileset()
		_toggle_tileset()

## Polígonos de colisión de cada tile (agua, árboles...): donde el héroe
## choca. Se calculan una vez por mapa.
func _collect_solids() -> void:
	_solid_polys.clear()
	var tm: TileMap = _world._tilemap
	if tm == null or tm.tile_set.get_physics_layers_count() == 0:
		return
	var xf := tm.get_global_transform()
	for cell in tm.get_used_cells(0):
		var data: TileData = tm.get_cell_tile_data(0, cell)
		if data == null:
			continue
		var center := tm.map_to_local(cell)
		for i in range(data.get_collision_polygons_count(0)):
			var pts := PackedVector2Array()
			for pt in data.get_collision_polygon_points(0, i):
				pts.append(xf * (center + pt))
			_solid_polys.append(pts)

## Tamaño del mapa en unidades del mundo (centrado en 0,0).
func map_size() -> Vector2:
	if _world == null:
		return Vector2(1000, 800)
	if _world._image_map_size != Vector2.ZERO:
		return _world._image_map_size
	return Vector2(_world._map_rect_tiles.size) * TILE_WORLD

func _fit() -> void:
	var vp := get_viewport_rect().size
	var ms := map_size()
	var z: float = minf((vp.x - 360.0) / ms.x, vp.y / ms.y) * 0.95
	_camera.zoom = Vector2.ONE * z
	# El panel tapa 350 px a la izquierda: se corre el centro.
	_camera.position = Vector2(-175.0 / z, 0.0)
	_overlay.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _tileset_panel != null:
			_toggle_tileset()
		else:
			get_tree().change_scene_to_file(CATALOG_SCENE)
	elif event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			_drag = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera.zoom = (_camera.zoom * 1.15).clamp(Vector2.ONE * 0.05, Vector2.ONE * 6.0)
			_overlay.queue_redraw()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera.zoom = (_camera.zoom / 1.15).clamp(Vector2.ONE * 0.05, Vector2.ONE * 6.0)
			_overlay.queue_redraw()
	elif event is InputEventMouseMotion and _drag:
		_camera.position -= event.relative / _camera.zoom.x

# ── Ficha ────────────────────────────────────────────────────────

func _build_info() -> void:
	for c in _info.get_children():
		c.queue_free()
	var d: Dictionary = GameState.MAPS[_map_id]
	_info.add_child(_label(d["name"].to_upper(), 18))
	_info.add_child(_label(d["desc"], 13))
	var diff: Dictionary = GameState.DIFFICULTIES["normal"]
	var hazard: String = {"": "ninguno", "mud": "charcos de barro (frenan 40%)", "sandstorm": "tormenta de arena (frena 18%, cada 42 s)"}.get(d["hazard"], d["hazard"])
	var source: String = ("Imagen pintada: " + d["image"]) if d.get("image", "") != "" else ("Tiles: " + d["tileset"] + "\nEscena: " + d["scene"])
	var ms := map_size()
	var lines: Array = [
		"Enemigos y monedas x%.2f (en Normal x%.1f)" % [d["mult"], float(diff["mult"])],
		"Peligro: " + hazard,
		"Tinte: " + d["tint"].to_html(false),
		"Tamaño: %d x %d unidades%s" % [ms.x, ms.y, ("" if d.get("image", "") != "" else " (%d x %d tiles)" % [ms.x / TILE_WORLD, ms.y / TILE_WORLD])],
		source.replace("res://assets/", ""),
		"Se desbloquea: " + (GameState.unlock_hint_for_map(_map_id) if GameState.unlock_hint_for_map(_map_id) != "" else "desde el inicio"),
	]
	var legend := GameState.legend_skill_for(_map_id)
	if legend != "":
		lines.append("Oleada 30: habilidad legendaria " + GameState.SKILL_TREE[legend]["name"])
	for l in lines:
		var lab := _label(l, 12)
		lab.modulate.a = 0.85
		_info.add_child(lab)
	_info.add_child(_label("Jefes", 15))
	var bosses := HFlowContainer.new()
	_info.add_child(bosses)
	var bl: Array = d["bosses"]
	for i in range(3):
		var kind: String = bl[mini(i, bl.size() - 1)]
		bosses.add_child(_monster_chip(kind, "Oleada %d" % ((i + 1) * 10)))
	var pools: Array = d["pools"]
	for i in range(pools.size()):
		_info.add_child(_label(POOL_NAMES[i], 15))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 4)
		_info.add_child(flow)
		var seen := {}
		for kind in pools[i]:
			if seen.has(kind):
				continue
			seen[kind] = true
			var n: int = pools[i].count(kind)
			flow.add_child(_monster_chip(kind, kind + (" x%d" % n if n > 1 else "")))

## Miniatura de un monstruo (primer cuadro del idle de frente) + texto.
func _monster_chip(kind: String, caption: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var tex := TextureRect.new()
	tex.custom_minimum_size = Vector2(56, 56)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var data: Dictionary = Monster.KIND_DATA.get(kind, {})
	if not data.is_empty():
		var frames: Dictionary = Monster._build_anim_frames(data, data.get("frame_size", Vector2(64, 64)), data.get("cols", 4))
		var f: Array = frames.get("idle", {}).get("front", [])
		if not f.is_empty():
			tex.texture = f[0]
	box.add_child(tex)
	var l := _label(caption, 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size.x = 64.0
	box.add_child(l)
	return box

# ── Tileset ──────────────────────────────────────────────────────

func _toggle_tileset() -> void:
	if _tileset_panel != null:
		_tileset_panel.get_parent().queue_free()
		_tileset_panel = null
		return
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var d: Dictionary = GameState.MAPS[_map_id]
	var is_image: bool = d.get("image", "") != ""
	# La textura real del TileSet del mapa (la ruta de MAPS es referencial).
	var tex: Texture2D = load(d["tileset"])
	if not is_image and _world._tilemap != null and _world._tilemap.tile_set.get_source_count() > 0:
		var src = _world._tilemap.tile_set.get_source(_world._tilemap.tile_set.get_source_id(0))
		if src is TileSetAtlasSource and src.texture != null:
			tex = src.texture
	var scale_px: float = 1.0 if is_image else 3.0
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 20.0
	root.offset_top = 14.0
	root.offset_right = -20.0
	root.offset_bottom = -14.0
	layer.add_child(root)
	var head := HBoxContainer.new()
	root.add_child(head)
	var title := _label("%s · %s" % [d["name"].to_upper(), d["tileset"].replace("res://assets/", "")], 16)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := _button("CERRAR", 13, _toggle_tileset)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.custom_minimum_size.x = 120.0
	head.add_child(close)
	var hint := _label("Imagen pintada: el área jugable empieza bajo el %d%% superior (playable_top)." % int(float(d.get("playable_top", 0.0)) * 100) if is_image 		else "Rojo = agua/árboles: ahí no aparecen monstruos (painted_world.NON_SPAWNABLE_COORDS). x,y = coordenada en el atlas.", 12)
	hint.modulate.a = 0.8
	root.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	var sheet := TilesetSheet.new()
	sheet.texture = tex
	sheet.px = scale_px
	sheet.show_grid = not is_image
	sheet.blocked = World.NON_SPAWNABLE_COORDS
	sheet.playable_top = float(d.get("playable_top", 0.0)) if is_image else 0.0
	sheet.custom_minimum_size = Vector2(tex.get_width(), tex.get_height()) * scale_px
	scroll.add_child(sheet)
	_tileset_panel = sheet

## Hoja de tiles ampliada con grilla, coordenadas y bloqueados en rojo.
class TilesetSheet extends Control:
	var texture: Texture2D
	var px: float = 3.0
	var show_grid: bool = true
	var blocked: Array = []
	var playable_top: float = 0.0
	func _draw() -> void:
		draw_texture_rect(texture, Rect2(Vector2.ZERO, Vector2(texture.get_width(), texture.get_height()) * px), false)
		if playable_top > 0.0:
			# Línea donde empieza el área jugable de un mapa pintado.
			var y: float = texture.get_height() * px * playable_top
			draw_line(Vector2(0, y), Vector2(texture.get_width() * px, y), Color(1, 0.85, 0.2), 3.0)
			draw_string_outline(ThemeDB.fallback_font, Vector2(8, y - 8), "desde acá se juega", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color.BLACK)
			draw_string(ThemeDB.fallback_font, Vector2(8, y - 8), "desde acá se juega", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.85, 0.2))
		if not show_grid:
			return
		var t: float = 16.0 * px
		var cols := int(texture.get_width() / 16.0)
		var rows := int(texture.get_height() / 16.0)
		var font := ThemeDB.fallback_font
		# Borde + esquina roja: el tile se sigue viendo tal cual.
		for c in blocked:
			var o := Vector2(c.x, c.y) * t
			draw_rect(Rect2(o + Vector2(1, 1), Vector2(t - 2, t - 2)), Color(1, 0.15, 0.1, 0.95), false, 2.0)
			draw_colored_polygon(PackedVector2Array([o + Vector2(t, t), o + Vector2(t - 14, t), o + Vector2(t, t - 14)]), Color(1, 0.15, 0.1, 0.95))
		for x in range(cols + 1):
			draw_line(Vector2(x * t, 0), Vector2(x * t, rows * t), Color(1, 1, 1, 0.25), 1.0)
		for y in range(rows + 1):
			draw_line(Vector2(0, y * t), Vector2(cols * t, y * t), Color(1, 1, 1, 0.25), 1.0)
		for y in range(rows):
			for x in range(cols):
				var p := Vector2(x * t + 2, y * t + 11)
				draw_string_outline(font, p, "%d,%d" % [x, y], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 3, Color(0, 0, 0, 0.9))
				draw_string(font, p, "%d,%d" % [x, y], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1, 0.9))

## Capas dibujadas encima del mundo.
class MapOverlay extends Node2D:
	var viewer = null
	func _draw() -> void:
		if viewer == null or viewer._world == null:
			return
		var world = viewer._world
		var ms: Vector2 = viewer.map_size()
		var origin: Vector2 = -ms / 2.0
		var z: float = maxf(0.05, viewer._camera.zoom.x)
		var line_w: float = 2.0 / z
		if viewer._layers["blocked"]:
			var t: float = viewer.TILE_WORLD
			var cols := int(ms.x / t)
			var rows := int(ms.y / t)
			for y in range(rows):
				for x in range(cols):
					var center := origin + Vector2(x + 0.5, y + 0.5) * t
					if not world.is_spawnable_at(center):
						draw_rect(Rect2(origin + Vector2(x, y) * t, Vector2(t, t)), Color(1, 0.1, 0.1, 0.35))
		if viewer._layers["solid"]:
			for pts in viewer._solid_polys:
				draw_colored_polygon(pts, Color(0.2, 0.8, 1.0, 0.45))
		if viewer._layers["grid"]:
			var t: float = viewer.TILE_WORLD
			var font := ThemeDB.fallback_font
			for x in range(int(ms.x / t) + 1):
				draw_line(origin + Vector2(x * t, 0), origin + Vector2(x * t, ms.y), Color(1, 1, 1, 0.18), line_w * 0.5)
			for y in range(int(ms.y / t) + 1):
				draw_line(origin + Vector2(0, y * t), origin + Vector2(ms.x, y * t), Color(1, 1, 1, 0.18), line_w * 0.5)
			for y in range(0, int(ms.y / t), 5):
				for x in range(0, int(ms.x / t), 5):
					draw_string(font, origin + Vector2(x * t + 3, y * t + 12), "%d,%d" % [x, y], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.85))
		if viewer._layers["ring"]:
			draw_arc(Vector2.ZERO, viewer.SPAWN_INNER, 0.0, TAU, 96, Color(1.0, 0.8, 0.2, 0.9), line_w)
			draw_arc(Vector2.ZERO, viewer.SPAWN_OUTER, 0.0, TAU, 96, Color(1.0, 0.8, 0.2, 0.9), line_w)
			draw_circle(Vector2.ZERO, 12.0 / z, Color(0.3, 1.0, 0.4))
		if viewer._layers["bounds"]:
			draw_rect(Rect2(origin, ms), Color(0.4, 0.8, 1.0, 0.95), false, line_w)
