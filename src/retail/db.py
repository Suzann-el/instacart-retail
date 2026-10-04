from __future__ import annotations
import re
from pathlib import Path
import duckdb
import pandas as pd
from .config import RAW_DIR, SQL_DIR

_BLOCK = re.compile(r"^-- name: (\w+)[^\n]*\n", re.M)

def named_queries(path: Path) -> dict[str, str]:
    parts = _BLOCK.split(path.read_text(encoding="utf-8"))[1:]
    out = {}
    for name, body in zip(parts[::2], parts[1::2]):
        lines = [l for l in body.splitlines() if not l.strip().startswith("--")]
        out[name] = "\n".join(lines).strip().rstrip(";")
    return out

class Warehouse:
    def __init__(self, con: duckdb.DuckDBPyConnection):
        self.con = con
        self._queries: dict[str, str] = {}
        for f in sorted(SQL_DIR.glob("0[2-9]_*.sql")):
            self._queries.update(named_queries(f))

    @classmethod
    def build(cls, raw_dir: Path = RAW_DIR) -> "Warehouse":
        if not (Path(raw_dir) / "orders.csv").exists():
            raise FileNotFoundError(f"Fichiers Instacart introuvables dans {raw_dir}")
        con = duckdb.connect()
        for f in ("00_staging.sql", "01_model.sql"):
            sql = (SQL_DIR / f).read_text(encoding="utf-8")
            sql = sql.replace("${RAW_DIR}", str(Path(raw_dir)).replace("\\", "/"))
            con.execute(sql)
            if f == "00_staging.sql":
               con.execute("""CREATE OR REPLACE TABLE stg_order_products_prior AS 
                 SELECT * FROM stg_order_products_prior LIMIT 300000""")
        return cls(con)

    def query(self, name: str) -> pd.DataFrame:
        if name not in self._queries:
            raise KeyError(f"requête inconnue : {name}")
        return self.con.execute(self._queries[name]).fetchdf()

    def checks(self) -> pd.DataFrame:
        rows = []
        for n, s in self._queries.items():
            if n.startswith("chk_"):
                v = float(self.con.execute(s).fetchone()[0])
                rows.append({"check": n, "violations": v})
        return pd.DataFrame(rows, columns=["check", "violations"])
