# Analyse opérationnelle retail — Instacart

Projet de Data Analyst retail de bout en bout sur le dataset **Instacart Market Basket Analysis**
(3M+ commandes, 50K produits, 206K clients) : comprendre les comportements d'achat, identifier les
produits qui fidélisent, segmenter les clients et détecter les opportunités de cross-selling.

> **Questions business** : quels rayons performent ? quels clients fidéliser en priorité ?
> quels produits sont souvent achetés ensemble ?

## Ce que fait le projet

| Étape | Contenu |
|---|---|
| 1. Modèle analytique | Staging → star schema DuckDB : `fact_order_lines`, 3 dimensions, 9 contrôles qualité |
| 2. KPIs opérationnels | Volume, panier moyen, taux de réachat — par département, rayon, heure, jour |
| 3. Assortiment | Longue traîne (Pareto), profondeur par département, top produits |
| 4. Fidélité / Réachat | Taux de réachat par rayon et par produit — proxy de satisfaction et d'impact promo |
| 5. Segmentation client | Segmentation comportementale FM (Fréquence × Fidélité × Intervalle), 5 profils actionnables |
| 6. Cross-selling | Associations de départements dans un même panier — guide merchandising |
| 7. Rétention | Courbe de rétention par numéro de commande |
| 8. Power BI | 14 exports CSV + guide DAX avec 8 mesures prêtes à l'emploi |

## Démarrage rapide

```bash
pip install duckdb pandas numpy matplotlib
# Télécharger les données : https://www.kaggle.com/c/instacart-market-basket-analysis/data
# Placer les 6 CSV dans data/raw/
python -m retail build    # modèle + graphiques + exports CSV Power BI
pytest tests/             # suite de tests
```


## Résultats 

Sur les données Instacart  :
- **Taux de réachat global** : ~59% — 3 articles sur 5 sont des répétitions
- **Panier moyen** : ~10 articles par commande
- **Pareto** : top 10% des produits = ~40% des commandes
- **Retention** : ~90% des clients passent une 2e commande ; chute progressive ensuite
- **Pic d'activité** : dimanche matin + samedi après-midi (données US)
- **Cross-selling** : produce + dairy co-achetés dans ~70% des paniers

## Structure

```
sql/
  00_staging.sql           chargement brut des 6 CSV Instacart
  01_model.sql             modèle analytique : fact_order_lines + 3 dimensions
  02_quality.sql           9 contrôles qualité nommés (chk_*)
  03_kpis.sql              KPIs opérationnels (volume, panier, réachat, temps)
  04_reorder.sql           analyse du réachat par rayon, produit, segment
  05_assortment.sql        performance assortiment, longue traîne, cross-selling
  06_customer_segments.sql segmentation FM, cohortes de rétention
src/retail/
  db.py                    Warehouse : build(), query(), checks()
  charts.py                8 graphiques matplotlib
  export.py                14 exports CSV pour Power BI
  cli.py                   python -m retail build
notebooks/
  01_analyse.ipynb         analyse complète pas à pas (9 étapes)
powerbi/
  guide_powerbi.md         modèle de données, 8 mesures DAX, 4 pages recommandées
tests/                     suite de tests
```

## Choix méthodologiques

- **Pas de prix dans Instacart** : les analyses portent sur les volumes et comportements.
  Le taux de réachat remplace le montant comme proxy de valeur et de satisfaction.
- **SQL d'abord** : toute la logique métier est en SQL DuckDB, lisible et auditable.
- **Segmentation sans K-Means** : NTILE(4) sur Fréquence, Fidélité et Intervalle.
- **Cross-selling au niveau département** plutôt que produit : les associations produit-produit
  sont trop nombreuses et trop instables ; le niveau département donne des insights actionnables
  pour le merchandising.




