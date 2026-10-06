"""El pueblo (pantalla de inicio caminable) desde dos packs de Craftpix
del mismo autor: "Market Square" (plaza, muros, portones) y "Training
Arena" (la arena de los desafíos).

Uso:
  python tools/build_village.py <zip Market Square> <zip Training Arena>
  (craftpix-net-587497-...-market-square-...zip,
   craftpix-net-626036-pixel-art-training-arena-tileset-for-rpg-games.zip)

Escribe en assets/ui/village/:
  base.png      suelo, muros y cercas del pueblo entero. Se arma por
                columnas con los mapas de ejemplo de los packs: la plaza
                con tres portones al norte (uno por mapa) y uno al sur
                (reto diario), la arena a la derecha y un muro a cada
                costado.
  props/*.png   adornos de la arena (armeros, blancos, palco, bancas)
                sueltos, para ordenarlos por altura con el héroe.
  pieces/*.png  toldo, estandartes y la barricada de los portones cerrados.
  npc/*.png     hojas del entrenador, luchadores, arqueros y nobles.
  village_layout.gd  tamaño, qué celdas de 8 px son sólidas, dónde va
                cada adorno y los portones (un script: un .json no
                entraría en la exportación).
Los puestos y la gente de la plaza salen de assets/ui/plaza (ver
tools/build_plaza.py). Qué aparece y dónde lo decide scenes/village.gd.
Necesita Pillow.
"""
import io
import os
import sys
import zipfile
import xml.etree.ElementTree as ET

from PIL import Image

from build_plaza import clean_piece

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "ui", "village")
TW = 16
CELL = 8   # resolución de la grilla de choque

# ── Plaza (Market_square.tmx): columnas de origen ──────────────────
# El mapa de ejemplo tiene un portón al centro del muro norte y otro
# en el sur (columnas 0..2). Repitiendo grupos de columnas salen tres
# portones; en el sur sólo queda abierto el del medio.
M_LEFT = [-10, -9, -8, -7]            # esquina con el cantero en L
M_PLAIN = [-6, -5, -4]                # muro liso con cantero
M_BED_END = [-3, -2, -1]              # termina el cantero
M_GATE = [0, 1, 2]                    # el portón
M_BED_START = [3, 4, 5, 6, 7, 8]      # empieza el cantero
M_JOIN = [3, 4, -2, -1, 3, 4]         # muro sin cantero, antes de la arena
M_COLS = (M_LEFT + M_PLAIN * 2 + M_BED_END + M_GATE + M_BED_START
          + M_PLAIN + M_BED_END + M_GATE + M_BED_START
          + M_PLAIN + M_BED_END + M_GATE + M_JOIN)
M_ROWS = list(range(-10, -1)) + [-1, 0] * 3 + list(range(1, 6))   # 20 filas
M_BASE = ["street", "walls_grass", "details", "Walls_top"]
M_SOLID = ["walls_grass", "Walls_top"]
SOUTH_GATE = 1          # cuál de los tres portones queda abierto al sur
GATE_CLOSED = [-5, -4, -6]  # muro liso que tapa los otros dos al sur

# ── Arena (Training_ground.tmx) ────────────────────────────────────
A_COLS = list(range(17, 41))
A_ROW0 = -2             # fila de la arena que va en la fila 0 del pueblo
A_FLAT = ["Floor", "sand", "straw", "details", "carpet", "Shadow"]
A_SOLID = ["Walls_sand", "border", "fence_top"]   # cercas y sogas
A_PROPS = ["Targets", "Chears", "Tent", "Flags", "benches", "boxes",
           "weapon stand1", "weapon stand2", "weapon stand3", "weapon stand4",
           "shield stand1", "shield stand2", "flags", "Tile Layer 33"]
# La puerta de la cerca de abajo queda abierta: se borran sus celdas.
A_GATE_CELLS = [(28, 12), (29, 12)]

# ── Muros de los costados (Walls_street.png, tiles (col, fila)) ────
BAND = [(11, 8), (12, 8), (13, 8)]    # borde, piedra, borde; se repite
FLAGSTONE = (16, 9)

# Piezas sueltas de PNG/Objects.png de la arena, en tiles (x0, y0, x1, y1).
# "barricade" (un armero vacío) tapa los portones cerrados.
A_PIECES = {"awning": (10, 0, 16, 4), "banner_tall": (0, 0, 1, 4), "banner_small": (0, 6, 0, 7),
            "barricade": (6, 12, 8, 13)}

ROWS = len(M_ROWS)
EDGE = 3

