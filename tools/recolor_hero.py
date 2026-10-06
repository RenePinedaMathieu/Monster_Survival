"""Colores de los héroes: GAROTH, ELARA y DOREN recoloreados (pelo y ojos).

Uso:
  python tools/recolor_hero.py              -> regenera todos los colores
  python tools/recolor_hero.py elara        -> sólo los de un héroe
  python tools/recolor_hero.py --all        -> también las animaciones que
                                               el juego no usa (sólo GAROTH:
                                               Walk, Walk_Attack, Run_Attack)

Cada héroe tiene 4 colores (el original y 3 recoloreados) que sólo
cambian cómo se ve. Los recoloreados se escriben en
assets/sprites/<id>/<Nombre>_lvlN/<Anim>/<Nombre>_lvlN_<Anim>_<dir>.png
(los de GAROTH son las carpetas toren/bran/vael de cuando eran héroes
aparte). Además deja la tira del quieto y el retrato ampliado de cada
color para la selección de personaje en assets/main_characters/.

El reemplazo es por color exacto: los tonos del pelo y de los ojos de
cada héroe aparecen sólo en la cabeza (revisado marcándolos en todas las
formas), y se mapean de claro a oscuro sobre la gama del color nuevo.
Desde "accent_from" también se tiñen los detalles de la ropa con el
tono de cada color ("accent", en grados): con casco, capucha o sombrero
es lo que los distingue. Qué se tiñe depende del héroe: en GAROTH todo lo
saturado salvo el acero azul y el dorado; en ELARA sólo verdes, azules y
violetas (el fuego de su ataque sigue naranjo); en DOREN sólo rojos y
verdes de la ropa (su piel no se toca). En el golpe y la muerte se saltan
los cuadros del destello rojo del pack. Necesita Pillow.
"""
import colorsys
import os
import sys

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SPRITES = os.path.join(ROOT, "assets", "sprites")
FRAME = 64
DIRS = ["front", "back", "side_left", "side_right"]
USED_ANIMS = ["Idle", "Run", "Attack", "Hurt", "Death"]
EXTRA_ANIMS = ["Walk", "Walk_Attack", "Run_Attack"]
FLASH_ANIMS = ("Hurt", "Death")   # traen cuadros con destello rojo
FLASH_MARGIN = 15                  # puntos de % de rojo sobre el primer cuadro

# Gamas de pelo de claro a oscuro (5 tonos; se interpolan si el héroe
# tiene más o menos).
RUBIO = ["f7e08f", "e2bb55", "b98a33", "82591f", "553816"]
COLORIN = ["f39a5a", "d8672f", "aa4722", "7a2f18", "4d1c10"]
PLATA = ["f5f2f8", "d8d2e2", "aea6bf", "7d7591", "504862"]
MORENO = ["5d6278", "3f4256", "2b2c3c", "1d1d29", "121219"]
OJOS_VERDES = ["52c46a", "2c7a45"]
OJOS_MIEL = ["dca448", "9a6a24"]
OJOS_VIOLETA = ["b27af0", "7040b0"]
OJOS_AZULES = ["5fa3f0", "2f5fb0"]


def garoth_path(tier, anim, direction):
    folder = anim if tier >= 4 else "Swordsman_lvl%d_%s" % (tier, anim)
    fname = "Swordsman_lvl%d_%s_%s.png" % (tier, "attack" if anim == "Attack" else anim, direction)
    return os.path.join(SPRITES, "swordman", "Swordsman_lvl%d" % tier, folder, fname)


def class_path(folder, name):
    def path(tier, anim, direction):
        return os.path.join(SPRITES, folder, "%s_lvl%d" % (name, tier), anim, "%s_lvl%d_%s_%s.png" % (name, tier, anim, direction))
    return path


def garoth_accent(h, s, v):
    if s < 0.42 or v < 0.28:
        return False            # acero, grises, cueros oscuros
    return not (185 <= h <= 255 or 36 <= h <= 62)   # acero azul y dorado


def hue_ranges(ranges, min_s=0.35, min_v=0.25):
    def rule(h, s, v):
        return s >= min_s and v >= min_v and any(a <= h <= b for a, b in ranges)
    return rule


