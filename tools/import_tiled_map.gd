extends SceneTree

## Lleva al juego un mapa pintado en Tiled. Uso:
##   godot --headless --path . --script tools/import_tiled_map.gd -- <id> [otro.tmx]
## (con otro.tmx: un archivo de la misma carpeta, sale como scenes/maps/otro.scn)
## Lee assets/maps/<id>/<id>.tmx (plantilla de tools/build_tiled_templates.py)
## y escribe scenes/maps/<id>.scn con el script scenes/tiled_map.gd:
##   - Capas planas (todas las de antes de la primera "objects" u
##     "objectsN"):
##     TileMapLayer debajo de todo, en el orden de Tiled.
##   - Capas de objetos (desde esa y todas las de más arriba): un
##     TileMapLayer ordenado por altura cada una. Cada grupo de baldosas
##     que se tocan es un objeto; todas sus baldosas se ordenan por la
##     base del objeto (y_sort_origin), así el héroe pasa por detrás de la
##     copa y por delante del tronco.
##   - Choque (celdas de 8 px): el agua (por color, también la de las
##     orillas), la base opaca de los objetos de 32 px de alto o más
##     y lo pintado en "choque" (rojo: choca; verde: no choca, gana a todo).
## Las capas ocultas en Tiled no se importan. Ver assets/maps/COMO_PINTAR.md.

const TILE := 16
const CELL := 8
const FLIP_H := 0x80000000
const FLIP_V := 0x40000000
const FLIP_D := 0x20000000
const GID_MASK := 0x1FFFFFFF
const CHOQUE_LAYER := "choque"
## Lo que flota sobre el agua cuenta como agua.
const WATER_EXTRA := ["duskweed", "duckweed", "water_lilies", "water_lilis"]
## Objetos más bajos que esto (flores, pasto, hongos, matas) no chocan.
const MIN_SOLID_HEIGHT := 32
## El héroe y los monstruos se ordenan por el centro del cuerpo y los
## pies están unos 12 px más abajo: los objetos se ordenan 12 px más
## arriba de su base para comparar pies con base.
const FEET_OFFSET := 12
const OPAQUE := 0.78

var _w := 0
var _h := 0
var _dir := ""
var _tilesets: Array = []   # {firstgid, name, columns, count, tw, th, image, sid, img}
var _layers: Array = []     # {name, visible, data: PackedInt32Array}

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Falta el id del mapa: -- bosque")
		quit(1)
		return
	var id: String = args[0]
	_dir = "res://assets/maps/%s" % id
	var t0 := Time.get_ticks_msec()
	# Otro .tmx de la misma carpeta (una copia de prueba): -- bosque otro.tmx
	var tmx: String = "%s/%s" % [_dir, args[1]] if args.size() > 1 else "%s/%s.tmx" % [_dir, id]
	if args.size() > 1:
		id = args[1].get_basename()
	_parse_tmx(tmx)
	var root := _build()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/maps"))
	var packed := PackedScene.new()
	packed.pack(root)
	var out := "res://scenes/maps/%s.scn" % id
	var err := ResourceSaver.save(packed, out)
	print("%s -> %s (%s) en %d ms" % [id, out, "ok" if err == OK else "ERROR %d" % err, Time.get_ticks_msec() - t0])
	root.free()
	quit(0 if err == OK else 1)

# ── Leer Tiled ────────────────────────────────────────────────────

