-- 02_quality.sql : contrôles qualité — chaque requête nommée retourne 0 si OK

-- name: chk_orders_grain_unique
SELECT COUNT(*) - COUNT(DISTINCT order_id) AS violations FROM stg_orders;

-- name: chk_fact_lines_no_orphan_orders
SELECT COUNT(*) AS violations FROM fact_order_lines WHERE user_id IS NULL;

-- name: chk_fact_lines_no_orphan_products
SELECT COUNT(*) AS violations FROM fact_order_lines WHERE product_name IS NULL;

-- name: chk_add_to_cart_order_positive
SELECT COUNT(*) AS violations FROM fact_order_lines WHERE add_to_cart_order <= 0;

-- name: chk_reordered_binary
SELECT COUNT(*) AS violations FROM fact_order_lines WHERE reordered NOT IN (0, 1);

-- name: chk_order_hour_range
SELECT COUNT(*) AS violations FROM stg_orders WHERE order_hour_of_day NOT BETWEEN 0 AND 23;

-- name: chk_order_dow_range
SELECT COUNT(*) AS violations FROM stg_orders WHERE order_dow NOT BETWEEN 0 AND 6;

-- name: chk_products_no_orphan_aisle
SELECT COUNT(*) AS violations FROM stg_products p
LEFT JOIN stg_aisles a USING (aisle_id) WHERE a.aisle_id IS NULL;

-- name: chk_products_no_orphan_dept
SELECT COUNT(*) AS violations FROM stg_products p
LEFT JOIN stg_departments d USING (department_id) WHERE d.department_id IS NULL;

-- name: info_dataset_summary
SELECT 'orders' entity, COUNT(*) n FROM stg_orders UNION ALL
SELECT 'users', COUNT(DISTINCT user_id) FROM stg_orders UNION ALL
SELECT 'products', COUNT(*) FROM stg_products UNION ALL
SELECT 'order_lines', COUNT(*) FROM fact_order_lines UNION ALL
SELECT 'departments', COUNT(*) FROM stg_departments UNION ALL
SELECT 'aisles', COUNT(*) FROM stg_aisles ORDER BY entity;
