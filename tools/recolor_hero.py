"""Genera héroes nuevos recoloreando a GAROTH (pelo y ojos).

Uso:
  python tools/recolor_hero.py            -> regenera TOREN, BRAN y VAEL
  python tools/recolor_hero.py --all      -> también las animaciones que el
                                             juego no usa (Walk, Walk_Attack,
                                             Run_Attack)

Lee assets/sprites/swordman/Swordsman_lvlN/ (las 9 formas) y escribe
assets/sprites/<id>/<Nombre>_lvlN/<Anim>/<Nombre>_lvlN_<Anim>_<dir>.png,
con un solo formato de nombre (el de GAROTH cambia entre formas 1-3 y
4-6, y "attack" va en minúscula). Además deja el retrato y la tira del
quieto para la selección de personaje en assets/main_characters/.

El reemplazo es por color exacto: los 5 tonos del pelo y los 2 azules de
los ojos de GAROTH aparecen sólo en la cabeza (medido en todas las hojas),
así que la ropa y la armadura no cambian. El brillo del ojo (d2dde8) se
deja igual. Necesita Pillow (pip install pillow).
"""
import os
import sys

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SRC = os.path.join(ROOT, "assets", "sprites", "swordman")
FRAME = 64
DIRS = ["front", "back", "side_left", "side_right"]
USED_ANIMS = ["Idle", "Run", "Attack", "Hurt", "Death"]
EXTRA_ANIMS = ["Walk", "Walk_Attack", "Run_Attack"]

# GAROTH: pelo de claro a oscuro, y los dos azules del ojo.
HAIR = ["876c7d", "684f5a", "4d3945", "3b2c33", "2b2023"]
EYES = ["3f6ad4", "374a8f"]

VARIANTS = {
    "toren": {"name": "Toren",   # rubio, ojos verdes
              "hair": ["f7e08f", "e2bb55", "b98a33", "82591f", "553816"], "eyes": ["52c46a", "2c7a45"]},
    "bran": {"name": "Bran",     # colorín, ojos miel
             "hair": ["f39a5a", "d8672f", "aa4722", "7a2f18", "4d1c10"], "eyes": ["dca448", "9a6a24"]},
    "vael": {"name": "Vael",     # pelo blanco, ojos violeta
             "hair": ["f5f2f8", "d8d2e2", "aea6bf", "7d7591", "504862"], "eyes": ["b27af0", "7040b0"]},
}


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def garoth_path(tier, anim, direction):
    folder = anim if tier >= 4 else "Swordsman_lvl%d_%s" % (tier, anim)
    fname = "Swordsman_lvl%d_%s_%s.png" % (tier, "attack" if anim == "Attack" else anim, direction)
    return os.path.join(SRC, "Swordsman_lvl%d" % tier, folder, fname)


def recolor(im, mapping):
    im = im.convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            c = px[x, y]
            if c[3] and c[:3] in mapping:
                px[x, y] = mapping[c[:3]] + (c[3],)
    return im


def main():
    anims = USED_ANIMS + (EXTRA_ANIMS if "--all" in sys.argv else [])
    for vid, v in VARIANTS.items():
        mapping = {rgb(a): rgb(b) for a, b in zip(HAIR + EYES, v["hair"] + v["eyes"])}
        n = 0
        for tier in range(1, 10):
            for anim in anims:
                for d in DIRS:
                    src = garoth_path(tier, anim, d)
                    if not os.path.exists(src):
                        continue
                    out_dir = os.path.join(ROOT, "assets", "sprites", vid, "%s_lvl%d" % (v["name"], tier), anim)
                    os.makedirs(out_dir, exist_ok=True)
                    out = os.path.join(out_dir, "%s_lvl%d_%s_%s.png" % (v["name"], tier, anim, d))
                    recolor(Image.open(src), mapping).save(out, optimize=True)
                    n += 1
        # Selección de personaje: tira del quieto (forma 3) y retrato ampliado.
        idle = recolor(Image.open(garoth_path(3, "Idle", "front")), mapping)
        mc = os.path.join(ROOT, "assets", "main_characters")
        idle.save(os.path.join(mc, "%s_idle_strip.png" % vid), optimize=True)
        first = idle.crop((0, 0, FRAME, FRAME))
        bb = first.getbbox()
        first = first.crop((max(0, bb[0] - 3), max(0, bb[1] - 3), min(FRAME, bb[2] + 3), min(FRAME, bb[3] + 3)))
        first.resize((first.width * 10, first.height * 10), Image.NEAREST).save(os.path.join(mc, "%s_portrait.png" % vid), optimize=True)
        print("%s: %d hojas" % (vid, n))


if __name__ == "__main__":
    main()
