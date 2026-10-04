from __future__ import annotations
import argparse, sys
from pathlib import Path
from . import charts, export
from .config import EXPORT_DIR, RAW_DIR, REPORT_DIR
from .db import Warehouse

def cmd_build(a) -> int:
    wh = Warehouse.build(Path(a.raw_dir))
    chk = wh.checks()
    bad = chk[chk["violations"] > 0]
    print(f"Contrôles qualité : {len(chk)-len(bad)}/{len(chk)} OK")
    if len(bad):
        print(bad.to_string(index=False)); return 1
    REPORT_DIR.mkdir(exist_ok=True)
    figs = charts.make_all(wh, REPORT_DIR / "figures")
    print(f"Graphiques : {len(figs)} figures -> {REPORT_DIR / 'figures'}")
    if not a.no_export:
        counts = export.export_all(wh, EXPORT_DIR)
        print(f"Exports Power BI : {len(counts)} tables/agrégats -> {EXPORT_DIR}")
    print("Build terminé.")
    return 0

def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="retail")
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("build")
    p.add_argument("--raw-dir", default=str(RAW_DIR))
    p.add_argument("--no-export", action="store_true")
    p.set_defaults(fn=cmd_build)
    a = ap.parse_args(argv)
    return a.fn(a)

if __name__ == "__main__":
    sys.exit(main())
