-- ============================================================
-- 04_reporting.sql : vues de reporting dans le schema REPORTING
-- Ce sont les equivalents Snowflake de 03_kpis.sql a 06_customer_segments.sql
-- Ces vues sont directement connectables a Power BI via le connecteur Snowflake natif
-- ============================================================

USE WAREHOUSE RETAIL_WH;
USE DATABASE INSTACART_DB;
USE SCHEMA INSTACART_DB.REPORTING;

-- ----------------------------------------------------------------
-- KPI global
-- ----------------------------------------------------------------
CREATE OR REPLACE VIEW REPORTING.V_KPI_GLOBAL AS
SELECT
  COUNT(DISTINCT USER_ID)                         AS TOTAL_CLIENTS,
  COUNT(DISTINCT ORDER_ID)                        AS TOTAL_COMMANDES,
  COUNT(*)                                        AS TOTAL_ARTICLES,
  ROUND(COUNT(*) / COUNT(DISTINCT ORDER_ID), 1)   AS PANIER_MOYEN,
  ROUND(100.0 * AVG(REORDERED::FLOAT), 1)         AS TAUX_REACHAT_PCT,
  ROUND(AVG(DAYS_SINCE_PRIOR_ORDER), 1)           AS JOURS_ENTRE_COMMANDES
FROM ANALYTICS.FACT_ORDER_LINES;

-- ----------------------------------------------------------------
-- Performance par departement
-- Difference DuckDB -> Snowflake : RATIO_TO_REPORT() au lieu de SUM() OVER ()
-- Les deux fonctionnent, RATIO_TO_REPORT est specifique Snowflake
-- ----------------------------------------------------------------
CREATE OR REPLACE VIEW REPORTING.V_DEPT_PERFORMANCE AS
SELECT
  DEPARTMENT,
  COUNT(DISTINCT ORDER_ID)                                AS ORDERS,
  COUNT(*)                                                AS ITEMS_SOLD,
  ROUND(RATIO_TO_REPORT(COUNT(*)) OVER () * 100, 2)       AS SHARE_PCT,
  ROUND(100.0 * AVG(REORDERED::FLOAT), 1)                 AS REORDER_RATE_PCT,
  COUNT(DISTINCT PRODUCT_ID)                              AS DISTINCT_PRODUCTS
FROM ANALYTICS.FACT_ORDER_LINES
GROUP BY DEPARTMENT
ORDER BY ITEMS_SOLD DESC;

-- ----------------------------------------------------------------
-- Top produits
-- ----------------------------------------------------------------
CREATE OR REPLACE VIEW REPORTING.V_TOP_PRODUCTS AS
SELECT
  PRODUCT_NAME, DEPARTMENT, AISLE,
  COUNT(DISTINCT ORDER_ID)                AS ORDERS,
  COUNT(*)                                AS ITEMS_SOLD,
  ROUND(100.0 * AVG(REORDERED::FLOAT), 1) AS REORDER_RATE_PCT,
  COUNT(DISTINCT USER_ID)                 AS UNIQUE_BUYERS
FROM ANALYTICS.FACT_ORDER_LINES
GROUP BY PRODUCT_NAME, DEPARTMENT, AISLE
ORDER BY ITEMS_SOLD DESC
LIMIT 50;

-- ----------------------------------------------------------------
-- Patterns temporels
-- Difference : TO_CHAR() au lieu de CASE WHEN pour le nom du jour
-- ----------------------------------------------------------------
CREATE OR REPLACE VIEW REPORTING.V_TIME_PATTERNS AS
SELECT
  ORDER_HOUR_OF_DAY,
  t.TIME_SLOT,
  COUNT(DISTINCT ORDER_ID)                                AS ORDERS,
  ROUND(COUNT(*) / COUNT(DISTINCT ORDER_ID)::FLOAT, 1)   AS AVG_BASKET_SIZE
FROM ANALYTICS.FACT_ORDER_LINES f
JOIN ANALYTICS.DIM_TIME t USING (ORDER_DOW, ORDER_HOUR_OF_DAY)
GROUP BY ORDER_HOUR_OF_DAY, t.TIME_SLOT
ORDER BY ORDER_HOUR_OF_DAY;

