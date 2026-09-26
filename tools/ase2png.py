"""Convierte .aseprite a hojas PNG horizontales (un frame al lado del otro).

Uso:
  python tools/ase2png.py archivo.aseprite [...]      -> PNG al lado de cada archivo
  python tools/ase2png.py --companions                -> regenera assets/companions/

--companions toma los animales de assets/sprites/<Animal>/ (Idle y Walk en
4 direcciones), los recorta al rectángulo que ocupa el animal en TODOS sus
frames (así no se mueve al cambiar de animación) y los guarda como
assets/companions/<id>/idle_front.png, walk_left.png, etc. Imprime el
tamaño de frame de cada uno para companion.gd (SPRITES).

Soporta RGBA, escala de grises e indexado, con mezcla normal y opacidad
de capa/cel. Necesita Pillow (pip install pillow).
"""
import glob
import os
import struct
import sys
import zlib

from PIL import Image


def _read_string(b, o):
    n = struct.unpack_from("<H", b, o)[0]
    return b[o + 2:o + 2 + n].decode("utf-8", "replace"), o + 2 + n


def parse(path):
    b = open(path, "rb").read()
    _, magic, nframes, w, h, depth = struct.unpack_from("<IHHHHH", b, 0)
    assert magic == 0xA5E0, "no es un .aseprite"
    transparent_idx = b[28]
    o = 128
    layers, frames, palette = [], [], {}
    for _ in range(nframes):
        fbytes, _, old_chunks, dur = struct.unpack_from("<IHHH", b, o)
        new_chunks = struct.unpack_from("<I", b, o + 12)[0]
        nchunks = new_chunks if new_chunks else old_chunks
        p = o + 16
        cels = []
        for _ in range(nchunks):
            csize, ctype = struct.unpack_from("<IH", b, p)
            d = p + 6
            if ctype == 0x2004:  # capa
                flags, ltype, _, _, _, blend, opacity = struct.unpack_from("<HHHHHHB", b, d)
                name, _ = _read_string(b, d + 16)
                layers.append({"flags": flags, "type": ltype, "blend": blend, "opacity": opacity, "name": name})
            elif ctype == 0x2005:  # cel
                li, x, y, op, ctype2 = struct.unpack_from("<HhhBH", b, d)
                q = d + 16
                cel = {"layer": li, "x": x, "y": y, "opacity": op, "ctype": ctype2}
                if ctype2 in (0, 2):
                    cw, ch = struct.unpack_from("<HH", b, q)
                    raw = b[q + 4:p + csize]
                    if ctype2 == 2:
                        raw = zlib.decompress(raw)
                    cel.update(w=cw, h=ch, raw=raw)
                elif ctype2 == 1:
                    cel["link"] = struct.unpack_from("<H", b, q)[0]
                cels.append(cel)
            elif ctype == 0x2019:  # paleta nueva
                _, first, last = struct.unpack_from("<III", b, d)
                q = d + 20
                for i in range(first, last + 1):
                    eflags = struct.unpack_from("<H", b, q)[0]
                    r, g, bb, a = b[q + 2:q + 6]
                    q += 6
                    if eflags & 1:
                        _, q = _read_string(b, q)
                    palette[i] = (r, g, bb, a)
            elif ctype == 0x0004 and not palette:  # paleta vieja
                npk = struct.unpack_from("<H", b, d)[0]
                q = d + 2
                idx = 0
                for _ in range(npk):
                    skip, n = b[q], b[q + 1]
                    q += 2
                    idx += skip
                    n = n or 256
                    for _ in range(n):
                        palette[idx] = (b[q], b[q + 1], b[q + 2], 255)
                        q += 3
                        idx += 1
            p += csize
        frames.append({"dur": dur, "cels": cels})
        o += fbytes
    return w, h, depth, transparent_idx, layers, frames, palette


