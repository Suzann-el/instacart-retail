-- 05_assortment.sql : performance de l'assortiment
-- Questions : quels produits sous-performent ? quels rayons sont saturés ?

-- name: assortment_product_performance
SELECT product_name, department, aisle,
  COUNT(DISTINCT user_id) AS unique_buyers,
  COUNT(DISTINCT order_id) AS total_orders,
  COUNT(*) AS total_items,
  ROUND(100.0 * AVG(reordered::DOUBLE), 1) AS reorder_rate_pct,
  ROUND(COUNT(DISTINCT user_id) * 1.0 / (SELECT COUNT(DISTINCT user_id) FROM fact_order_lines) * 100, 2) AS penetration_pct,
  ROUND(1.0 * COUNT(DISTINCT order_id) / COUNT(DISTINCT user_id), 2) AS orders_per_buyer
FROM fact_order_lines
GROUP BY product_name, department, aisle
HAVING COUNT(DISTINCT order_id) >= 20
ORDER BY unique_buyers DESC;

-- name: assortment_long_tail
WITH stats AS (
  SELECT product_id, COUNT(DISTINCT order_id) AS orders
  FROM fact_order_lines GROUP BY product_id),
ranked AS (
  SELECT *, ROW_NUMBER() OVER (ORDER BY orders DESC) AS rk,
         COUNT(*) OVER () AS total_products,
         SUM(orders) OVER () AS total_orders,
         SUM(orders) OVER (ORDER BY orders DESC ROWS UNBOUNDED PRECEDING) AS cum_orders
  FROM stats)
SELECT
  CASE WHEN rk <= total_products * 0.10 THEN 'Top 10% produits'
       WHEN rk <= total_products * 0.30 THEN 'Top 10-30% produits'
       WHEN rk <= total_products * 0.50 THEN 'Top 30-50% produits'
       ELSE 'Longue traîne (50%+)' END AS segment,
  COUNT(*) AS nb_products,
  SUM(orders) AS total_orders,
  ROUND(100.0 * SUM(orders) / MAX(total_orders), 1) AS pct_orders
FROM ranked GROUP BY 1 ORDER BY MIN(rk);

-- name: assortment_by_department_depth
SELECT d.department,
  COUNT(DISTINCT p.product_id) AS nb_products,
  COUNT(DISTINCT a.aisle_id) AS nb_aisles,
  ROUND(COUNT(DISTINCT p.product_id) * 1.0 / COUNT(DISTINCT a.aisle_id), 1) AS products_per_aisle,
  f.total_items,
  ROUND(f.total_items * 1.0 / COUNT(DISTINCT p.product_id), 1) AS items_per_product
FROM stg_departments d
JOIN stg_products p USING (department_id)
JOIN stg_aisles a ON a.aisle_id = p.aisle_id
JOIN (SELECT department, COUNT(*) total_items FROM fact_order_lines GROUP BY 1) f ON f.department = d.department
GROUP BY d.department, f.total_items ORDER BY total_items DESC;

-- name: assortment_cross_selling
SELECT a.department AS dept_a, b.department AS dept_b,
  COUNT(DISTINCT a.order_id) AS co_orders,
  ROUND(100.0 * COUNT(DISTINCT a.order_id) /
    (SELECT COUNT(DISTINCT order_id) FROM fact_order_lines), 2) AS pct_baskets
FROM fact_order_lines a
JOIN fact_order_lines b ON a.order_id = b.order_id AND a.department < b.department
GROUP BY 1, 2
HAVING COUNT(DISTINCT a.order_id) >= 100
ORDER BY co_orders DESC LIMIT 15;
