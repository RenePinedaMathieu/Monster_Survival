"""Plantillas de Tiled para pintar los mapas del juego con los packs de
Craftpix (Forest, Desert y Swamp top-down tilesets).

Uso:
  python tools/build_tiled_templates.py <zip Forest> <zip Desert> <zip Swamp> [mapas...]
  (sin mapas: los tres; OJO: rearmar una plantilla borra lo pintado en ella)

Escribe, para cada mapa (bosque, desierto, pantano), en assets/maps/<id>/:
  <id>.tmx       el mapa para abrir en Tiled: del tamaño de una partida
                 (W x H cuadros de 16 px, a escala x1), con las capas del
                 mapa de ejemplo del pack y ese ejemplo puesto al centro
                 (sirve de paleta para copiar piezas), agua debajo de todo,
                 el suelo de base (pasto o arena) encima y la capa
                 "choque" arriba.
  tiles/*.tsx    los tilesets del pack (con sus animaciones de agua) y el
  tiles/*.png    de "choque" (rojo: no se camina; verde: sí se camina).
                 Las orillas (Water_coasts.tsx) traen pinceles de terreno
                 de Tiled: pintar "Sin pasto" abre un hueco con orilla y
                 deja ver el agua (o la tierra) de abajo.
Cómo se pinta y qué lee el juego: assets/maps/COMO_PINTAR.md. El mapa
pintado se lleva al juego con tools/import_tiled_map.gd. Necesita Pillow.
"""
import io
import os
import sys
import zipfile
import xml.etree.ElementTree as ET

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "maps")
W, H = 200, 160
TW = 16
FLIP_MASK = 0x1FFFFFFF

# Mapa del juego -> zip (índice en los argumentos), tmx de ejemplo,
# "fill": capa -> gid del suelo que cubre todo fuera del ejemplo (el
# centro de la isla del pincel de terreno, así pegan sin costura),
# "water": la capa de agua de abajo y su gid, "ground": capas de suelo
# del ejemplo, "wang": pinceles de terreno de las orillas (nombre,
# color de suelo, color sin suelo, esquina de la isla 3x3, esquina del
# hueco 2x2 en Water_coasts).
MAPS = {
    "bosque": {"zip": 0, "sample": "Forest", "fill": {"main_space": 5954}, "water": ("water", 1),
               "ground": ("ground", "main_space"),
               "wang": [("Pasto y agua", "Pasto", "Sin pasto", (0, 5), (3, 5), "#6aa84f"),
                        ("Tierra y agua", "Tierra", "Sin tierra", (0, 1), (3, 1), "#8b6b4a")]},
    "desierto": {"zip": 1, "sample": "Desert", "fill": {"sand": 6984}, "water": ("water", 6923),
                 "ground": ("sand",),
                 "wang": [("Arena y agua", "Arena", "Sin arena", (0, 1), (3, 1), "#d4b06a"),
                          ("Pasto y agua", "Pasto", "Sin pasto", (0, 5), (3, 5), "#9a9a3c")]},
    "pantano": {"zip": 2, "sample": "Swamp", "fill": {"main_space": 3514}, "water": ("water", 1),
                "ground": ("ground", "main_space"),
                "wang": [("Pasto y agua", "Pasto", "Sin pasto", (2, 1), (5, 1), "#8fa548"),
                         ("Tierra y agua", "Tierra", "Sin tierra", (13, 1), (16, 1), "#7a6a3a")]},
}
## Baldosa transparente de Water_coasts (la de "sin suelo").
EMPTY_TILE = 1
# Esquinas (arriba-izq, arriba-der, abajo-der, abajo-izq) de cada pieza:
# 1 = suelo, 2 = sin suelo (agua).
_L, _W = 1, 2
ISLAND = {(0, 0): (_W, _W, _L, _W), (1, 0): (_W, _W, _L, _L), (2, 0): (_W, _W, _W, _L),
          (0, 1): (_W, _L, _L, _W), (1, 1): (_L, _L, _L, _L), (2, 1): (_L, _W, _W, _L),
          (0, 2): (_W, _L, _W, _W), (1, 2): (_L, _L, _W, _W), (2, 2): (_L, _W, _W, _W)}
HOLE = {(0, 0): (_L, _L, _W, _L), (1, 0): (_L, _L, _L, _W), (0, 1): (_L, _W, _L, _L), (1, 1): (_W, _L, _L, _L)}
CHOQUE_LAYER = "choque"