func _parse_tmx(path: String) -> void:
	var p := XMLParser.new()
	if p.open(path) != OK:
		push_error("No se pudo abrir " + path)
		return
	var layer: Dictionary = {}
	var in_data := false
	while p.read() == OK:
		match p.get_node_type():
			XMLParser.NODE_ELEMENT:
				match p.get_node_name():
					"map":
						_w = int(p.get_named_attribute_value("width"))
						_h = int(p.get_named_attribute_value("height"))
						if p.get_named_attribute_value_safe("infinite") == "1":
							push_error("El mapa es infinito: en Tiled, Mapa > Propiedades > Infinito: no")
					"tileset":
						_load_tsx(_dir + "/" + p.get_named_attribute_value("source"), int(p.get_named_attribute_value("firstgid")))
					"layer":
						layer = {"name": p.get_named_attribute_value("name"),
							"visible": p.get_named_attribute_value_safe("visible") != "0",
							"data": PackedInt32Array()}
					"data":
						if p.get_named_attribute_value_safe("encoding") != "csv":
							push_error("La capa %s no está en CSV: en Tiled, Mapa > Propiedades > Formato de capa: CSV" % layer.get("name", "?"))
						in_data = true
			XMLParser.NODE_TEXT:
				if in_data and not layer.is_empty():
					layer["data"].append_array(_csv(p.get_node_data()))
			XMLParser.NODE_ELEMENT_END:
				match p.get_node_name():
					"data":
						in_data = false
					"layer":
						if layer["data"].size() == _w * _h:
							_layers.append(layer)
						else:
							push_error("Capa %s: %d celdas en vez de %d" % [layer["name"], layer["data"].size(), _w * _h])
						layer = {}
	_tilesets.sort_custom(func(a, b): return a["firstgid"] < b["firstgid"])

func _csv(text: String) -> PackedInt32Array:
	var out := PackedInt32Array()
	for v in text.split(",", false):
		var s := v.strip_edges()
		if s != "":
			# Los gid con espejado pasan de 2^31: se guardan como el mismo
			# patrón de bits en un int de 32.
			out.append(int(s))
	return out

func _load_tsx(path: String, firstgid: int) -> void:
	var p := XMLParser.new()
	p.open(path)
	var ts := {"firstgid": firstgid}
	while p.read() == OK:
		if p.get_node_type() != XMLParser.NODE_ELEMENT:
			continue
		if p.get_node_name() == "tileset":
			ts["name"] = p.get_named_attribute_value("name")
			ts["tw"] = int(p.get_named_attribute_value("tilewidth"))
			ts["th"] = int(p.get_named_attribute_value("tileheight"))
			ts["count"] = int(p.get_named_attribute_value("tilecount"))
			ts["columns"] = int(p.get_named_attribute_value("columns"))
		elif p.get_node_name() == "image" and not ts.has("image"):
			ts["image"] = path.get_base_dir() + "/" + p.get_named_attribute_value("source")
	_tilesets.append(ts)

func _tileset_of(gid: int) -> Dictionary:
	var g := gid & GID_MASK
	var found: Dictionary = {}
	for ts in _tilesets:
		if g >= ts["firstgid"]:
			found = ts
	return found

# ── Armar la escena ───────────────────────────────────────────────

