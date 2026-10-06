"""Puestos y gente del pueblo desde el pack de Craftpix "Market Square".

Uso:
  python tools/build_plaza.py <ruta del zip>
  (craftpix-net-587497-pixel-art-market-square-rpg-shop-and-npc-assets-pack.zip)

Escribe en assets/ui/plaza/:
  pieces/*.png    puestos y adornos recortados de Objects.png, limpios de
                  pedazos de las piezas vecinas.
  npc/*.png       hojas de mercaderes, músicos, ciudadanos y velas, tal cual.
El suelo y los muros del pueblo salen de tools/build_village.py (que usa
clean_piece de acá). Qué aparece y dónde lo decide scenes/village.gd.
Necesita Pillow.
"""
import io
import os
import sys
import zipfile

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "ui", "plaza")
TW = 16
# Recortes de PNG/Objects.png en tiles (x0, y0, x1, y1), ambos incluidos.
PIECES = {
    "magic_table": (26, 29, 29, 31), "tent_empty": (7, 25, 13, 31), "tent_full": (0, 25, 7, 31), "rug": (26, 25, 29, 28),
    "weapon_table": (18, 5, 23, 8), "awning_blue": (10, 2, 15, 8), "weapon_full": (1, 0, 8, 7), "armor_a": (23, 1, 25, 2),
    "fruit_crates": (14, 10, 21, 13), "fruit_frame": (8, 10, 14, 13), "fruit_full": (0, 9, 6, 15), "cart": (0, 32, 6, 35),
    "bakery": (7, 16, 12, 20), "tables": (7, 21, 20, 24), "banner_a": (1, 4, 1, 6), "banner_b": (28, 6, 28, 8),
    "barrels": (23, 16, 25, 19), "crates": (23, 9, 28, 11),
}
NPC_SHEETS = {
    "magic.png": "PNG/Characters/Character_others_animation/Trader_magic_animation_with_shadow.png",
    "weapon.png": "PNG/Characters/Character_others_animation/Trader_weapon_animation_with_shadow.png",
    "fruits.png": "PNG/Characters/Character_others_animation/Trader_fruits_animation.png",
    "bread.png": "PNG/Characters/Character_others_animation/Trader_bread_animation_with_shadow.png",
    "lute.png": "PNG/Characters/Character_others_animation/Lute_player_animation_with_shadow.png",
    "flute.png": "PNG/Characters/Character_others_animation/Flutist_animation_with_shadow.png",
    "eater.png": "PNG/Characters/Character_others_animation/Eater_animation.png",
    "candles.png": "PNG/candles.png",
}


def load(z, name):
    return Image.open(io.BytesIO(z.read(name))).convert("RGBA")


def clean_piece(objects, tx0, ty0, tx1, ty1, keep_frac=0.3):
    """Recorte sin pedazos de las piezas vecinas: se borran los grupos de
    píxeles que tocan el borde y son chicos respecto del más grande."""
    im = objects.crop((tx0 * TW, ty0 * TW, (tx1 + 1) * TW, (ty1 + 1) * TW))
    w, h = im.size
    a = im.getchannel("A").load()
    seen = [[False] * w for _ in range(h)]
    comps = []
    for y in range(h):
        for x in range(w):
            if a[x, y] and not seen[y][x]:
                stack, pts, border = [(x, y)], [], False
                seen[y][x] = True
                while stack:
                    cx, cy = stack.pop()
                    pts.append((cx, cy))
                    border = border or cx in (0, w - 1) or cy in (0, h - 1)
                    for dx in (-1, 0, 1):
                        for dy in (-1, 0, 1):
                            nx, ny = cx + dx, cy + dy
                            if 0 <= nx < w and 0 <= ny < h and a[nx, ny] and not seen[ny][nx]:
                                seen[ny][nx] = True
                                stack.append((nx, ny))
                comps.append((pts, border))
    big = max(len(p) for p, _ in comps)
    px = im.load()
    for pts, border in comps:
        if border and len(pts) < big * keep_frac:
            for x, y in pts:
                px[x, y] = (0, 0, 0, 0)
    return im.crop(im.getbbox())


def main(zip_path):
    z = zipfile.ZipFile(zip_path)
    os.makedirs(os.path.join(OUT, "pieces"), exist_ok=True)
    os.makedirs(os.path.join(OUT, "npc"), exist_ok=True)
    objects = load(z, "PNG/Objects.png")
    for name, r in PIECES.items():
        clean_piece(objects, *r).save(os.path.join(OUT, "pieces", name + ".png"), optimize=True)
    for name, src in NPC_SHEETS.items():
        load(z, src).save(os.path.join(OUT, "npc", name), optimize=True)
    for i in range(1, 6):
        for anim in ("Idle", "Walk"):
            load(z, "PNG/Characters/Character_citizens_animation/Citizen%d_%s_with_shadow.png" % (i, anim)).save(
                os.path.join(OUT, "npc", "citizen%d_%s.png" % (i, anim.lower())), optimize=True)
    print("plaza lista en", OUT)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    main(sys.argv[1])
