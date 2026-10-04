from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
SQL_DIR = ROOT / "sql"
RAW_DIR = ROOT / "data" / "raw"
EXPORT_DIR = ROOT / "exports"
REPORT_DIR = ROOT / "reports"
SOURCE_LABEL = "instacart"  # remplacé par 'synthetic' si données synthétiques détectées