NPC_SHEETS = {
    "trainer.png": "PNG/Characters/Other_fighters/With_shadow/Trainer_with_shadow.png",
    "fighter1.png": "PNG/Characters/Figters_sword/With_shadow/Fighter_sword1_with_shadow.png",
    "fighter3.png": "PNG/Characters/Figters_sword/With_shadow/Fighter_sword3_with_shadow.png",
    "archer1.png": "PNG/Characters/Archers/Archer1_with_shadow.png",
    "archer2.png": "PNG/Characters/Archers/Archer2_with_shadow.png",
    "noble_man.png": "PNG/Characters/Aristocrates/Aristocrat_man.png",
    "noble_woman.png": "PNG/Characters/Aristocrates/Aristocrat_woman.png",
    "noble_old.png": "PNG/Characters/Aristocrates/Aristocrat_old_man.png",
    "servant.png": "PNG/Characters/Aristocrates/With_shadow/Servant_girl_with_shadow.png",
    "sit1.png": "PNG/Characters/Other_fighters/Fighter_sit1.png",
    "sit2.png": "PNG/Characters/Other_fighters/Fighter_sit2.png",
    "mannequin1.png": "Tiled_files/Attacked_Manequin1_with_shadow.png",
    "mannequin3.png": "Tiled_files/Attacked_Manequin3_with_shadow.png",
}


