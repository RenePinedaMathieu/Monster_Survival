"""Resumen del banco de DPS (tools/dps_bench.bat): lee los .jsonl que deja
dps_bench.gd en la carpeta que se le pasa, escribe informe.txt ahí y lo
muestra.

    python tools/dps_bench/report.py build/dps_bench
"""
import glob
import json
import os
import statistics
import sys

HEROES = [("swordman", "GAROTH"), ("elara", "ELARA"), ("doren", "DOREN")]
SCENARIOS = ["1 cerca", "1 lejos", "9 cerca", "9 lejos", "rodeado 12"]


def load(path):
    rows = []
    for f in sorted(glob.glob(path)):
        with open(f, encoding="utf-8") as fh:
            rows += [json.loads(l) for l in fh if l.strip()]
    return rows


def weapon_dps(r):
    """Daño del arma probada (todo lo que no es el ataque base)."""
    if r["config"] == "ataque":
        return r["by"].get("ataque", 0.0)
    return sum(v for k, v in r["by"].items() if k != "ataque")


def main():
    d = sys.argv[1] if len(sys.argv) > 1 else "build/dps_bench"
    out = []
    p = out.append

    dummy = {h: {} for h, _ in HEROES}
    for h, _ in HEROES:
        for r in load(f"{d}/{h}_dummy.jsonl"):
            dummy[h].setdefault((r["config"], r["stage"]), {})[r["scenario"]] = weapon_dps(r)

    p("BANCO DE DPS · blancos quietos, daño por segundo")
    p("Héroe completo: ataque en la última forma + sus 4 armas a nivel 5 (o evolucionadas),")
    p("sin cartas extra ni pasivas: las mismas 20 cartas para los tres")
    p(f"{'':16}" + "".join(s.rjust(12) for s in SCENARIOS))
    for evo in (False, True):
        for h, name in HEROES:
            rows = dummy[h]
            tot = {s: rows.get(("ataque", "Tmax"), {}).get(s, 0.0) for s in SCENARIOS}
            for (w, st), vals in rows.items():
                if w == "ataque":
                    continue
                best = "EVO" if evo else "L5"
                if st == best:
                    for s in SCENARIOS:
                        tot[s] += vals.get(s, 0.0)
            label = f"{name}{' evol.' if evo else ''}"
            p(f"{label:16}" + "".join(f"{tot[s]:12.0f}" for s in SCENARIOS))
    p("")
    p("Por arma (L5 = nivel 5, MAX = con sus cartas extra, EVO = evolucionada)")
    for h, name in HEROES:
        p(f"-- {name}")
        for (w, st), vals in dummy[h].items():
            if st in ("L1", "L3"):
                continue
            p(f"{w + ' ' + st:28}" + "".join(f"{vals.get(s, 0.0):12.1f}" for s in SCENARIOS))
    p("")

    p("HORDA · 40 monstruos con la vida de la oleada de cada etapa: segundos en limpiarla")
    p("(promedio de las semillas; el héroe no se mueve)")
    for h, name in HEROES:
        by = {}
        for r in load(f"{d}/{h}_horde_*.jsonl"):
            by.setdefault(r["stage"], []).append(r["clear_s"])
        p(f"{name:8}" + " | ".join(f"{st} {statistics.mean(v):.1f}" for st, v in by.items()))
    p("")

    p("JEFE · demon1 con la vida de la oleada 10 (1548): daño por segundo")
    for h, name in HEROES:
        by = {}
        src = {}
        for r in load(f"{d}/{h}_boss_*.jsonl"):
            by.setdefault(r["stage"], []).append(r["boss_dps"])
            if r["stage"] == "final nv25":
                for k, v in r["by"].items():
                    src.setdefault(k, []).append(v)
        p(f"{name:8}" + " | ".join(f"{st} {statistics.mean(v):.0f}" for st, v in by.items()))
        top = sorted(((statistics.mean(v), k) for k, v in src.items()), reverse=True)
        p(f"{'':8}final: " + ", ".join(f"{k} {v:.0f}" for v, k in top))
    p("")

    p("NIVEL AL TERMINAR CADA OLEADA · partida real del bot (run_bot.gd)")
    waves = [1, 2, 3, 5, 8, 10, 12, 15, 18, 20]
    p(f"{'oleada':8}" + "".join(f"{w:5}" for w in waves))
    for h, name in HEROES:
        by = {}
        for r in load(f"{d}/{h}_run_*.jsonl"):
            by.setdefault(r["wave"], []).append(r["level"])
        p(f"{name:8}" + "".join(f"{round(statistics.mean(by[w])) if w in by else '-':>5}" for w in waves))

    text ="\n".join(out) + "\n"
    with open(os.path.join(d, "informe.txt"), "w", encoding="utf-8") as fh:
        fh.write(text)
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    print(text)


if __name__ == "__main__":
    main()
