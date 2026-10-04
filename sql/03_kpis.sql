-- 03_kpis.sql : KPIs opérationnels retail

-- name: kpi_global
SELECT
  COUNT(DISTINCT user_id) AS total_users,
  COUNT(DISTINCT order_id) AS total_orders,
  COUNT(*) AS total_lines,
  ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT order_id), 1) AS avg_basket_size,
  ROUND(100.0 * AVG(reordered::DOUBLE), 1) AS global_reorder_rate_pct,
  ROUND(AVG(days_since_prior_order), 1) AS avg_days_between_orders
FROM fact_order_lines;

-- name: kpi_by_department
SELECT department,
  COUNT(DISTINCT order_id) AS orders,
  COUNT(*) AS items_sold,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS share_of_items_pct,
  ROUND(100.0 * AVG(reordered::DOUBLE), 1) AS reorder_rate_pct,
  COUNT(DISTINCT product_id) AS distinct_products,
  ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT product_id), 1) AS items_per_product
FROM fact_order_lines
GROUP BY department ORDER BY items_sold DESC;

-- name: kpi_by_aisle
SELECT department, aisle,
  COUNT(DISTINCT order_id) AS orders,
  COUNT(*) AS items_sold,
  ROUND(100.0 * AVG(reordered::DOUBLE), 1) AS reorder_rate_pct,
  COUNT(DISTINCT product_id) AS distinct_products
FROM fact_order_lines
GROUP BY department, aisle ORDER BY items_sold DESC;

-- name: kpi_top_products
SELECT product_name, department, aisle,
  COUNT(DISTINCT order_id) AS orders,
  COUNT(*) AS items_sold,
  ROUND(100.0 * AVG(reordered::DOUBLE), 1) AS reorder_rate_pct,
  COUNT(DISTINCT user_id) AS unique_buyers
FROM fact_order_lines
GROUP BY product_name, department, aisle ORDER BY items_sold DESC LIMIT 30;

-- name: kpi_by_dow
SELECT order_dow, day_name,
  COUNT(DISTINCT order_id) AS orders,
  COUNT(*) AS items,
  ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT order_id), 1) AS avg_basket_size
FROM fact_order_lines f
JOIN dim_time t USING (order_dow, order_hour_of_day)
GROUP BY order_dow, day_name ORDER BY order_dow;

-- name: kpi_by_hour
SELECT order_hour_of_day, time_slot,
  COUNT(DISTINCT order_id) AS orders,
  COUNT(*) AS items,
  ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT order_id), 1) AS avg_basket_size
FROM fact_order_lines f
JOIN dim_time t USING (order_dow, order_hour_of_day)
GROUP BY order_hour_of_day, time_slot ORDER BY order_hour_of_day;

-- name: kpi_basket_distribution
SELECT basket_size,
  COUNT(*) AS nb_orders,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_orders
FROM (
  SELECT order_id, COUNT(*) AS basket_size FROM fact_order_lines GROUP BY order_id)
GROUP BY basket_size ORDER BY basket_size;