func _build() -> Node2D:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE, TILE)
	for ts in _tilesets:
		if ts["name"] == CHOQUE_LAYER:
			continue
		var src := TileSetAtlasSource.new()
		src.texture = load(ts["image"])
		src.texture_region_size = Vector2i(ts["tw"], ts["th"])
		ts["sid"] = tile_set.add_source(src)
		ts["img"] = Image.load_from_file(ProjectSettings.globalize_path(ts["image"]))
		ts["img"].convert(Image.FORMAT_RGBA8)
	# Objetos desde la primera capa "objects", "objects1", "Objects4"...
	# ("objects_under_elevated_space" es plana: va bajo la meseta).
	var obj_re := RegEx.create_from_string("^objects[0-9]*$")
	var obj_start := _layers.size()
	for i in range(_layers.size()):
		if obj_re.search(String(_layers[i]["name"]).to_lower()) != null:
			obj_start = i
			break

	var root := Node2D.new()
	root.name = "TiledMap"
	root.set_script(load("res://scenes/tiled_map.gd"))
	root.y_sort_enabled = true
	var ground := Node2D.new()
	ground.name = "Suelo"
	ground.z_index = -10
	root.add_child(ground)
	var objects := Node2D.new()
	objects.name = "Objetos"
	objects.y_sort_enabled = true
	root.add_child(objects)

	var gw := _w * TILE / CELL
	var gh := _h * TILE / CELL
	var solid := PackedByteArray()
	solid.resize(gw * gh)
	var free := PackedByteArray()
	free.resize(gw * gh)

	_water(obj_start, solid, gw)

	# Orden por altura: base de cada objeto -> y_sort_origin de sus baldosas.
	var origins := {}   # "sid:x:y:flags" -> {origen: veces}
	for li in range(obj_start, _layers.size()):
		var layer: Dictionary = _layers[li]
		if not layer["visible"] or layer["name"] == CHOQUE_LAYER:
			continue
		for comp in _components(layer["data"]):
			_object(layer["data"], comp, origins, solid, gw)

	# Capas de Tiled -> TileMapLayer.
	var alts := {}
	for li in range(_layers.size()):
		var layer: Dictionary = _layers[li]
		if not layer["visible"]:
			continue
		if layer["name"] == CHOQUE_LAYER:
			_choque(layer["data"], solid, free, gw)
			continue
		var tml := TileMapLayer.new()
		tml.name = layer["name"]
		tml.tile_set = tile_set
		if li >= obj_start:
			tml.y_sort_enabled = true
			objects.add_child(tml)
		else:
			ground.add_child(tml)
		var data: PackedInt32Array = layer["data"]
		for i in range(data.size()):
			var gid := data[i]
			if gid == 0:
				continue
			var ts := _tileset_of(gid)
			if ts.is_empty() or not ts.has("sid"):
				continue
			var local := (gid & GID_MASK) - int(ts["firstgid"])
			var atlas := Vector2i(local % int(ts["columns"]), local / int(ts["columns"]))
			var alt := _alternative(tile_set, ts, atlas, gid, alts, origins)
			tml.set_cell(Vector2i(i % _w, i / _w), ts["sid"], atlas, alt)

	for i in range(solid.size()):
		if free[i]:
			solid[i] = 0
	var body := StaticBody2D.new()
	body.name = "Choque"
	# Capa 4: la de los árboles y el agua de los mapas de siempre (los
	# voladores la atraviesan).
	body.collision_layer = 4
	body.collision_mask = 0
	root.add_child(body)
	for r in _rects(solid, gw, gh):
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = r.size
		shape.shape = rect
		shape.position = r.get_center()
		body.add_child(shape)

	root.map_size = Vector2(_w * TILE, _h * TILE)
	root.cell = CELL
	root.grid_size = Vector2i(gw, gh)
	root.solid = solid
	_own(root, root)
	return root

func _own(node: Node, owner_node: Node) -> void:
	for c in node.get_children():
		c.owner = owner_node
		_own(c, owner_node)

## Variante de la baldosa con su espejado y su origen de orden.
func _alternative(tile_set: TileSet, ts: Dictionary, atlas: Vector2i, gid: int, alts: Dictionary, origins: Dictionary) -> int:
	var flags := gid & (FLIP_H | FLIP_V | FLIP_D)
	var key := "%d:%d:%d:%d" % [ts["sid"], atlas.x, atlas.y, flags]
	if alts.has(key):
		return alts[key]
	var src: TileSetAtlasSource = tile_set.get_source(ts["sid"])
	if not src.has_tile(atlas):
		src.create_tile(atlas)
	var alt := 0
	if flags != 0:
		alt = src.create_alternative_tile(atlas)
		var td := src.get_tile_data(atlas, alt)
		# Tiled: primero la diagonal (trasponer), después los espejos.
		td.transpose = flags & FLIP_D != 0
		td.flip_h = flags & FLIP_H != 0
		td.flip_v = flags & FLIP_V != 0
	if origins.has(key):
		var best := 0
		var best_n := -1
		for o in origins[key]:
			if origins[key][o] > best_n:
				best_n = origins[key][o]
				best = o
		src.get_tile_data(atlas, alt).y_sort_origin = best
	alts[key] = alt
	return alt

## Grupos de baldosas que se tocan (en 8 direcciones) de una capa.
func _components(data: PackedInt32Array) -> Array:
	var seen := PackedByteArray()
	seen.resize(data.size())
	var out: Array = []
	for i in range(data.size()):
		if data[i] == 0 or seen[i]:
			continue
		var comp := PackedInt32Array()
		var stack := [i]
		seen[i] = 1
		while not stack.is_empty():
			var c: int = stack.pop_back()
			comp.append(c)
			var cx := c % _w
			var cy := c / _w
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var nx: int = cx + dx
					var ny: int = cy + dy
					if nx < 0 or ny < 0 or nx >= _w or ny >= _h:
						continue
					var n: int = ny * _w + nx
					if data[n] != 0 and not seen[n]:
						seen[n] = 1
						stack.append(n)
		out.append(comp)
	return out

