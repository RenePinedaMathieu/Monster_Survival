"""Importa efectos del pack "Magic Buff Effects" de Craftpix.

Uso:
  python tools/import_buff_fx.py <carpeta con el zip>

Pack (craftpix.net):
  craftpix-net-207889-magic-buff-effects-pack-for-top-down-games.zip

Cada efecto viene en cuadros sueltos de 640x800 (un aro en el piso y
partículas que suben). Se recortan todos al mismo rectángulo (el que
cubre el dibujo de todos los cuadros, centrado en x), se achican para
que el aro mida RING_WIDTH (el héroe mide ~26 de ancho) y se pegan en
una tira horizontal:
  assets/sprites/fx/buffs/life_recovery.png   12 cuadros (agarrar vida)
  assets/sprites/fx/buffs/immunity.png        16 cuadros (inmunidad)
Imprime el tamaño del cuadro y a qué altura del cuadro queda el centro
del aro: buff_fx.gd lo usa para apoyarlo en los pies del héroe.
"""
import io
import os
import sys
import zipfile

from PIL import Image

ZIP = "craftpix-net-207889-magic-buff-effects-pack-for-top-down-games.zip"
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "fx", "buffs")
RING_WIDTH = 56
EFFECTS = {"Life Recovery": "life_recovery", "Immunity": "immunity"}


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/Downloads")
    z = zipfile.ZipFile(os.path.join(src, ZIP))
    os.makedirs(OUT, exist_ok=True)
    for folder, name in EFFECTS.items():
        names = sorted(n for n in z.namelist()
                       if n.startswith(f"{folder}/PNG/") and n.endswith(".png"))
        frames = [Image.open(io.BytesIO(z.read(n))).convert("RGBA") for n in names]
        w, h = frames[0].size
        x0, y0, x1, y1 = w, h, 0, 0
        for f in frames:
            b = f.getchannel("A").getbbox()
            x0, y0, x1, y1 = min(x0, b[0]), min(y0, b[1]), max(x1, b[2]), max(y1, b[3])
        # Simétrico en x: el aro queda en el centro del cuadro.
        half = max(w // 2 - x0, x1 - w // 2)
        box = (w // 2 - half, y0, w // 2 + half, y1)
        # El aro: las filas más anchas del último cuadro (sólo el aro).
        a = frames[-1].getchannel("A")
        rows = []
        for y in range(y0, y1):
            row = a.crop((0, y, w, y + 1)).getbbox()
            rows.append((row[2] - row[0]) if row else 0)
        widest = max(rows)
        mid = [y0 + i for i, r in enumerate(rows) if r >= widest * 0.97]
        ring_y = sum(mid) / len(mid)
        scale = RING_WIDTH / widest
        fw = round((box[2] - box[0]) * scale)
        fh = round((box[3] - box[1]) * scale)
        sheet = Image.new("RGBA", (fw * len(frames), fh))
        for i, f in enumerate(frames):
            sheet.alpha_composite(f.crop(box).resize((fw, fh), Image.LANCZOS), (i * fw, 0))
        path = os.path.join(OUT, f"{name}.png")
        sheet.save(path)
        print(f"{name}: {len(frames)} cuadros de {fw}x{fh}, centro del aro en y={round((ring_y - y0) * scale)}")


if __name__ == "__main__":
    main()
