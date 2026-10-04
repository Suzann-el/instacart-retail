# Guide Power BI — Analyse Instacart Retail

## 1. Import des données

Dans Power BI Desktop : **Obtenir les données → Texte/CSV** → importer chacun des fichiers du dossier `exports/` :

| Fichier | Description |
|---|---|
| `dim_product.csv` | Dimension produit (produit, rayon, département) |
| `dim_customer.csv` | Agrégats client (commandes, panier, réachat) |
| `dim_time.csv` | Dimension temps (heure, jour, créneau) |
| `fact_order_lines.csv` | Table de faits (une ligne = un article dans une commande) |
| `kpi_by_department.csv` | KPIs pré-calculés par département |
| `customer_segment_summary.csv` | Résumé des segments clients |
| `reorder_top_products.csv` | Top produits par taux de réachat |
| `assortment_long_tail.csv` | Analyse longue traîne |
| `assortment_cross_selling.csv` | Associations de départements |

## 2. Modèle de données (relations)

Dans l'onglet **Modèle** de Power BI, créer les relations suivantes :

```
fact_order_lines[product_id]      → dim_product[product_id]
fact_order_lines[user_id]         → dim_customer[user_id]
fact_order_lines[order_dow]       → dim_time[order_dow]
fact_order_lines[order_hour_of_day] → dim_time[order_hour_of_day]
```

Type de relation : **Plusieurs à un (\*:1)**, sens unique.

## 3. Mesures DAX essentielles

Créer une table de mesures vide (**Saisir des données**) nommée `_Mesures`, puis ajouter :

### Volume
```dax
Nb Commandes = DISTINCTCOUNT(fact_order_lines[order_id])

Nb Articles = COUNT(fact_order_lines[product_id])

Taille Panier Moyenne = DIVIDE([Nb Articles], [Nb Commandes])

Nb Clients Actifs = DISTINCTCOUNT(fact_order_lines[user_id])
```

### Fidélité
```dax
Taux de Réachat = 
DIVIDE(
    CALCULATE(COUNT(fact_order_lines[reordered]), fact_order_lines[reordered] = 1),
    COUNT(fact_order_lines[reordered])
)

Taux de Réachat % = FORMAT([Taux de Réachat], "0.0%")
```

### Assortiment
```dax
Nb Produits Actifs = DISTINCTCOUNT(fact_order_lines[product_id])

Nb Produits par Rayon = 
CALCULATE(
    DISTINCTCOUNT(fact_order_lines[product_id]),
    ALLEXCEPT(fact_order_lines, fact_order_lines[aisle])
)

Part des Commandes = 
DIVIDE([Nb Commandes], CALCULATE([Nb Commandes], ALL(fact_order_lines)))
```

### Client
```dax
Commandes Moyennes par Client = 
AVERAGEX(
    SUMMARIZE(fact_order_lines, fact_order_lines[user_id]),
    CALCULATE(DISTINCTCOUNT(fact_order_lines[order_id]))
)
```

## 4. Pages recommandées

### Page 1 — Vue d'ensemble opérationnelle
- Carte KPI : Nb commandes, Nb clients, Taille panier moyenne, Taux de réachat global
- Histogramme : Commandes par heure (dim_time[order_hour_of_day])
- Histogramme : Commandes par jour (dim_time[day_name])
- Treemap : Volume par département

### Page 2 — Performance assortiment
- Tableau : Top 20 produits (trier par Nb Articles DESC)
- Graphique barres : Taux de réachat par département
- Graphique barres : Longue traîne (depuis assortment_long_tail.csv)
- Matrice : département × jour → taux de réachat

### Page 3 — Segments clients
- Graphique barres : Nb clients par segment (customer_segment_summary.csv)
- Nuage de points : Nb commandes × Taux de réachat (coloré par segment)
- Tableau : Résumé des segments avec avg_orders, avg_basket, avg_reorder_rate_pct

### Page 4 — Cross-selling et associations
- Graphique barres : Top associations de départements (assortment_cross_selling.csv)
- Matrice département × département : fréquence de co-achat

## 5. Filtres recommandés

Ajouter en segments ou filtres de page :
- `dim_product[department]` — filtrer par département
- `dim_time[time_slot]` — filtrer par créneau horaire (Matin / Après-midi / Soir)
- `dim_customer[total_orders]` — slider pour filtrer par niveau d'engagement client

## 6. Bonnes pratiques

- **Ne pas importer fact_order_lines en entier** si votre machine a peu de RAM : utiliser les agrégats pré-calculés (`kpi_by_department.csv`, etc.) pour les visualisations, et réserver fact_order_lines pour les drills-down ponctuels.
- **Actualisation** : si vous régénérez les CSV avec `python -m retail build`, cliquez sur **Actualiser** dans Power BI pour recharger.
- **Naming** : renommer les colonnes dans Power Query pour enlever les underscores (`order_id` → `Order ID`).
