-- 04_reorder.sql : analyse du réachat (proxy promotions/fidélité)
-- Note : sans date réelle dans Instacart, on utilise order_number comme proxy temporel
-- et days_since_prior_order comme proxy de l'intervalle entre visites.

-- name: reorder_by_department
SELECT department,
  COUNT(*) AS items,
  ROUND(100.0 * SUM(reordered) / COUNT(*), 1) AS reorder_rate_pct,
  ROUND(100.0 * SUM(CASE WHEN reordered=1 THEN 1 END) / COUNT(*), 1) AS loyal_items_pct
FROM fact_order_lines
GROUP BY department ORDER BY reorder_rate_pct DESC;

-- name: reorder_top_products
SELECT product_name, department, aisle,
  COUNT(*) AS nb_appearances,
  SUM(reordered) AS nb_reorders,
  ROUND(100.0 * SUM(reordered) / COUNT(*), 1) AS reorder_rate_pct,
  COUNT(DISTINCT user_id) AS unique_buyers
FROM fact_order_lines
GROUP BY product_name, department, aisle
HAVING COUNT(*) >= 50
ORDER BY reorder_rate_pct DESC LIMIT 20;

-- name: reorder_new_vs_loyal_customers
SELECT
  CASE WHEN total_orders = 1 THEN '1 commande'
       WHEN total_orders BETWEEN 2 AND 5 THEN '2-5 commandes'
       WHEN total_orders BETWEEN 6 AND 10 THEN '6-10 commandes'
       ELSE '10+ commandes' END AS segment,
  COUNT(*) AS nb_users,
  ROUND(AVG(avg_basket_size), 1) AS avg_basket,
  ROUND(AVG(reorder_rate) * 100, 1) AS avg_reorder_rate_pct,
  ROUND(AVG(avg_days_between_orders), 1) AS avg_days_between_orders
FROM dim_customer
GROUP BY 1 ORDER BY MIN(total_orders);

-- name: reorder_interval_distribution
SELECT
  CASE WHEN days_since_prior_order <= 3 THEN '0-3 jours'
       WHEN days_since_prior_order <= 7 THEN '4-7 jours'
       WHEN days_since_prior_order <= 14 THEN '8-14 jours'
       WHEN days_since_prior_order <= 21 THEN '15-21 jours'
       WHEN days_since_prior_order <= 30 THEN '22-30 jours'
       ELSE '30+ jours' END AS interval_bucket,
  COUNT(DISTINCT order_id) AS nb_orders,
  ROUND(100.0 * COUNT(DISTINCT order_id) / SUM(COUNT(DISTINCT order_id)) OVER (), 1) AS pct
FROM stg_orders
WHERE days_since_prior_order IS NOT NULL
GROUP BY 1 ORDER BY MIN(days_since_prior_order);
