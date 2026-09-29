"""Importa formas nuevas de GAROTH desde un pack de Craftpix (zip).

Uso:
  python tools/import_swordsman_pack.py <pack.zip>

Pensado para "swordsman 7-9 level" (craftpix-net-299679): toma los
.aseprite de ASEPRITE/Swordsman_lvlN/<Anim>/ (uno por animación y
dirección, igual que las formas 4 a 6), los copia a
assets/sprites/swordman/Swordsman_lvlN/<Anim>/ y exporta cada uno a PNG
(tira horizontal) con tools/ase2png.py.

Por qué no usa los PNG del pack: las hojas "attack" y "Run_Attack" de
PNG/With_shadow vienen vacías. Y para que las formas nuevas queden
iguales a las 1-6, a los píxeles semitransparentes (sombra, brillo del
tajo) se les aplica lo mismo que traen los PNG de Craftpix: color
premultiplicado y opacidad al cuadrado (la sombra queda al 12 %, el
estándar). Se omiten las variantes *_normal (sin efecto en el tajo).
"""
import os
import sys
import zipfile

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ase2png  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
DEST = os.path.join(ROOT, "assets", "sprites", "swordman")


def craftpix_alpha(im):
    im = im.convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if 0 < a < 255:
                px[x, y] = (r * a // 255, g * a // 255, b * a // 255, a * a // 255)
    return im


def main(zip_path):
    zf = zipfile.ZipFile(zip_path)
    count = 0
    for name in zf.namelist():
        if "__MACOSX" in name or not name.startswith("ASEPRITE/") or not name.endswith(".aseprite"):
            continue
        parts = name.split("/")   # ASEPRITE / Swordsman_lvlN / <Anim> / archivo
        if len(parts) != 4 or parts[2].endswith("_normal"):
            continue
        out_dir = os.path.join(DEST, parts[1], parts[2])
        os.makedirs(out_dir, exist_ok=True)
        ase_path = os.path.join(out_dir, parts[3])
        with open(ase_path, "wb") as f:
            f.write(zf.read(name))
        imgs = ase2png.frames_of(ase_path)
        png = craftpix_alpha(ase2png.strip(imgs))
        png.save(ase_path[:-len(".aseprite")] + ".png", optimize=True)
        count += 1
    print("%d hojas importadas en %s" % (count, DEST))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    main(sys.argv[1])
