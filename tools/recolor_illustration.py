"""Ilustración de TOREN, BRAN y VAEL: la de GAROTH recoloreada.

La ilustración no tiene una paleta cerrada como los sprites (ver
recolor_hero.py), así que se trabaja por tono y zona:
  - pelo: castaños/malvas oscuros en la cabeza (sobre la bufanda), que se
    pasan a la rampa del héroe manteniendo luces y sombras;
  - ojos: los azules del recuadro de los ojos;
  - bufanda y capa: los rojos de esa zona (no el cuero de cinturón y botas),
    en el color de detalle de cada héroe.

Uso:  python tools/recolor_illustration.py
Escribe assets/main_characters/<id>_char.png (1024x1536, como la de GAROTH).
Requiere numpy y Pillow.
"""
import pathlib
import numpy as np
from PIL import Image, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "assets/main_characters/swordman_char.png"
OUT = ROOT / "assets/main_characters"

# pelo: (tono, saturación en sombra, saturación en luz, valor mín, valor máx)
VARIANTS = {
    "toren": {"hair": (45, 0.78, 0.48, 0.32, 1.00), "eyes": 118, "scarf": 105},
    "bran":  {"hair": (16, 0.80, 0.55, 0.26, 0.97), "eyes": 36,  "scarf": 30},
    "vael":  {"hair": (255, 0.14, 0.03, 0.40, 1.00), "eyes": 278, "scarf": 280},
}
EYES_SAT = {"bran": 1.15}     # ojos miel: un poco más saturados
SCARF_VALUE = {"bran": 1.3}   # naranjo más claro, para no confundirse con el cuero


def to_hsv(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx, mn = rgb.max(-1), rgb.min(-1)
    d = mx - mn
    safe = np.where(d > 1e-6, d, 1.0)
    h = np.where(mx == r, ((g - b) / safe) % 6,
                 np.where(mx == g, (b - r) / safe + 2, (r - g) / safe + 4)) * 60
    h = np.where(d > 1e-6, h, 0.0)
    s = np.where(mx > 0, d / np.where(mx > 0, mx, 1.0), 0.0)
    return h, s, mx


def to_rgb(h, s, v):
    hh = (h % 360) / 60.0
    c = v * s
    x = c * (1 - np.abs(hh % 2 - 1))
    m = v - c
    z = np.zeros_like(hh)
    conds = [hh < 1, hh < 2, hh < 3, hh < 4, hh < 5, hh >= 5]
    r = np.select(conds, [c, x, z, z, x, c])
    g = np.select(conds, [x, c, c, x, z, z])
    b = np.select(conds, [z, z, x, c, c, x])
    return np.stack([r + m, g + m, b + m], -1)


def masks(h, s, v, a):
    H, W = a.shape
    yy, xx = np.mgrid[0:H, 0:W]
    op = a > 0.3
    red = op & ((h > 335) | (h < 14)) & (s > 0.45)
    brown = op & ((h > 300) | (h < 40)) & (v < 0.66) & ~(red & (s > 0.62))
    head = (yy < 470) & (xx > 380) & (xx < 910)
    m = Image.fromarray(((brown & head) * 255).astype(np.uint8))
    m = m.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.MinFilter(5))
    hair = (np.array(m) > 127) & op & ~red & head
    eyes = op & (h > 185) & (h < 240) & (s > 0.3) & (yy > 360) & (yy < 470) & (xx > 540) & (xx < 750)
    zone = ((yy < 760) | ((xx < 330) & (yy < 990))) & ~((xx > 330) & (xx < 500) & (yy > 700))
    scarf = op & ((h > 335) | (h < 10)) & (s > 0.4) & zone & ~hair
    folds = op & ((h > 315) | (h < 12)) & (s > 0.22) & (v < 0.5) & zone & (yy > 470) & (xx < 560) & ~hair
    inner = op & (h > 300) & (s > 0.4) & (v < 0.5) & (yy > 470) & (yy < 640) & (xx > 560) & (xx < 800) & ~hair
    return hair, eyes, scarf | folds | inner


def main():
    im = np.array(Image.open(SRC).convert("RGBA")).astype(np.float32) / 255
    h, s, v = to_hsv(im[..., :3])
    hair, eyes, scarf = masks(h, s, v, im[..., 3])
    lo, hi = np.percentile(v[hair], 2), np.percentile(v[hair], 99)
    t = np.clip((v - lo) / (hi - lo), 0, 1)
    for name, p in VARIANTS.items():
        out = im.copy()
        th, s_dark, s_light, v0, v1 = p["hair"]
        rgb = to_rgb(np.full_like(v, th), s_dark + (s_light - s_dark) * t, v0 + (v1 - v0) * t)
        out[..., :3] = np.where(hair[..., None], rgb, out[..., :3])
        rgb = to_rgb(np.full_like(v, p["eyes"]), np.clip(s * EYES_SAT.get(name, 1.0), 0, 1), v)
        out[..., :3] = np.where(eyes[..., None], rgb, out[..., :3])
        rgb = to_rgb(np.full_like(v, p["scarf"]), s, np.clip(v * SCARF_VALUE.get(name, 1.0), 0, 1))
        out[..., :3] = np.where(scarf[..., None], rgb, out[..., :3])
        path = OUT / ("%s_char.png" % name)
        Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8)).save(path, optimize=True)
        print("escrito", path.relative_to(ROOT))


if __name__ == "__main__":
    main()
