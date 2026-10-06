"""Importa la maga (ELARA) y el arquero (DOREN) desde los packs de Craftpix.

Uso:
  python tools/import_class_pack.py <carpeta con los zip>

Packs (craftpix.net):
  craftpix-net-137340-mage-1-3-level-pixel-top-down-sprite-character.zip
  craftpix-net-248938-mage-4-6-level-pixel-top-down-sprite-characters.zip
  craftpix-net-922316-archer-1-3-level-pixel-top-down-sprite-character.zip

Cada hoja del pack trae las 4 direcciones en filas (frente, izquierda,
derecha, espalda). Se corta en un archivo por dirección con el mismo
formato que TOREN/BRAN/VAEL:
  assets/sprites/<id>/<Nombre>_lvlN/<Anim>/<Nombre>_lvlN_<Anim>_<dir>.png
y cada fila se recorta a sus cuadros con dibujo: el quieto de espalda trae
4 cuadros y 8 vacíos (si se animaran los 12, el héroe desaparecería).
Se usan las hojas con sombra, que vienen completas (revisado: ningún
cuadro vacío fuera del quieto de espalda).

Efectos:
  elara/fx/fire_cycle_1.png, fire_cycle_4.png      bola de fuego (4 cuadros de 32, una fila por dirección)
  elara/fx/fire_explosion_1.png (32 px), fire_explosion_4.png (48 px)
  doren/fx/arrow.png                                 flecha hacia la derecha (el juego la gira)
"""
import io
import os
import sys
import zipfile

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "sprites")
FRAME = 64
ROW_DIRS = ["front", "side_left", "side_right", "back"]
ANIMS = ["Idle", "Run", "Attack", "Hurt", "Death"]

MAGE_ZIPS = {
    "craftpix-net-137340-mage-1-3-level-pixel-top-down-sprite-character.zip": [1, 2, 3],
    "craftpix-net-248938-mage-4-6-level-pixel-top-down-sprite-characters.zip": [4, 5, 6],
}
ARCHER_ZIP = "craftpix-net-922316-archer-1-3-level-pixel-top-down-sprite-character.zip"


def find(z, suffix):
    """Nombre del archivo del zip que termina en suffix (sin mirar mayúsculas)."""
    s = suffix.lower()
    hits = [n for n in z.namelist() if n.lower().endswith(s) and not n.startswith("__MACOSX")]
    if len(hits) != 1:
        raise SystemExit("no encuentro %s (%d coincidencias)" % (suffix, len(hits)))
    return hits[0]


def load(z, name):
    return Image.open(io.BytesIO(z.read(name))).convert("RGBA")


def split_rows(sheet, out_dir, prefix):
    """Una tira por fila, sólo con los cuadros dibujados (al principio de la fila)."""
    os.makedirs(out_dir, exist_ok=True)
    cols = sheet.width // FRAME
    for r, d in enumerate(ROW_DIRS):
        frames = [sheet.crop((c * FRAME, r * FRAME, (c + 1) * FRAME, (r + 1) * FRAME)) for c in range(cols)]
        n = 0
        while n < cols and frames[n].getbbox():
            n += 1
        assert n > 0 and all(not f.getbbox() for f in frames[n:]), (prefix, d, "cuadros vacíos en medio")
        strip = Image.new("RGBA", (n * FRAME, FRAME), (0, 0, 0, 0))
        for i in range(n):
            strip.paste(frames[i], (i * FRAME, 0))
        strip.save(os.path.join(out_dir, "%s_%s.png" % (prefix, d)), optimize=True)


def import_mage(src_dir):
    for zname, levels in MAGE_ZIPS.items():
        z = zipfile.ZipFile(os.path.join(src_dir, zname))
        for lvl in levels:
            for anim in ANIMS:
                fname = "Mage_lvl%d_%s.png" % (lvl, "attack" if anim == "Attack" else anim)
                sheet = load(z, find(z, "With_shadow/" + fname))
                split_rows(sheet, os.path.join(OUT, "elara", "Elara_lvl%d" % lvl, anim), "Elara_lvl%d_%s" % (lvl, anim))
        fx = os.path.join(OUT, "elara", "fx")
        os.makedirs(fx, exist_ok=True)
        tag = levels[0]
        load(z, find(z, "PNG/Fire/Fire_cycle.png")).save(os.path.join(fx, "fire_cycle_%d.png" % tag), optimize=True)
        load(z, find(z, "PNG/Fire/Fire_explosion.png")).save(os.path.join(fx, "fire_explosion_%d.png" % tag), optimize=True)
        print("maga", levels, "ok")


def import_archer(src_dir):
    z = zipfile.ZipFile(os.path.join(src_dir, ARCHER_ZIP))
    for lvl in [1, 2, 3]:
        for anim in ANIMS:
            # Las hojas con sombra están en la raíz de cada carpeta de nivel.
            name = [n for n in z.namelist() if not n.startswith("__MACOSX")
                    and n.lower() == ("png/archer_lvl%d/archer_lvl%d_%s.png" % (lvl, lvl, anim)).lower()]
            assert len(name) == 1, (lvl, anim, name)
            split_rows(load(z, name[0]), os.path.join(OUT, "doren", "Doren_lvl%d" % lvl, anim), "Doren_lvl%d_%s" % (lvl, anim))
    # Flecha: la hoja trae 4 (abajo, izquierda, derecha, arriba) sueltas en
    # 112x32; se guarda la que apunta a la derecha, recortada.
    sheet = load(z, find(z, "PNG/Archer_Lvl1/Arrow.png"))
    cols = [x for x in range(sheet.width) if any(sheet.getpixel((x, y))[3] for y in range(sheet.height))]
    groups, start = [], cols[0]
    for a, b in zip(cols, cols[1:] + [None]):
        if b is None or b != a + 1:
            groups.append((start, a + 1))
            if b is not None:
                start = b
    assert len(groups) == 4, groups
    x0, x1 = groups[2]
    piece = sheet.crop((x0, 0, x1, sheet.height))
    piece = piece.crop(piece.getbbox())
    fx = os.path.join(OUT, "doren", "fx")
    os.makedirs(fx, exist_ok=True)
    piece.save(os.path.join(fx, "arrow.png"), optimize=True)
    print("arquero ok, flecha", piece.size)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    import_mage(sys.argv[1])
    import_archer(sys.argv[1])