def _cel_image(cel, depth, tidx, palette):
    cw, ch, raw = cel["w"], cel["h"], cel["raw"]
    if depth == 32:
        return Image.frombytes("RGBA", (cw, ch), raw[:cw * ch * 4])
    if depth == 16:
        px = [(raw[i], raw[i], raw[i], raw[i + 1]) for i in range(0, cw * ch * 2, 2)]
    else:
        px = [(0, 0, 0, 0) if v == tidx else palette.get(v, (0, 0, 0, 0)) for v in raw[:cw * ch]]
    im = Image.new("RGBA", (cw, ch))
    im.putdata(px)
    return im


def frames_of(path):
    """Lista de imágenes RGBA (una por frame, tamaño del lienzo)."""
    w, h, depth, tidx, layers, frames, palette = parse(path)
    imgs = []
    for fr in frames:
        canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        for cel in sorted(fr["cels"], key=lambda c: c["layer"]):
            layer = layers[cel["layer"]]
            if not (layer["flags"] & 1) or layer["type"] != 0:
                continue
            src = cel
            if cel["ctype"] == 1:
                src = next(c for c in frames[cel["link"]]["cels"] if c["layer"] == cel["layer"])
            if "raw" not in src:
                continue
            im = _cel_image(src, depth, tidx, palette)
            alpha = (layer["opacity"] / 255.0) * (cel["opacity"] / 255.0)
            if alpha < 1.0:
                im.putalpha(im.getchannel("A").point(lambda v: int(v * alpha)))
            layer_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
            layer_img.paste(im, (cel["x"], cel["y"]))
            canvas.alpha_composite(layer_img)
        imgs.append(canvas)
    return imgs


def strip(imgs, crop=None):
    if crop:
        imgs = [im.crop(crop) for im in imgs]
    fw, fh = imgs[0].size
    out = Image.new("RGBA", (fw * len(imgs), fh), (0, 0, 0, 0))
    for i, im in enumerate(imgs):
        out.paste(im, (i * fw, 0))
    return out


# ── Acompañantes ───────────────────────────────────────────────────
# carpeta en assets/sprites/ -> id en assets/companions/
COMPANION_SOURCES = {
    "Chick": "chick", "Chicken": "chicken", "Rooster": "rooster",
    "Calf": "calf", "Bull": "bull", "Foal": "foal", "Horse": "horse",
    "Goatling": "goatling", "Goat": "goat", "Gosling": "gosling", "Goose": "goose",
    "Lamb": "lamb", "Sheep": "sheep", "Rabbit_cub": "rabbit_cub", "Rabbit": "rabbit",
    "Piglet": "piglet", "Turkey": "turkey",
}
DIRS = ("front", "back", "left", "right")


def export_companions(root="."):
    sprites = os.path.join(root, "assets", "sprites")
    out_root = os.path.join(root, "assets", "companions")
    for folder, cid in COMPANION_SOURCES.items():
        sheets = {}
        for f in glob.glob(os.path.join(sprites, folder, "**", "*.aseprite"), recursive=True):
            name = os.path.splitext(os.path.basename(f))[0].lower()
            anim = "idle" if "idle" in name else "walk" if "walk" in name else None
            direction = next((d for d in DIRS if d in name), None)
            if anim and direction:
                sheets[(anim, direction)] = frames_of(f)
        if len(sheets) != 8:
            print("!! %s: faltan hojas (%d de 8)" % (folder, len(sheets)))
            continue
        # Rectángulo común a todos los frames de todas las animaciones.
        box = None
        for imgs in sheets.values():
            for im in imgs:
                bb = im.getbbox()
                if bb:
                    box = bb if box is None else (min(box[0], bb[0]), min(box[1], bb[1]),
                                                   max(box[2], bb[2]), max(box[3], bb[3]))
        os.makedirs(os.path.join(out_root, cid), exist_ok=True)
        for (anim, direction), imgs in sheets.items():
            strip(imgs, box).save(os.path.join(out_root, cid, "%s_%s.png" % (anim, direction)))
        fw, fh = box[2] - box[0], box[3] - box[1]
        print('\t"%s": Vector2(%d, %d),' % (cid, fw, fh))


if __name__ == "__main__":
    if sys.argv[1:] == ["--companions"]:
        export_companions(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
    else:
        for src in sys.argv[1:]:
            out = os.path.splitext(src)[0] + ".png"
            strip(frames_of(src)).save(out)
            print(os.path.basename(out))