HEROES = {
    "swordman": {
        "src": garoth_path, "tiers": 9, "strip_tier": 3,
        "hair": ["876c7d", "684f5a", "4d3945", "3b2c33", "2b2023"],
        "eyes": ["3f6ad4", "374a8f"],
        # Piel, contornos y brillo del ojo: nunca se tiñen.
        "keep": ["f6ca74", "e1b26e", "be865f", "a46f59", "552d24", "795048", "110b00", "211a1c", "d2dde8"],
        "accent_from": 3, "accent_rule": garoth_accent,
        "colors": {
            "toren": {"name": "Toren", "hair": RUBIO, "eyes": OJOS_VERDES, "accent": 120},
            "bran": {"name": "Bran", "hair": COLORIN, "eyes": OJOS_MIEL, "accent": 22},
            "vael": {"name": "Vael", "hair": PLATA, "eyes": OJOS_VIOLETA, "accent": 275},
        },
    },
    "elara": {
        "src": class_path("elara", "Elara"), "tiers": 6, "strip_tier": 3,
        "hair": ["cf681d", "bb5322", "ad4626", "9a3524", "882d20", "71201f", "4d1b1a"],
        "eyes": ["25aa53", "227d56"],
        "keep": ["d2dde8"],
        "accent_from": 3, "accent_rule": hue_ranges([(85, 170), (195, 345)]),
        "colors": {
            "elara_2": {"name": "Elara", "hair": RUBIO, "eyes": OJOS_AZULES, "accent": 215},
            "elara_3": {"name": "Elara", "hair": MORENO, "eyes": OJOS_MIEL, "accent": 350},
            "elara_4": {"name": "Elara", "hair": PLATA, "eyes": OJOS_VIOLETA, "accent": 275},
        },
    },
    "doren": {
        "src": class_path("doren", "Doren"), "tiers": 3, "strip_tier": 2,
        "hair": ["3b5271", "354361", "2c344e", "26283e", "191b28"],
        "eyes": [],
        "keep": ["d2dde8"],
        "accent_from": 2, "accent_rule": hue_ranges([(330, 360), (0, 8), (85, 170)], min_s=0.45),
        "colors": {
            "doren_2": {"name": "Doren", "hair": RUBIO, "eyes": [], "accent": 120},
            "doren_3": {"name": "Doren", "hair": COLORIN, "eyes": [], "accent": 22},
            "doren_4": {"name": "Doren", "hair": PLATA, "eyes": [], "accent": 275},
        },
    },
}


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def ramp(target, n):
    """n tonos de claro a oscuro sacados de la gama target (interpolada)."""
    cols = [rgb(c) for c in target]
    if n == len(cols):
        return cols
    out = []
    for i in range(n):
        t = i * (len(cols) - 1) / max(1, n - 1)
        a = int(t)
        b = min(a + 1, len(cols) - 1)
        f = t - a
        out.append(tuple(int(round(cols[a][k] + (cols[b][k] - cols[a][k]) * f)) for k in range(3)))
    return out


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


def recolor(im, mapping, accent=None, keep=(), rule=None):
    im = im.convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            c = px[x, y]
            if not c[3]:
                continue
            if c[:3] in mapping:
                px[x, y] = mapping[c[:3]] + (c[3],)
            elif accent is not None and c[3] >= 200 and c[:3] not in keep:
                h, s, v = colorsys.rgb_to_hsv(c[0] / 255, c[1] / 255, c[2] / 255)
                if rule(h * 360, s, v):
                    nr, ng, nb = colorsys.hsv_to_rgb(accent / 360.0, s, v)
                    px[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), c[3])
    return im


def recolor_sheet(im, mapping, accent, keep, rule, skip_flash):
    """Recolorea una tira cuadro por cuadro; con skip_flash no tiñe los
    cuadros de destello rojo."""
    im = im.convert("RGBA")
    if accent is None or not skip_flash:
        return recolor(im, mapping, accent, keep, rule)
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    frames = [im.crop((i * FRAME, 0, (i + 1) * FRAME, FRAME)) for i in range(im.width // FRAME)]
    base = red_share(frames[0])
    for i, fr in enumerate(frames):
        flash = red_share(fr) > base + FLASH_MARGIN
        out.paste(recolor(fr, mapping, None if flash else accent, keep, rule), (i * FRAME, 0))
    return out


def save_select_art(color_id, idle):
    """Tira del quieto y retrato ampliado para la selección de personaje."""
    mc = os.path.join(ROOT, "assets", "main_characters")
    idle.save(os.path.join(mc, "%s_idle_strip.png" % color_id), optimize=True)
    first = idle.crop((0, 0, FRAME, FRAME))
    bb = first.getbbox()
    first = first.crop((max(0, bb[0] - 3), max(0, bb[1] - 3), min(FRAME, bb[2] + 3), min(FRAME, bb[3] + 3)))
    first.resize((first.width * 10, first.height * 10), Image.NEAREST).save(os.path.join(mc, "%s_portrait.png" % color_id), optimize=True)


def build(hero_id, extra):
    hero = HEROES[hero_id]
    src = hero["src"]
    keep = {rgb(c) for c in hero["keep"]}
    hair = [rgb(c) for c in hero["hair"]]
    eyes = [rgb(c) for c in hero["eyes"]]
    anims = USED_ANIMS + (EXTRA_ANIMS if extra and hero_id == "swordman" else [])
    # El color original de ELARA y DOREN también necesita su arte de la
    # selección (el de GAROTH es su ilustración).
    if hero_id != "swordman":
        save_select_art(hero_id, Image.open(src(hero["strip_tier"], "Idle", "front")).convert("RGBA"))
    for cid, col in hero["colors"].items():
        mapping = dict(zip(hair, ramp(col["hair"], len(hair))))
        if eyes and col["eyes"]:
            mapping.update(zip(eyes, ramp(col["eyes"], len(eyes))))
        n = 0
        for tier in range(1, hero["tiers"] + 1):
            for anim in anims:
                for d in DIRS:
                    path = src(tier, anim, d)
                    if not os.path.exists(path):
                        continue
                    out_dir = os.path.join(SPRITES, cid, "%s_lvl%d" % (col["name"], tier), anim)
                    os.makedirs(out_dir, exist_ok=True)
                    out = os.path.join(out_dir, "%s_lvl%d_%s_%s.png" % (col["name"], tier, anim, d))
                    accent = col["accent"] if tier >= hero["accent_from"] else None
                    recolor_sheet(Image.open(path), mapping, accent, keep, hero["accent_rule"], anim in FLASH_ANIMS).save(out, optimize=True)
                    n += 1
        idle = recolor(Image.open(src(hero["strip_tier"], "Idle", "front")), mapping, col["accent"], keep, hero["accent_rule"])
        save_select_art(cid, idle)
        print("%s: %d hojas" % (cid, n))


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    for hero_id in (args or list(HEROES)):
        build(hero_id, "--all" in sys.argv)


if __name__ == "__main__":
    main()
