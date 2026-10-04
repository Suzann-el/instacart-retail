-- 06_customer_segments.sql : segmentation client comportementale
-- Segmentation basée sur la fréquence et la fidélité (proxy RFM sans montant ni date réelle)

-- name: customer_segments_rfm_proxy
WITH scored AS (
  SELECT user_id, total_orders, avg_basket_size, reorder_rate, avg_days_between_orders,
    NTILE(4) OVER (ORDER BY total_orders DESC) AS f_score,
    NTILE(4) OVER (ORDER BY reorder_rate DESC) AS m_score,
    NTILE(4) OVER (ORDER BY avg_days_between_orders ASC NULLS LAST) AS r_score
  FROM dim_customer)
SELECT *,
  CASE
    WHEN f_score = 1 AND m_score = 1 THEN 'Champions'
    WHEN f_score <= 2 AND m_score <= 2 AND r_score <= 2 THEN 'Clients fidèles'
    WHEN f_score = 1 AND m_score >= 3 THEN 'Acheteurs fréquents peu engagés'
    WHEN f_score >= 3 AND m_score = 1 THEN 'Gros paniers occasionnels'
    WHEN f_score >= 3 AND r_score >= 3 THEN 'Clients à risque'
    ELSE 'Clients réguliers' END AS segment
FROM scored;

-- name: customer_segment_summary
WITH segs AS (
  SELECT user_id, total_orders, avg_basket_size, reorder_rate, avg_days_between_orders, distinct_departments,
    NTILE(4) OVER (ORDER BY total_orders DESC) f_score,
    NTILE(4) OVER (ORDER BY reorder_rate DESC) m_score,
    NTILE(4) OVER (ORDER BY avg_days_between_orders ASC NULLS LAST) r_score
  FROM dim_customer)
SELECT
  CASE WHEN f_score=1 AND m_score=1 THEN 'Champions'
       WHEN f_score<=2 AND m_score<=2 AND r_score<=2 THEN 'Clients fideles'
       WHEN f_score=1 AND m_score>=3 THEN 'Acheteurs frequents peu engages'
       WHEN f_score>=3 AND m_score=1 THEN 'Gros paniers occasionnels'
       WHEN f_score>=3 AND r_score>=3 THEN 'Clients a risque'
       ELSE 'Clients reguliers' END AS segment,
  COUNT(*) AS nb_clients,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_clients,
  ROUND(AVG(total_orders), 1) AS avg_orders,
  ROUND(AVG(avg_basket_size), 1) AS avg_basket,
  ROUND(AVG(reorder_rate) * 100, 1) AS avg_reorder_rate_pct,
  ROUND(AVG(avg_days_between_orders), 1) AS avg_days_between_orders,
  ROUND(AVG(distinct_departments), 1) AS avg_departments
FROM segs GROUP BY 1 ORDER BY nb_clients DESC;

-- name: customer_cohort_retention
WITH first_order AS (
  SELECT user_id, MIN(order_number) AS first_num FROM stg_orders GROUP BY user_id),
cohorts AS (
  SELECT o.user_id,
    CASE WHEN f.first_num = 1 THEN 'Nouveau' ELSE 'Existant' END AS cohort,
    o.order_number - f.first_num AS order_since_first
  FROM stg_orders o JOIN first_order f USING (user_id))
SELECT order_since_first AS commande_n,
  COUNT(DISTINCT user_id) AS nb_users,
  ROUND(100.0 * COUNT(DISTINCT user_id) /
    FIRST_VALUE(COUNT(DISTINCT user_id)) OVER (ORDER BY order_since_first
    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING), 1) AS retention_pct
FROM cohorts WHERE order_since_first <= 10
GROUP BY 1 ORDER BY 1;
