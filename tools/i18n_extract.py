"""Extrae los textos visibles del juego y actualiza locale/en.po.

Uso (desde la raíz del repo):
    python tools/i18n_extract.py

Cómo funciona la traducción en el juego:
  - El texto fuente es el español: cada "msgid" del .po ES la frase en
    español tal cual está en el código o en la escena.
  - Godot traduce solo los Label/Button/RichTextLabel cuyo texto completo
    coincide con un msgid. Para textos con números ("Oleada %d") el
    código tiene que pasar la plantilla por tr() ANTES de formatear:
        tr("Oleada %d") % n
  - Si una frase no tiene traducción (msgstr vacío), el juego la muestra
    en español: nada se rompe, sólo queda sin traducir.

Qué hace este script:
  - Junta los textos de las escenas (.tscn: text, tooltip_text,
    placeholder_text) y las cadenas de los scripts (.gd) que parecen
    texto para el jugador.
  - Reescribe locale/en.po conservando todas las traducciones que ya
    estaban; las frases nuevas quedan con msgstr "" para completar.
  - Las frases que ya no aparecen en el código se conservan al final
    como entradas obsoletas (#~) por si vuelven.

Después de correrlo: completar los msgstr vacíos (a mano o con Poedit).
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PO_PATH = os.path.join(ROOT, "locale", "en.po")
SCAN_DIRS = ["scenes", "autoload"]

# Escenas/scripts de herramientas internas: no se traducen.
SKIP_FILES = {
    "qa_room.gd", "qa_room.tscn", "catalog.gd", "catalog.tscn",
    "effects_viewer.gd", "effects_viewer.tscn", "map_viewer.gd", "map_viewer.tscn",
    "icon_browser.gd", "icon_browser.tscn", "speed_debug.gd", "sandbox.gd",
    "sandbox.tscn", "tile_showcase.gd", "tile_showcase.tscn",
    "hand_painted_playground.gd", "hand_painted_playground.tscn",
    "build_info.gd", "steam_bridge.gd", "supabase.gd",
}

STRING_RE = re.compile(r'(?<![A-Za-z_&^])"((?:[^"\\\n]|\\.)*)"')
TSCN_RE = re.compile(r'^(?:text|tooltip_text|placeholder_text) = "((?:[^"\\]|\\.)*)"', re.M)
# Líneas cuyos strings son internos (logs, señales, grupos, sonidos...).
SKIP_LINE_RE = re.compile(
    r'\b(print|printerr|push_warning|push_error|assert|play_sfx|play_music|'
    r'get_node|get_node_or_null|has_node|find_child|is_action\w*|add_to_group|'
    r'is_in_group|remove_from_group|has_method|emit_signal|connect|'
    r'add_theme_\w+|get_theme_\w+|has_meta|get_meta|set_meta|preload|load|'
    r'ResourceLoader\.\w+|set_deferred|call_deferred|tween_property|'
    r'InputMap\.\w+|change_scene_to_file)\s*\(|\.name\s*=|get_bus_index'
)
LETTER = re.compile(r'[A-Za-zÁÉÍÓÚÑÜáéíóúñü]')


FORMAT_SPEC = re.compile(r'%[-+0-9.]*[sdfxi%]')


def looks_like_ui_text(s: str) -> bool:
    # Letras que no sean parte de un %d / %s / %.2f.
    if not LETTER.search(FORMAT_SPEC.sub("", s)):
        return False
    if any(t in s for t in ("window.", "navigator", "(function", "eq.", "?select=", ".cfg", "res:", "uid:")):
        return False
    # Sin espacios y con / _ . en el medio: rutas, archivos, ids de sprites.
    if " " not in s and re.search(r'[/_]|\.[A-Za-z]', s):
        return False
    if re.fullmatch(r'(north|south)-(east|west)[-0-9a-f]*|one-last-hero-', s):
        return False
    if s.startswith(("res://", "user://", "http", "uid://", "[", "#")):
        return False
    if re.fullmatch(r'[a-z0-9_]+', s):           # ids: "ui_click", "rat_2"
        return False
    if re.fullmatch(r'[A-Za-z0-9_]+(/[A-Za-z0-9_]+)+', s):   # rutas de nodos
        return False
    if re.fullmatch(r'[0-9a-fA-F]{6,8}', s):    # colores
        return False
    # Palabras sueltas tipo "Content" o "Master" (nodos/buses) se cuelan
    # igual; no pasa nada: quedan con msgstr vacío y no se traducen.
    return True


def extract() -> dict:
    found = {}   # msgid -> [refs]
    for d in SCAN_DIRS:
        for name in sorted(os.listdir(os.path.join(ROOT, d))):
            if name in SKIP_FILES:
                continue
            path = os.path.join(ROOT, d, name)
            rel = f"{d}/{name}"
            if name.endswith(".tscn"):
                text = open(path, encoding="utf-8").read()
                for m in TSCN_RE.finditer(text):
                    s = po_unescape(m.group(1))
                    if s.strip() and LETTER.search(s) and s.strip() != "...":
                        line = text.count("\n", 0, m.start()) + 1
                        found.setdefault(s, []).append(f"{rel}:{line}")
            elif name.endswith(".gd"):
                for i, line in enumerate(open(path, encoding="utf-8"), 1):
                    stripped = line.strip()
                    if stripped.startswith("#") or SKIP_LINE_RE.search(line):
                        continue
                    code = line.split(" #")[0] if '"' not in line.split(" #")[-1] else line
                    for m in STRING_RE.finditer(code):
                        s = po_unescape(m.group(1))
                        if looks_like_ui_text(s):
                            found.setdefault(s, []).append(f"{rel}:{i}")
    return found


def po_escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\t", "\\t")


def po_unescape(s: str) -> str:
    out, i = [], 0
    while i < len(s):
        c = s[i]
        if c == "\\" and i + 1 < len(s):
            n = s[i + 1]
            out.append({"n": "\n", "t": "\t", '"': '"', "\\": "\\"}.get(n, n))
            i += 2
        else:
            out.append(c)
            i += 1
    return "".join(out)


def read_po(path: str) -> dict:
    """msgid -> msgstr (incluye obsoletas #~)."""
    entries = {}
    if not os.path.exists(path):
        return entries
    msgid = msgstr = None
    target = None
    for raw in open(path, encoding="utf-8"):
        line = raw.strip()
        if line.startswith("#~ "):
            line = line[3:]
        if line.startswith("msgid "):
            if msgid is not None:
                entries[msgid] = msgstr or ""
            msgid, msgstr, target = po_unescape(line[7:-1]), None, "id"
        elif line.startswith("msgstr "):
            msgstr, target = po_unescape(line[8:-1]), "str"
        elif line.startswith('"') and target:
            chunk = po_unescape(line[1:-1])
            if target == "id":
                msgid += chunk
            else:
                msgstr += chunk
    if msgid is not None:
        entries[msgid] = msgstr or ""
    entries.pop("", None)
    return entries


def write_po(path: str, found: dict, old: dict) -> tuple:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    lines = [
        'msgid ""',
        'msgstr ""',
        '"Project-Id-Version: One Last Hero\\n"',
        '"Language: en\\n"',
        '"MIME-Version: 1.0\\n"',
        '"Content-Type: text/plain; charset=UTF-8\\n"',
        '"Content-Transfer-Encoding: 8bit\\n"',
        "",
    ]
    missing = 0
    for msgid in sorted(found, key=lambda k: (found[k][0], k)):
        msgstr = old.get(msgid, "")
        if not msgstr:
            missing += 1
        lines.append("#: " + " ".join(found[msgid][:3]))
        lines.append(f'msgid "{po_escape(msgid)}"')
        lines.append(f'msgstr "{po_escape(msgstr)}"')
        lines.append("")
    obsolete = [k for k in old if k not in found and old[k]]
    for msgid in sorted(obsolete):
        lines.append(f'#~ msgid "{po_escape(msgid)}"')
        lines.append(f'#~ msgstr "{po_escape(old[msgid])}"')
        lines.append("")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    return len(found), missing, len(obsolete)


def main() -> None:
    found = extract()
    old = read_po(PO_PATH)
    # Semilla opcional: archivo TSV "español<TAB>inglés" para cargar
    # muchas traducciones de una (python tools/i18n_extract.py seed.tsv).
    if len(sys.argv) > 1:
        for raw in open(sys.argv[1], encoding="utf-8"):
            if "\t" in raw:
                src, dst = raw.rstrip("\n").split("\t", 1)
                if dst.strip():
                    old[po_unescape(src)] = po_unescape(dst)
    total, missing, obsolete = write_po(PO_PATH, found, old)
    print(f"{total} frases, {missing} sin traducir, {obsolete} obsoletas -> {os.path.relpath(PO_PATH, ROOT)}")


if __name__ == "__main__":
    main()
