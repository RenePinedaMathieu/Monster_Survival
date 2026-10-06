"""Plantillas de Tiled para pintar los mapas del juego con los packs de
Craftpix (Forest, Desert y Swamp top-down tilesets).

Uso:
  python tools/build_tiled_templates.py <zip Forest> <zip Desert> <zip Swamp>

Escribe, para cada mapa (bosque, desierto, pantano), en assets/maps/<id>/:
  <id>.tmx       el mapa para abrir en Tiled: del tamaño de una partida
                 (W x H cuadros de 16 px, a escala x1), con las capas del
                 mapa de ejemplo del pack y ese ejemplo puesto al centro
                 (sirve de paleta para copiar piezas), el suelo de base
                 relleno en todo el resto y la capa "choque" arriba.
  tiles/*.tsx    los tilesets del pack (con sus animaciones de agua) y el
  tiles/*.png    de "choque" (rojo: no se camina; verde: sí se camina).
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

# Mapa del juego -> (zip, tmx de ejemplo, relleno: capa -> gid de suelo liso).
MAPS = {
    "bosque": (0, "Forest", {"ground": 6314, "main_space": 7770}),
    "desierto": (1, "Desert", {"sand": 453}),
    "pantano": (2, "Swamp", {"ground": 2931, "main_space": 3372}),
}
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


def write_tsx(node, image_name, path):
    """Tileset externo con la imagen al lado (copia hijos: animaciones)."""
    ts = ET.Element("tileset", {
        "version": "1.10", "tiledversion": "1.10.2", "name": node.get("name"),
        "tilewidth": node.get("tilewidth"), "tileheight": node.get("tileheight"),
        "tilecount": node.get("tilecount"), "columns": node.get("columns"),
    })
    for child in node:
        if child.tag == "image":
            ET.SubElement(ts, "image", {"source": image_name, "width": child.get("width"), "height": child.get("height")})
        else:
            ts.append(child)
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


def build(map_id, zip_path, sample, fill):
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
        write_tsx(node, image, os.path.join(tiles_dir, tsx))
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
        if name.lower().startswith("water") or name in fill:
            occupied |= {(x + ox, y + oy) for x, y in cells}
    # Agua suelta fuera del recuadro del suelo (el desierto trae una
    # franja vacía): también va con relleno.
    ground = [(x + ox, y + oy) for name, cells in layers if name in fill for x, y in cells]
    gx0, gy0 = min(c[0] for c in ground), min(c[1] for c in ground)
    gx1, gy1 = max(c[0] for c in ground), max(c[1] for c in ground)
    occupied = {c for c in occupied if gx0 <= c[0] <= gx1 and gy0 <= c[1] <= gy1}
    next_id = 1
    for name, cells in layers:
        grid = [[0] * W for _ in range(H)]
        if name in fill:
            # Relleno sólo donde el ejemplo no tiene suelo ni agua.
            for y in range(H):
                for x in range(W):
                    if (x, y) not in occupied:
                        grid[y][x] = fill[name]
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
    ET.ElementTree(tmx).write(os.path.join(out_dir, map_id + ".tmx"), encoding="UTF-8", xml_declaration=True)
    print(map_id, "listo:", len(layers), "capas, ejemplo en", (ox + x0, oy + y0))


if __name__ == "__main__":
    if len(sys.argv) < 4:
        raise SystemExit(__doc__)
    for map_id, (i, sample, fill) in MAPS.items():
        build(map_id, sys.argv[1 + i], sample, fill)