def chunk_cells(layer):
    """Celdas de una capa de mapa infinito (por chunks) o fijo."""
    cells = {}
    data = layer.find("data")
    chunks = data.findall("chunk")
    if chunks:
        for ch in chunks:
            cx, cy, w = int(ch.get("x")), int(ch.get("y")), int(ch.get("width"))
            vals = [int(v) for v in ch.text.replace("\n", "").split(",") if v.strip()]
            for k, g in enumerate(vals):
                if g:
                    cells[(cx + k % w, cy + k // w)] = g
    elif data.text and data.text.strip():
        w = int(layer.get("width"))
        vals = [int(v) for v in data.text.replace("\n", "").split(",") if v.strip()]
        for k, g in enumerate(vals):
            if g:
                cells[(k % w, k // w)] = g
    return cells


def wangsets(columns, sets):
    """Pinceles de terreno de Tiled (tipo esquina) para las orillas."""
    root = ET.Element("wangsets")
    for name, land, empty, island, hole, color in sets:
        center = (island[1] + 1) * columns + island[0] + 1
        ws = ET.SubElement(root, "wangset", {"name": name, "type": "corner", "tile": str(center)})
        ET.SubElement(ws, "wangcolor", {"name": land, "color": color, "tile": str(center), "probability": "1"})
        ET.SubElement(ws, "wangcolor", {"name": empty, "color": "#3b6fb6", "tile": str(EMPTY_TILE), "probability": "1"})
        pieces = [((island[0] + dx, island[1] + dy), c) for (dx, dy), c in ISLAND.items()]
        pieces += [((hole[0] + dx, hole[1] + dy), c) for (dx, dy), c in HOLE.items()]
        pieces.append(((EMPTY_TILE % columns, EMPTY_TILE // columns), (_W, _W, _W, _W)))
        for (x, y), (tl, tr, br, bl) in pieces:
            # Orden de Tiled: arriba, arriba-der, der, abajo-der, abajo, abajo-izq, izq, arriba-izq.
            ET.SubElement(ws, "wangtile", {"tileid": str(y * columns + x), "wangid": "0,%d,0,%d,0,%d,0,%d" % (tr, br, bl, tl)})
    return root


def write_tsx(node, image_name, path, extra=None):
    """Tileset externo con la imagen al lado (copia hijos: animaciones)."""
    ts = ET.Element("tileset", {
        "version": "1.10", "tiledversion": "1.10.2", "name": node.get("name"),
        "tilewidth": node.get("tilewidth"), "tileheight": node.get("tileheight"),
        "tilecount": node.get("tilecount"), "columns": node.get("columns"),
    })
    for child in node:
        if child.tag == "image":
            ET.SubElement(ts, "image", {"source": image_name, "width": child.get("width"), "height": child.get("height")})
        elif child.tag != "wangsets":
            ts.append(child)
    if extra is not None:
        ts.append(extra)
    ET.ElementTree(ts).write(path, encoding="UTF-8", xml_declaration=True)


def choque_tileset(tiles_dir):
    img = Image.new("RGBA", (2 * TW, TW), (0, 0, 0, 0))
    for x in range(TW):
        for y in range(TW):
            edge = x in (0, TW - 1) or y in (0, TW - 1)
            img.putpixel((x, y), (230, 40, 40, 230 if edge else 120))
            img.putpixel((TW + x, y), (40, 200, 80, 230 if edge else 120))
    img.save(os.path.join(tiles_dir, "choque.png"))
    ts = ET.Element("tileset", {"version": "1.10", "tiledversion": "1.10.2", "name": "choque",
                                "tilewidth": str(TW), "tileheight": str(TW), "tilecount": "2", "columns": "2"})
    ET.SubElement(ts, "image", {"source": "choque.png", "width": str(2 * TW), "height": str(TW)})
    for tid, name in ((0, "choque"), (1, "libre")):
        tile = ET.SubElement(ts, "tile", {"id": str(tid)})
        props = ET.SubElement(tile, "properties")
        ET.SubElement(props, "property", {"name": "tipo", "value": name})
    ET.ElementTree(ts).write(os.path.join(tiles_dir, "choque.tsx"), encoding="UTF-8", xml_declaration=True)


def build(map_id, zip_path, cfg):
    sample, fill = cfg["sample"], cfg["fill"]
    water_layer, water_gid = cfg["water"]
    z = zipfile.ZipFile(zip_path)
    src = ET.fromstring(z.read("Tiled_files/%s.tmx" % sample))
    out_dir = os.path.join(OUT, map_id)
    tiles_dir = os.path.join(out_dir, "tiles")
    os.makedirs(tiles_dir, exist_ok=True)

    tmx = ET.Element("map", {
        "version": "1.10", "tiledversion": "1.10.2", "orientation": "orthogonal", "renderorder": "right-down",
        "width": str(W), "height": str(H), "tilewidth": str(TW), "tileheight": str(TW), "infinite": "0",
    })
    last_gid = 1
    for t in src.findall("tileset"):
        node = ET.fromstring(z.read("Tiled_files/" + t.get("source"))) if t.get("source") else t
        image = node.find("image").get("source")
        with open(os.path.join(tiles_dir, image), "wb") as f:
            f.write(z.read("Tiled_files/" + image))
        tsx = node.get("name") + ".tsx"
        extra = wangsets(int(node.get("columns")), cfg["wang"]) if node.get("name") == "Water_coasts" else None
        write_tsx(node, image, os.path.join(tiles_dir, tsx), extra)
        ET.SubElement(tmx, "tileset", {"firstgid": t.get("firstgid"), "source": "tiles/" + tsx})
        last_gid = max(last_gid, int(t.get("firstgid")) + int(node.get("tilecount")))
    choque_tileset(tiles_dir)
    ET.SubElement(tmx, "tileset", {"firstgid": str(last_gid), "source": "tiles/choque.tsx"})

    layers = [(l.get("name"), chunk_cells(l)) for l in src.iter("layer")]
    used = [c for _, cells in layers for c in cells]
    x0, y0 = min(c[0] for c in used), min(c[1] for c in used)
    x1, y1 = max(c[0] for c in used), max(c[1] for c in used)
    ox, oy = (W - (x1 - x0 + 1)) // 2 - x0, (H - (y1 - y0 + 1)) // 2 - y0
    # El suelo del ejemplo: su agua y sus capas de suelo. Fuera de eso
    # (también baldosas sueltas lejos del centro) va el relleno.
    occupied = set()
    for name, cells in layers:
        if name.lower().startswith("water") or name in cfg["ground"]:
            occupied |= {(x + ox, y + oy) for x, y in cells}
    # Agua suelta fuera del recuadro del suelo (el desierto trae una
    # franja vacía): también va con relleno.
    ground = [(x + ox, y + oy) for name, cells in layers if name in cfg["ground"] for x, y in cells]
    gx0, gy0 = min(c[0] for c in ground), min(c[1] for c in ground)
    gx1, gy1 = max(c[0] for c in ground), max(c[1] for c in ground)
    occupied = {c for c in occupied if gx0 <= c[0] <= gx1 and gy0 <= c[1] <= gy1}
    next_id = 1
    filled = set()
    for name, cells in layers:
        grid = [[0] * W for _ in range(H)]
        # Relleno (sólo la primera capa con ese nombre: el desierto trae
        # dos "sand") donde el ejemplo no tiene suelo ni agua; el agua va
        # debajo de todo, para que al abrir el suelo se vea.
        base = water_gid if name == water_layer else fill.get(name, 0)
        if base and name not in filled:
            filled.add(name)
            for y in range(H):
                for x in range(W):
                    if (x, y) not in occupied:
                        grid[y][x] = base
        for (x, y), g in cells.items():
            grid[y + oy][x + ox] = g
        layer = ET.SubElement(tmx, "layer", {"id": str(next_id), "name": name, "width": str(W), "height": str(H)})
        data = ET.SubElement(layer, "data", {"encoding": "csv"})
        data.text = "\n" + ",\n".join(",".join(str(v) for v in row) for row in grid) + "\n"
        next_id += 1
    layer = ET.SubElement(tmx, "layer", {"id": str(next_id), "name": CHOQUE_LAYER, "width": str(W), "height": str(H), "opacity": "0.6"})
    data = ET.SubElement(layer, "data", {"encoding": "csv"})
    data.text = "\n" + ",\n".join(",".join("0" for _ in range(W)) for _ in range(H)) + "\n"
    tmx.set("nextlayerid", str(next_id + 1))
    tmx.set("nextobjectid", "1")
    # En Windows "Bosque.tmx" y "bosque.tmx" son el mismo archivo: se
    # borra antes para que quede con el nombre en minúsculas.
    for f in os.listdir(out_dir):
        if f.lower() == map_id + ".tmx":
            os.remove(os.path.join(out_dir, f))
    ET.ElementTree(tmx).write(os.path.join(out_dir, map_id + ".tmx"), encoding="UTF-8", xml_declaration=True)
    print(map_id, "listo:", len(layers), "capas, ejemplo en", (ox + x0, oy + y0))


if __name__ == "__main__":
    if len(sys.argv) < 4:
        raise SystemExit(__doc__)
    only = sys.argv[4:]
    for map_id, cfg in MAPS.items():
        if not only or map_id in only:
            build(map_id, sys.argv[1 + cfg["zip"]], cfg)
