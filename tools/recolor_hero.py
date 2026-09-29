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
deja igual.

Desde la forma 3 además se tiñen los detalles de color (bufanda, capa,
penacho, camisa) con el tono de cada héroe ("accent", en grados): con el
casco puesto (formas 5 a 9) es lo que los distingue de GAROTH. No se
tocan el acero azul, el dorado, la piel, el pelo, los ojos ni los
contornos. En el golpe y la muerte se saltan los cuadros del destello
rojo del pack (los que tienen 15 puntos más de rojo que el primer cuadro
de la hoja), para que el aviso de daño siga siendo rojo. Necesita Pillow
(pip install pillow).
"""
import colorsys
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
    "toren": {"name": "Toren",   # rubio, ojos verdes, detalles verdes
              "hair": ["f7e08f", "e2bb55", "b98a33", "82591f", "553816"], "eyes": ["52c46a", "2c7a45"], "accent": 120},
    "bran": {"name": "Bran",     # colorín, ojos miel, detalles naranjos
             "hair": ["f39a5a", "d8672f", "aa4722", "7a2f18", "4d1c10"], "eyes": ["dca448", "9a6a24"], "accent": 22},
    "vael": {"name": "Vael",     # pelo blanco, ojos violeta, detalles violeta
             "hair": ["f5f2f8", "d8d2e2", "aea6bf", "7d7591", "504862"], "eyes": ["b27af0", "7040b0"], "accent": 275},
}
ACCENT_FROM_TIER = 3
FLASH_ANIMS = ("Hurt", "Death")   # traen cuadros con destello rojo
FLASH_MARGIN = 15                  # puntos de % de rojo sobre el primer cuadro
# Piel, contornos y brillo del ojo de GAROTH: nunca se tiñen.
KEEP = ["f6ca74", "e1b26e", "be865f", "a46f59", "552d24", "795048", "110b00", "211a1c", "d2dde8"]


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def garoth_path(tier, anim, direction):
    folder = anim if tier >= 4 else "Swordsman_lvl%d_%s" % (tier, anim)
    fname = "Swordsman_lvl%d_%s_%s.png" % (tier, "attack" if anim == "Attack" else anim, direction)
    return os.path.join(SRC, "Swordsman_lvl%d" % tier, folder, fname)


def is_accent(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    deg = h * 360
    if s < 0.42 or v < 0.28:
        return False            # acero, grises, cueros oscuros
    if 185 <= deg <= 255 or 36 <= deg <= 62:
        return False            # acero azul y dorado
    return True


def red_share(frame):
    px = [p for p in frame.getdata() if p[3] > 200]
    if not px:
        return 0
    red = 0
    for p in px:
        h = colorsys.rgb_to_hsv(p[0] / 255, p[1] / 255, p[2] / 255)[0] * 360
        if h < 15 or h > 340:
            red += 1
    return red * 100 // len(px)


def recolor_sheet(im, mapping, accent, keep, skip_flash):
    """Recolorea una tira cuadro por cuadro; con skip_flash no tiñe los
    cuadros de destello rojo."""
    im = im.convert("RGBA")
    if accent is None or not skip_flash:
        return recolor(im, mapping, accent, keep)
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    frames = [im.crop((i * FRAME, 0, (i + 1) * FRAME, FRAME)) for i in range(im.width // FRAME)]
    base = red_share(frames[0])
    for i, fr in enumerate(frames):
        flash = red_share(fr) > base + FLASH_MARGIN
        out.paste(recolor(fr, mapping, None if flash else accent, keep), (i * FRAME, 0))
    return out


def recolor(im, mapping, accent=None, keep=()):
    im = im.convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            c = px[x, y]
            if not c[3]:
                continue
            if c[:3] in mapping:
                px[x, y] = mapping[c[:3]] + (c[3],)
            elif accent is not None and c[3] >= 200 and c[:3] not in keep and is_accent(*c[:3]):
                h, s, v = colorsys.rgb_to_hsv(c[0] / 255, c[1] / 255, c[2] / 255)
                nr, ng, nb = colorsys.hsv_to_rgb(accent / 360.0, s, v)
                px[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), c[3])
    return im


def main():
    anims = USED_ANIMS + (EXTRA_ANIMS if "--all" in sys.argv else [])
    for vid, v in VARIANTS.items():
        mapping = {rgb(a): rgb(b) for a, b in zip(HAIR + EYES, v["hair"] + v["eyes"])}
        keep = {rgb(c) for c in KEEP}
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
                    accent = v["accent"] if tier >= ACCENT_FROM_TIER else None
                    recolor_sheet(Image.open(src), mapping, accent, keep, anim in FLASH_ANIMS).save(out, optimize=True)
                    n += 1
        # Selección de personaje: tira del quieto (forma 3) y retrato ampliado.
        idle = recolor(Image.open(garoth_path(3, "Idle", "front")), mapping, v["accent"], keep)
        mc = os.path.join(ROOT, "assets", "main_characters")
        idle.save(os.path.join(mc, "%s_idle_strip.png" % vid), optimize=True)
        first = idle.crop((0, 0, FRAME, FRAME))
        bb = first.getbbox()
        first = first.crop((max(0, bb[0] - 3), max(0, bb[1] - 3), min(FRAME, bb[2] + 3), min(FRAME, bb[3] + 3)))
        first.resize((first.width * 10, first.height * 10), Image.NEAREST).save(os.path.join(mc, "%s_portrait.png" % vid), optimize=True)
        print("%s: %d hojas" % (vid, n))


if __name__ == "__main__":
    main()
