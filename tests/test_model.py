import pytest, pandas as pd
from retail.db import Warehouse

def test_quality_checks_all_pass(wh):
    chk = wh.checks()
    assert len(chk) >= 9
    assert (chk["violations"] <= 0).all(), chk[chk["violations"] > 0]

def test_fact_grain_unique(wh):
    n = wh.con.execute("SELECT COUNT(*) - COUNT(DISTINCT order_id || '|' || product_id || '|' || eval_set) FROM fact_order_lines").fetchone()[0]
    assert n == 0

def test_dim_product_complete(wh):
    n_orphan = wh.con.execute("SELECT COUNT(*) FROM fact_order_lines WHERE product_name IS NULL").fetchone()[0]
    assert n_orphan == 0

def test_reorder_binary(wh):
    assert wh.con.execute("SELECT COUNT(*) FROM fact_order_lines WHERE reordered NOT IN (0,1)").fetchone()[0] == 0

def test_kpi_global_sanity(wh):
    k = wh.query("kpi_global").iloc[0]
    assert k["total_users"] > 0
    assert 1 <= k["avg_basket_size"] <= 100
    assert 0 <= k["global_reorder_rate_pct"] <= 100

def test_kpi_dept_sums_to_total(wh):
    dept = wh.query("kpi_by_department")
    total = wh.con.execute("SELECT COUNT(*) FROM fact_order_lines").fetchone()[0]
    assert dept["items_sold"].sum() == pytest.approx(total, rel=0.01)

def test_reorder_rates_between_0_and_100(wh):
    dept = wh.query("reorder_by_department")
    assert (dept["reorder_rate_pct"] >= 0).all() and (dept["reorder_rate_pct"] <= 100).all()

def test_customer_segments_cover_all_users(wh):
    segs = wh.query("customer_segment_summary")
    n_seg = segs["nb_clients"].sum()
    n_total = wh.con.execute("SELECT COUNT(DISTINCT user_id) FROM dim_customer").fetchone()[0]
    assert n_seg == n_total

def test_long_tail_pct_sums_to_100(wh):
    lt = wh.query("assortment_long_tail")
    assert lt["pct_orders"].sum() == pytest.approx(100.0, abs=0.5)

def test_cross_selling_departments_different(wh):
    cs = wh.query("assortment_cross_selling")
    assert (cs["dept_a"] != cs["dept_b"]).all()

def test_retention_monotonically_decreasing(wh):
    ret = wh.query("customer_cohort_retention")
    users = ret["nb_users"].values
    assert all(users[i] >= users[i+1] for i in range(len(users)-1))

def test_no_personal_data_in_exports(wh):
    forbidden = ["email","phone","first_name","last_name","address","birth"]
    for t in ["dim_customer","fact_order_lines"]:
        cols = [c[0].lower() for c in wh.con.execute(f"DESCRIBE {t}").fetchall()]
        assert not [c for c in cols if any(f in c for f in forbidden)]
