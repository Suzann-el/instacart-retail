from __future__ import annotations
from pathlib import Path
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from .db import Warehouse

C1,C2,C3,C4,C5 = "#1d3557","#e76f51","#2a9d8f","#e9c46a","#264653"
COLORS = [C1,C2,C3,C4,C5,"#f4a261","#a8dadc","#457b9d"]
plt.rcParams.update({"figure.dpi":120,"font.size":9,"axes.spines.top":False,
                     "axes.spines.right":False,"axes.grid":True,"grid.alpha":0.25})

def _save(fig, path):
    fig.tight_layout(); fig.savefig(path, dpi=120, bbox_inches="tight"); plt.close(fig); return path

def dept_performance(wh, path):
    df = wh.query("kpi_by_department").head(12)
    fig, axes = plt.subplots(1, 2, figsize=(11, 4))
    axes[0].barh(df["department"], df["items_sold"]/1e3, color=C1)
    axes[0].set_xlabel("Articles vendus (k)"); axes[0].set_title("Volume par département")
    axes[0].invert_yaxis()
    axes[1].barh(df["department"], df["reorder_rate_pct"],
                 color=[C2 if v > df["reorder_rate_pct"].mean() else C3 for v in df["reorder_rate_pct"]])
    axes[1].axvline(df["reorder_rate_pct"].mean(), color="black", ls="--", lw=1)
    axes[1].set_xlabel("Taux de réachat (%)"); axes[1].set_title("Taux de réachat par département")
    axes[1].invert_yaxis()
    return _save(fig, path)

def time_heatmap(wh, path):
    df = wh.query("kpi_by_hour")
    dow = wh.query("kpi_by_dow")
    fig, axes = plt.subplots(1, 2, figsize=(11, 3.8))
    axes[0].bar(df["order_hour_of_day"], df["orders"]/1e3, color=C1)
    axes[0].set_xlabel("Heure"); axes[0].set_ylabel("Commandes (k)")
    axes[0].set_title("Commandes par heure de la journée")
    days_order = ["Lundi","Mardi","Mercredi","Jeudi","Vendredi","Samedi","Dimanche"]
    dow_sorted = dow.copy()
    dow_sorted["day_name"] = pd.Categorical(dow_sorted["day_name"], categories=days_order, ordered=True)
    dow_sorted = dow_sorted.sort_values("day_name")
    axes[1].bar(dow_sorted["day_name"], dow_sorted["orders"]/1e3, color=C2)
    axes[1].set_xlabel("Jour"); axes[1].set_ylabel("Commandes (k)")
    axes[1].set_title("Commandes par jour de la semaine")
    axes[1].tick_params(axis="x", rotation=30)
    return _save(fig, path)

def basket_distribution(wh, path):
    df = wh.query("kpi_basket_distribution").head(20)
    fig, ax = plt.subplots(figsize=(9, 3.8))
    ax.bar(df["basket_size"], df["pct_orders"], color=C3)
    ax.set_xlabel("Taille du panier (nb articles)"); ax.set_ylabel("% des commandes")
    ax.set_title("Distribution de la taille du panier")
    return _save(fig, path)

def reorder_by_dept(wh, path):
    df = wh.query("reorder_by_department").sort_values("reorder_rate_pct", ascending=True)
    fig, ax = plt.subplots(figsize=(9, 5))
    bars = ax.barh(df["department"], df["reorder_rate_pct"],
                   color=[C2 if v >= 60 else C1 for v in df["reorder_rate_pct"]])
    ax.axvline(df["reorder_rate_pct"].mean(), color="black", ls="--", lw=1,
               label=f"Moyenne : {df['reorder_rate_pct'].mean():.1f}%")
    ax.set_xlabel("Taux de réachat (%)"); ax.set_title("Taux de réachat par département")
    ax.legend(frameon=False)
    return _save(fig, path)

def long_tail(wh, path):
    df = wh.query("assortment_long_tail")
    fig, ax = plt.subplots(figsize=(8, 4))
    bars = ax.bar(df["segment"], df["pct_orders"], color=[C1,C2,C3,C4])
    ax.bar_label(bars, [f"{v:.1f}%" for v in df["pct_orders"]], fontsize=9)
    ax.set_ylabel("% des commandes"); ax.set_title("Loi de Pareto — concentration des ventes par produit")
    ax.tick_params(axis="x", rotation=15)
    return _save(fig, path)

def customer_segments(wh, path):
    df = wh.query("customer_segment_summary")
    fig, axes = plt.subplots(1, 3, figsize=(13, 4))
    colors = [COLORS[i % len(COLORS)] for i in range(len(df))]
    axes[0].barh(df["segment"], df["nb_clients"], color=colors)
    axes[0].set_title("Nb clients par segment"); axes[0].invert_yaxis()
    axes[1].barh(df["segment"], df["avg_orders"], color=colors)
    axes[1].set_title("Commandes moyennes"); axes[1].invert_yaxis()
    axes[2].barh(df["segment"], df["avg_reorder_rate_pct"], color=colors)
    axes[2].set_title("Taux de réachat moyen (%)"); axes[2].invert_yaxis()
    return _save(fig, path)

def retention_curve(wh, path):
    df = wh.query("customer_cohort_retention")
    fig, ax = plt.subplots(figsize=(9, 4))
    ax.plot(df["commande_n"], df["retention_pct"], marker="o", color=C1, lw=2)
    ax.fill_between(df["commande_n"], df["retention_pct"], alpha=0.15, color=C1)
    ax.set_xlabel("Numéro de commande depuis la 1ère"); ax.set_ylabel("% utilisateurs encore actifs")
    ax.set_title("Courbe de rétention client")
    ax.set_ylim(0, 110); ax.axhline(100, color="grey", ls="--", lw=1)
    return _save(fig, path)

def cross_selling(wh, path):
    df = wh.query("assortment_cross_selling").head(10)
    fig, ax = plt.subplots(figsize=(9, 4))
    labels = [f"{r['dept_a']} +\n{r['dept_b']}" for _, r in df.iterrows()]
    ax.bar(range(len(df)), df["pct_baskets"], color=C4)
    ax.set_xticks(range(len(df)), labels, rotation=30, ha="right", fontsize=8)
    ax.set_ylabel("% des paniers"); ax.set_title("Top associations de départements dans un même panier")
    return _save(fig, path)

def make_all(wh: Warehouse, out_dir: Path) -> dict[str, Path]:
    out = Path(out_dir); out.mkdir(parents=True, exist_ok=True)
    return {
        "dept_performance": dept_performance(wh, out / "01_dept_performance.png"),
        "time_heatmap": time_heatmap(wh, out / "02_time_patterns.png"),
        "basket_dist": basket_distribution(wh, out / "03_basket_distribution.png"),
        "reorder": reorder_by_dept(wh, out / "04_reorder_by_dept.png"),
        "long_tail": long_tail(wh, out / "05_long_tail.png"),
        "segments": customer_segments(wh, out / "06_customer_segments.png"),
        "retention": retention_curve(wh, out / "07_retention.png"),
        "cross_selling": cross_selling(wh, out / "08_cross_selling.png"),
    }
