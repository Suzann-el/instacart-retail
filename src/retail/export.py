from __future__ import annotations
from pathlib import Path
from .db import Warehouse

TABLES_STAR = ["dim_product","dim_customer","dim_time"]

def export_all(wh: Warehouse, out_dir: Path) -> dict[str, int]:
    out = Path(out_dir); out.mkdir(parents=True, exist_ok=True)
    counts = {}
    for t in TABLES_STAR:
        wh.con.execute(f"COPY (SELECT * FROM {t}) TO '{(out/f'{t}.csv').as_posix()}' (HEADER, DELIMITER ',')")
        counts[t] = wh.con.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
    # Agrégats pré-calculés pour Power BI
    for name in ["kpi_by_department","kpi_by_aisle","kpi_top_products","kpi_by_dow","kpi_by_hour",
                 "reorder_by_department","reorder_top_products","customer_segment_summary",
                 "assortment_long_tail","assortment_cross_selling"]:
        wh.query(name).to_csv(out / f"{name}.csv", index=False)
        counts[name] = len(wh.query(name))
    return counts