## Un objeto: anota el origen de orden de sus baldosas y, si es alto,
## marca sólida su base opaca.
func _object(data: PackedInt32Array, comp: PackedInt32Array, origins: Dictionary, solid: PackedByteArray, gw: int) -> void:
	var x0 := _w
	var y0 := _h
	var x1 := 0
	var y1 := 0
	for c in comp:
		x0 = mini(x0, c % _w)
		x1 = maxi(x1, c % _w)
		y0 = mini(y0, c / _w)
		y1 = maxi(y1, c / _w)
	var img := Image.create((x1 - x0 + 1) * TILE, (y1 - y0 + 1) * TILE, false, Image.FORMAT_RGBA8)
	for c in comp:
		var gid := data[c]
		var ts := _tileset_of(gid)
		if ts.is_empty() or not ts.has("sid"):
			continue
		var local := (gid & GID_MASK) - int(ts["firstgid"])
		var atlas := Vector2i(local % int(ts["columns"]), local / int(ts["columns"]))
		var flags := gid & (FLIP_H | FLIP_V | FLIP_D)
		var key := "%d:%d:%d:%d" % [ts["sid"], atlas.x, atlas.y, flags]
		var origin := (y1 - c / _w) * TILE + TILE / 2 - FEET_OFFSET
		if not origins.has(key):
			origins[key] = {}
		origins[key][origin] = int(origins[key].get(origin, 0)) + 1
		img.blit_rect(_tile_image(gid), Rect2i(0, 0, TILE, TILE), Vector2i((c % _w - x0) * TILE, (c / _w - y0) * TILE))
	var used := img.get_used_rect()
	if used.size.y < MIN_SOLID_HEIGHT:
		return
	# Base: la franja opaca de abajo (sin la sombra, que es transparente).
	var bottom := -1
	for y in range(used.end.y - 1, used.position.y - 1, -1):
		for x in range(used.position.x, used.end.x):
			if img.get_pixel(x, y).a >= OPAQUE:
				bottom = y
				break
		if bottom >= 0:
			break
	if bottom < 0:
		return
	var band := clampi(used.size.y / 4, 4, 12)
	var counts := {}
	for y in range(maxi(0, bottom - band + 1), bottom + 1):
		for x in range(used.position.x, used.end.x):
			if img.get_pixel(x, y).a >= OPAQUE:
				var cell := Vector2i((x0 * TILE + x) / CELL, (y0 * TILE + y) / CELL)
				counts[cell] = int(counts.get(cell, 0)) + 1
	for cell in counts:
		if counts[cell] >= CELL * 2:
			solid[cell.y * gw + cell.x] = 1

## Agua por color: la paleta son los colores de las baldosas de las
## capas de agua; donde se usa un tileset de agua (agua, orillas), se
## arma lo que se ve de las capas planas y cada celda de 8 px que es
## agua en más de 60 % choca. Así las orillas pintadas con baldosas
## de costa también quedan bien.
func _water(obj_start: int, solid: PackedByteArray, gw: int) -> void:
	var palette := {}
	for li in range(obj_start):
		var layer: Dictionary = _layers[li]
		var n := String(layer["name"]).to_lower()
		# Sin los nenúfares ni la lenteja: su verde se parece al pasto.
		if not layer["visible"] or not n.begins_with("water") or n.contains("lil"):
			continue
		var seen := {}
		for gid in layer["data"]:
			if gid == 0 or seen.has(gid):
				continue
			seen[gid] = true
			var img := _tile_image(gid)
			if img == null:
				continue
			for y in range(TILE):
				for x in range(TILE):
					var c := img.get_pixel(x, y)
					if c.a >= OPAQUE:
						palette[c.to_rgba32()] = true
	if palette.is_empty():
		return
	var k := TILE / CELL
	for i in range(_w * _h):
		# De arriba hacia abajo: un suelo opaco tapa todo lo de abajo.
		var watery := false
		for li in range(obj_start - 1, -1, -1):
			var gid: int = _layers[li]["data"][i]
			if gid == 0 or not _layers[li]["visible"]:
				continue
			if String(_tileset_of(gid).get("name", "")).to_lower().contains("water"):
				watery = true
			if _is_opaque(gid):
				break
		if not watery:
			continue
		var cell := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
		for li in range(obj_start):
			var gid: int = _layers[li]["data"][i]
			if gid == 0 or not _layers[li]["visible"]:
				continue
			var img := _tile_image(gid)
			if img != null:
				cell.blend_rect(img, Rect2i(0, 0, TILE, TILE), Vector2i.ZERO)
		for sy in range(k):
			for sx in range(k):
				var n := 0
				for y in range(sy * CELL, (sy + 1) * CELL):
					for x in range(sx * CELL, (sx + 1) * CELL):
						if palette.has(cell.get_pixel(x, y).to_rgba32()):
							n += 1
				if n >= CELL * CELL * 0.6:
					solid[((i / _w) * k + sy) * gw + (i % _w) * k + sx] = 1