-- ----------------------------------------------------------------
-- Segmentation client
-- Difference : NTILE() identique a DuckDB
-- IFF() = raccourci Snowflake pour CASE WHEN x THEN y ELSE z END
-- ----------------------------------------------------------------
CREATE OR REPLACE VIEW REPORTING.V_CUSTOMER_SEGMENTS AS
WITH SCORED AS (
  SELECT USER_ID, TOTAL_ORDERS, AVG_BASKET_SIZE, REORDER_RATE, AVG_DAYS_BETWEEN_ORDERS,
    NTILE(4) OVER (ORDER BY TOTAL_ORDERS DESC)           AS F_SCORE,
    NTILE(4) OVER (ORDER BY REORDER_RATE DESC)           AS M_SCORE,
    NTILE(4) OVER (ORDER BY AVG_DAYS_BETWEEN_ORDERS ASC NULLS LAST) AS R_SCORE
  FROM ANALYTICS.DIM_CUSTOMER
)
SELECT *,
  CASE
    WHEN F_SCORE = 1 AND M_SCORE = 1              THEN 'Champions'
    WHEN F_SCORE <= 2 AND M_SCORE <= 2
         AND R_SCORE <= 2                         THEN 'Clients fideles'
    WHEN F_SCORE = 1 AND M_SCORE >= 3             THEN 'Acheteurs frequents'
    WHEN F_SCORE >= 3 AND M_SCORE = 1             THEN 'Gros paniers occasionnels'
    WHEN F_SCORE >= 3 AND R_SCORE >= 3            THEN 'Clients a risque'
    ELSE                                               'Clients reguliers'
  END AS SEGMENT
FROM SCORED;

-- Resume des segments (agregat de la vue)
CREATE OR REPLACE VIEW REPORTING.V_SEGMENT_SUMMARY AS
SELECT
  SEGMENT,
  COUNT(*)                                AS NB_CLIENTS,
  ROUND(RATIO_TO_REPORT(COUNT(*)) OVER () * 100, 1) AS PCT_CLIENTS,
  ROUND(AVG(TOTAL_ORDERS), 1)             AS AVG_ORDERS,
  ROUND(AVG(AVG_BASKET_SIZE), 1)          AS AVG_BASKET,
  ROUND(AVG(REORDER_RATE) * 100, 1)       AS AVG_REORDER_PCT,
  ROUND(AVG(AVG_DAYS_BETWEEN_ORDERS), 1)  AS AVG_JOURS
FROM REPORTING.V_CUSTOMER_SEGMENTS
GROUP BY SEGMENT
ORDER BY NB_CLIENTS DESC;

-- ----------------------------------------------------------------
-- Cross-selling (associations de departements)
-- Difference : identique DuckDB - self-join sur ORDER_ID
-- En prod Snowflake on activerait le result cache automatique
-- ----------------------------------------------------------------
CREATE OR REPLACE VIEW REPORTING.V_CROSS_SELLING AS
SELECT
  a.DEPARTMENT AS DEPT_A,
  b.DEPARTMENT AS DEPT_B,
  COUNT(DISTINCT a.ORDER_ID) AS CO_ORDERS,
  ROUND(RATIO_TO_REPORT(COUNT(DISTINCT a.ORDER_ID)) OVER () * 100, 2) AS PCT_PANIERS
FROM ANALYTICS.FACT_ORDER_LINES a
JOIN ANALYTICS.FACT_ORDER_LINES b
  ON a.ORDER_ID = b.ORDER_ID
  AND a.DEPARTMENT < b.DEPARTMENT
GROUP BY DEPT_A, DEPT_B
HAVING COUNT(DISTINCT a.ORDER_ID) >= 1000
ORDER BY CO_ORDERS DESC
LIMIT 20;

-- ----------------------------------------------------------------
-- Retention
-- ----------------------------------------------------------------
CREATE OR REPLACE VIEW REPORTING.V_RETENTION AS
WITH FIRST_ORDER AS (
  SELECT USER_ID, MIN(ORDER_NUMBER) AS FIRST_N
  FROM RAW.STG_ORDERS GROUP BY USER_ID
),
COHORT AS (
  SELECT o.USER_ID, o.ORDER_NUMBER - f.FIRST_N AS SINCE_FIRST
  FROM RAW.STG_ORDERS o JOIN FIRST_ORDER f USING (USER_ID)
)
SELECT
  SINCE_FIRST                     AS COMMANDE_N,
  COUNT(DISTINCT USER_ID)         AS NB_USERS,
  ROUND(100.0 * COUNT(DISTINCT USER_ID) /
    FIRST_VALUE(COUNT(DISTINCT USER_ID)) OVER (ORDER BY SINCE_FIRST
    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING), 1) AS RETENTION_PCT
FROM COHORT
WHERE SINCE_FIRST BETWEEN 0 AND 10
GROUP BY SINCE_FIRST
ORDER BY SINCE_FIRST;

-- Liste de toutes les vues creees
SHOW VIEWS IN SCHEMA INSTACART_DB.REPORTING;
