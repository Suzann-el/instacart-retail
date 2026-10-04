import pytest
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
from retail.db import Warehouse
from retail.config import RAW_DIR

RAW_OK = (RAW_DIR / "orders.csv").exists()

@pytest.fixture(scope="session")
def wh():
    if not RAW_OK:
        pytest.skip("Donnees Instacart absentes")
    return Warehouse.build()