var _tile_cache := {}
var _opaque_cache := {}

## La baldosa tapa todo su cuadro (nada de lo de abajo se ve).
func _is_opaque(gid: int) -> bool:
	if _opaque_cache.has(gid):
		return _opaque_cache[gid]
	var img := _tile_image(gid)
	var full := img != null
	if full:
		for y in range(TILE):
			for x in range(TILE):
				if img.get_pixel(x, y).a < OPAQUE:
					full = false
					break
			if not full:
				break
	_opaque_cache[gid] = full
	return full

## Imagen de una baldosa (con su espejado), o null si es de "choque".
func _tile_image(gid: int) -> Image:
	if _tile_cache.has(gid):
		return _tile_cache[gid]
	var ts := _tileset_of(gid)
	var img: Image = null
	if not ts.is_empty() and ts.has("img"):
		var local := (gid & GID_MASK) - int(ts["firstgid"])
		var atlas := Vector2i(local % int(ts["columns"]), local / int(ts["columns"]))
		img = ts["img"].get_region(Rect2i(atlas * TILE, Vector2i(TILE, TILE)))
		if gid & FLIP_D:
			img.rotate_90(CLOCKWISE)
			img.flip_x()
		if gid & FLIP_H:
			img.flip_x()
		if gid & FLIP_V:
			img.flip_y()
	_tile_cache[gid] = img
	return img

func _mark_tile(grid: PackedByteArray, gw: int, tx: int, ty: int) -> void:
	var k := TILE / CELL
	for dy in range(k):
		for dx in range(k):
			grid[(ty * k + dy) * gw + tx * k + dx] = 1

## Capa "choque": baldosa 0 (roja) choca, 1 (verde) no choca.
func _choque(data: PackedInt32Array, solid: PackedByteArray, free: PackedByteArray, gw: int) -> void:
	for i in range(data.size()):
		if data[i] == 0:
			continue
		var ts := _tileset_of(data[i])
		if ts.get("name", "") != CHOQUE_LAYER:
			continue
		var local := (data[i] & GID_MASK) - int(ts["firstgid"])
		_mark_tile(free if local == 1 else solid, gw, i % _w, i / _w)

## Celdas sólidas -> rectángulos: tramos por fila y, los que se repiten
## igual en la fila de abajo, se juntan.
func _rects(solid: PackedByteArray, gw: int, gh: int) -> Array:
	var open := {}   # "x0:x1" -> Rect2
	var out: Array = []
	for y in range(gh):
		var runs := {}
		var x := 0
		while x < gw:
			if solid[y * gw + x] == 0:
				x += 1
				continue
			var xs := x
			while x < gw and solid[y * gw + x] != 0:
				x += 1
			runs["%d:%d" % [xs, x]] = Vector2i(xs, x)
		for k in open.keys():
			if not runs.has(k):
				out.append(open[k])
				open.erase(k)
		for k in runs:
			if open.has(k):
				var r: Rect2 = open[k]
				r.size.y += CELL
				open[k] = r
			else:
				var run: Vector2i = runs[k]
				open[k] = Rect2(run.x * CELL, y * CELL, (run.y - run.x) * CELL, CELL)
	for k in open:
		out.append(open[k])
	return out
