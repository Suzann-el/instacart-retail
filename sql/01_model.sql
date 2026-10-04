-- 01_model.sql : modèle analytique
-- Grain de fact_order_lines : une ligne = un produit dans une commande
-- Note : Instacart ne contient PAS de prix — les analyses portent sur
-- les volumes (commandes, produits) et les comportements.

CREATE OR REPLACE TABLE dim_product AS
SELECT p.product_id, p.product_name, a.aisle, d.department,
       a.aisle_id, d.department_id
FROM stg_products p
JOIN stg_aisles a USING (aisle_id)
JOIN stg_departments d USING (department_id);

CREATE OR REPLACE TABLE dim_time AS
SELECT DISTINCT order_dow, order_hour_of_day,
  CASE order_dow WHEN 0 THEN 'Dimanche' WHEN 1 THEN 'Lundi' WHEN 2 THEN 'Mardi'
    WHEN 3 THEN 'Mercredi' WHEN 4 THEN 'Jeudi' WHEN 5 THEN 'Vendredi' ELSE 'Samedi' END AS day_name,
  CASE WHEN order_hour_of_day BETWEEN 6 AND 11 THEN 'Matin'
       WHEN order_hour_of_day BETWEEN 12 AND 17 THEN 'Apres-midi'
       WHEN order_hour_of_day BETWEEN 18 AND 21 THEN 'Soir' ELSE 'Nuit' END AS time_slot
FROM stg_orders;

CREATE OR REPLACE TABLE fact_order_lines AS
WITH all_lines AS (
  SELECT order_id, product_id, add_to_cart_order, reordered, 'prior' AS eval_set
  FROM stg_order_products_prior
  UNION ALL
  SELECT order_id, product_id, add_to_cart_order, reordered, 'train' AS eval_set
  FROM stg_order_products_train)
SELECT l.order_id, l.product_id, l.add_to_cart_order, l.reordered, l.eval_set,
       o.user_id, o.order_number, o.order_dow, o.order_hour_of_day,
       o.days_since_prior_order,
       p.product_name, p.aisle, p.department, p.aisle_id, p.department_id
FROM all_lines l
JOIN stg_orders o USING (order_id)
JOIN dim_product p USING (product_id);

CREATE OR REPLACE TABLE dim_customer AS
SELECT user_id,
       COUNT(DISTINCT order_id) AS total_orders,
       SUM(1) AS total_items,
       AVG(basket_size) AS avg_basket_size,
       MAX(order_number) AS max_order_number,
       AVG(days_since_prior_order) AS avg_days_between_orders,
       AVG(reordered::DOUBLE) AS reorder_rate,
       COUNT(DISTINCT department_id) AS distinct_departments
FROM (
  SELECT o.user_id, o.order_id, o.order_number, o.days_since_prior_order,
         l.reordered, l.department_id,
         COUNT(*) OVER (PARTITION BY o.order_id) AS basket_size
  FROM stg_orders o
  JOIN fact_order_lines l USING (order_id)) sub
GROUP BY user_id;