class Tmx:
    """Un mapa de Tiled con capas por chunks (mapa infinito)."""

    def __init__(self, z, path):
        self.z = z
        root = ET.fromstring(z.read(path))
        base = path.rsplit("/", 1)[0] + "/"
        self.tilesets = []
        for ts in root.findall("tileset"):
            img = ts.find("image")
            if img is None or base + img.get("source") not in z.namelist():
                continue
            sheet = Image.open(io.BytesIO(z.read(base + img.get("source")))).convert("RGBA")
            self.tilesets.append((int(ts.get("firstgid")), int(ts.get("columns")), sheet))
        self.tilesets.sort(key=lambda t: t[0])
        self.layers = {}
        self.order = []
        for layer in root.iter("layer"):
            cells = {}
            for ch in layer.find("data").findall("chunk"):
                cx, cy, w = int(ch.get("x")), int(ch.get("y")), int(ch.get("width"))
                vals = [int(v) for v in ch.text.replace("\n", "").split(",") if v.strip()]
                for k, g in enumerate(vals):
                    if g:
                        cells[(cx + k % w, cy + k // w)] = g
            name = layer.get("name")
            if name in self.layers:
                self.layers[name].update(cells)
            else:
                self.layers[name] = cells
                self.order.append(name)

    def tile(self, gid):
        flip_h, flip_v = gid & 0x80000000, gid & 0x40000000
        gid &= 0x1FFFFFFF
        first, cols, sheet = [t for t in self.tilesets if gid >= t[0]][-1]
        i = gid - first
        im = sheet.crop(((i % cols) * TW, (i // cols) * TW, (i % cols + 1) * TW, (i // cols + 1) * TW))
        if flip_h:
            im = im.transpose(Image.FLIP_LEFT_RIGHT)
        if flip_v:
            im = im.transpose(Image.FLIP_TOP_BOTTOM)
        return im

    def cell(self, names, x, y):
        """Las capas `names` de una celda, apiladas en el orden del mapa."""
        out = Image.new("RGBA", (TW, TW), (0, 0, 0, 0))
        for name in self.order:
            if name in names and (x, y) in self.layers[name]:
                out.alpha_composite(self.tile(self.layers[name][(x, y)]))
        return out


def keep_largest(im):
    """Deja sólo el grupo de píxeles más grande (el toldo trae los
    blancos de tiro metidos entre sus postes)."""
    w, h = im.size
    a = im.getchannel("A").load()
    seen = set()
    comps = []
    for y in range(h):
        for x in range(w):
            if a[x, y] and (x, y) not in seen:
                pts, stack = [], [(x, y)]
                seen.add((x, y))
                while stack:
                    cx, cy = stack.pop()
                    pts.append((cx, cy))
                    for dx in (-1, 0, 1):
                        for dy in (-1, 0, 1):
                            n = (cx + dx, cy + dy)
                            if 0 <= n[0] < w and 0 <= n[1] < h and a[n] and n not in seen:
                                seen.add(n)
                                stack.append(n)
                comps.append(pts)
    big = max(comps, key=len)
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    src, dst = im.load(), out.load()
    for p in big:
        dst[p] = src[p]
    return out.crop(out.getbbox())


def sheet_tile(sheet, tx, ty):
    return sheet.crop((tx * TW, ty * TW, (tx + 1) * TW, (ty + 1) * TW))


def build(market_zip, arena_zip):
    mz, az = zipfile.ZipFile(market_zip), zipfile.ZipFile(arena_zip)
    market = Tmx(mz, "Tiled_files/Market_square.tmx")
    arena = Tmx(az, "Tiled_files/Training_ground.tmx")
    for c in A_GATE_CELLS:
        arena.layers["Walls_sand"].pop(c, None)
    # "Walls_sand" trae muros, cercas Y la arena del suelo: lo que se
    # repite adentro de la cerca es suelo, va a su propia capa.
    sand_gids = {g for (x, y), g in arena.layers["Walls_sand"].items() if 20 <= x <= 37 and 3 <= y <= 10}
    arena.layers["sand"] = {c: g for c, g in arena.layers["Walls_sand"].items() if g in sand_gids}
    arena.layers["Walls_sand"] = {c: g for c, g in arena.layers["Walls_sand"].items() if g not in sand_gids}
    arena.order.insert(arena.order.index("Walls_sand"), "sand")
    walls = Image.open(io.BytesIO(mz.read("PNG/Walls_street.png"))).convert("RGBA")

    m0 = EDGE
    a0 = m0 + len(M_COLS)
    width = a0 + len(A_COLS) + EDGE
    base = Image.new("RGBA", (width * TW, ROWS * TW), (0, 0, 0, 255))
    solid_img = Image.new("RGBA", base.size, (0, 0, 0, 0))   # alfa = sólido

    gate_starts = [i for i in range(len(M_COLS) - 2) if M_COLS[i:i + 3] == M_GATE]

    def market_col(vx, vy):
        """Columna de la plaza en (vx, fila vy), con los portones del sur tapados."""
        i = vx - m0
        mc, mr = M_COLS[i], M_ROWS[vy]
        if mr >= 4:
            for g, start in enumerate(gate_starts):
                if g != SOUTH_GATE and start <= i < start + 3:
                    mc = GATE_CLOSED[i - start]
        return mc, mr

    def put(img, vx, vy, solid=False, solid_part=None):
        base.alpha_composite(img, (vx * TW, vy * TW))
        if solid:
            solid_img.alpha_composite(Image.new("RGBA", (TW, TW), (0, 0, 0, 255)), (vx * TW, vy * TW))
        elif solid_part is not None:
            solid_img.alpha_composite(solid_part, (vx * TW, vy * TW))

    floor_m = market.cell(["street"], -9, -2)
    floor_a = arena.cell(["Floor"], 40, 8)
    flag = sheet_tile(walls, *FLAGSTONE)
    for vy in range(ROWS):
        # Plaza
        for vx in range(m0, a0):
            mc, mr = market_col(vx, vy)
            put(market.cell(M_BASE, mc, mr), vx, vy, solid_part=market.cell(M_SOLID, mc, mr))
        # Arena; abajo de su cerca sigue el suelo y el muro de la plaza.
        for i, ac in enumerate(A_COLS):
            vx = a0 + i
            ar = A_ROW0 + vy
            if ar <= 13:
                put(arena.cell(A_FLAT + A_SOLID, ac, ar), vx, vy, solid_part=arena.cell(A_SOLID, ac, ar))
            else:
                mc, mr = M_PLAIN[i % 3], M_ROWS[vy]
                put(market.cell(M_BASE, mc, mr), vx, vy, solid_part=market.cell(M_SOLID, mc, mr))
        # Costados: arriba y abajo siguen el muro; entremedio, el muro
        # visto desde arriba (borde, piedra, borde).
        for side in ("left", "right"):
            for k in range(EDGE):
                vx = k if side == "left" else a0 + len(A_COLS) + k
                if side == "left" and (vy <= 3 or vy >= 17):
                    mr = M_ROWS[vy]
                    put(market.cell(M_BASE, -10, mr), vx, vy, solid=True)
                    continue
                if side == "right" and vy <= 4:
                    put(arena.cell(A_FLAT + A_SOLID, 40, A_ROW0 + vy), vx, vy, solid=True)
                    continue
                if side == "right" and vy >= 17:
                    put(market.cell(M_BASE, 12, M_ROWS[vy]), vx, vy, solid=True)
                    continue
                band = sheet_tile(walls, BAND[k][0], BAND[k][1] + vy % 3)
                under = flag if (side == "left" and k == 0) or (side == "right" and k == 2) else None
                if k == 1:
                    under = flag
                if under is None:
                    under = floor_m if side == "left" else floor_a
                put(under, vx, vy)
                put(band, vx, vy, solid=True)

    # Adornos de la arena: cada grupo de celdas tocándose de una misma
    # capa queda suelto (se ordena por su borde de abajo). La franja de
    # abajo de cada uno (sus "pies") es sólida.
    props = []
    os.makedirs(os.path.join(OUT, "props"), exist_ok=True)
    for name in A_PROPS:
        cells = {c for c in arena.layers.get(name, {}) if A_COLS[0] <= c[0] <= A_COLS[-1] and c[1] - A_ROW0 < ROWS}
        seen = set()
        for c in sorted(cells):
            if c in seen:
                continue
            group, stack = [], [c]
            seen.add(c)
            while stack:
                x, y = stack.pop()
                group.append((x, y))
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        n = (x + dx, y + dy)
                        if n in cells and n not in seen:
                            seen.add(n)
                            stack.append(n)
            xs, ys = [g[0] for g in group], [g[1] for g in group]
            x0, y0 = min(xs), min(ys)
            im = Image.new("RGBA", ((max(xs) - x0 + 1) * TW, (max(ys) - y0 + 1) * TW), (0, 0, 0, 0))
            for (x, y) in group:
                im.alpha_composite(arena.cell([name], x, y), ((x - x0) * TW, (y - y0) * TW))
            bbox = im.getbbox()
            if bbox is None:
                continue
            im = im.crop(bbox)
            pid = "prop%02d" % len(props)
            im.save(os.path.join(OUT, "props", pid + ".png"), optimize=True)
            px = (a0 + x0 - A_COLS[0]) * TW + bbox[0]
            py = (y0 - A_ROW0) * TW + bbox[1]
            props.append({"name": pid, "layer": name, "x": px, "y": py, "w": im.width, "h": im.height})
            feet = max(6, min(14, im.height // 3))
            foot = im.crop((0, im.height - feet, im.width, im.height))
            solid_img.alpha_composite(foot, (px, py + im.height - feet))

    # Choque: una celda de 8 px es sólida si más de un tercio está tapado.
    alpha = solid_img.getchannel("A")
    gw, gh = base.width // CELL, base.height // CELL
    grid = []
    for gy in range(gh):
        row = ""
        for gx in range(gw):
            box = alpha.crop((gx * CELL, gy * CELL, (gx + 1) * CELL, (gy + 1) * CELL))
            covered = sum(1 for v in box.getdata() if v > 0)
            row += "#" if covered > CELL * CELL / 3 else "."
        grid.append(row)

    gates = [{"x": (m0 + start) * TW, "w": 3 * TW, "south": g == SOUTH_GATE} for g, start in enumerate(gate_starts)]
    os.makedirs(OUT, exist_ok=True)
    base.save(os.path.join(OUT, "base.png"), optimize=True)
    out = ["extends RefCounted", "", "## Generado por tools/build_village.py: no editar a mano.", ""]
    out.append("const SIZE := Vector2(%d, %d)" % base.size)
    out.append("const CELL := %d" % CELL)
    out.append("const ARENA := Rect2(%d, 0, %d, %d)" % (a0 * TW, len(A_COLS) * TW, (14 - A_ROW0 + 1) * TW))
    out.append("const ARENA_GATE_X := %d" % ((a0 + 29 - A_COLS[0]) * TW))
    out.append("## Portones del muro norte, de izquierda a derecha; \"south\": también abierto al sur.")
    out.append("const GATES: Array = [")
    for g in gates:
        out.append("	{\"x\": %d, \"w\": %d, \"south\": %s}," % (g["x"], g["w"], "true" if g["south"] else "false"))
    out.append("]")
    out.append("## Adornos sueltos de la arena (esquina sup. izq. en el mapa).")
    out.append("const PROPS: Array = [")
    for q in props:
        out.append("	{\"name\": \"%s\", \"layer\": \"%s\", \"x\": %d, \"y\": %d, \"w\": %d, \"h\": %d}," % (q["name"], q["layer"], q["x"], q["y"], q["w"], q["h"]))
    out.append("]")
    out.append("## Celdas de CELL px: \"#\" sólida.")
    out.append("const GRID: PackedStringArray = [")
    for row in grid:
        out.append("	\"%s\"," % row)
    out.append("]")
    with open(os.path.join(OUT, "village_layout.gd"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out) + "\n")
    os.makedirs(os.path.join(OUT, "pieces"), exist_ok=True)
    objects = Image.open(io.BytesIO(az.read("Tiled_files/Objects.png"))).convert("RGBA")
    for name, r in A_PIECES.items():
        keep_largest(clean_piece(objects, *r)).save(os.path.join(OUT, "pieces", name + ".png"), optimize=True)
    os.makedirs(os.path.join(OUT, "npc"), exist_ok=True)
    for name, src in NPC_SHEETS.items():
        Image.open(io.BytesIO(az.read(src))).convert("RGBA").save(os.path.join(OUT, "npc", name), optimize=True)
    print("pueblo listo en", OUT, base.size, len(props), "adornos")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    build(sys.argv[1], sys.argv[2])
