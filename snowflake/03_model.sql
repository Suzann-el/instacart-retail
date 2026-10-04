-- ============================================================
-- 03_model.sql : modele analytique dans le schema ANALYTICS
-- Memes transformations que DuckDB 01_model.sql, syntaxe Snowflake
-- ============================================================
-- Differences syntaxiques DuckDB -> Snowflake notees en commentaire

USE WAREHOUSE RETAIL_WH;
USE DATABASE INSTACART_DB;
USE SCHEMA INSTACART_DB.ANALYTICS;

-- ----------------------------------------------------------------
-- Dimension produit
-- Identique a DuckDB (JOIN standard, pas de difference syntaxique)
-- ----------------------------------------------------------------
CREATE OR REPLACE TABLE ANALYTICS.DIM_PRODUCT AS
SELECT
  p.PRODUCT_ID,
  p.PRODUCT_NAME,
  a.AISLE,
  d.DEPARTMENT,
  a.AISLE_ID,
  d.DEPARTMENT_ID
FROM RAW.STG_PRODUCTS p
JOIN RAW.STG_AISLES a ON a.AISLE_ID = p.AISLE_ID
JOIN RAW.STG_DEPARTMENTS d ON d.DEPARTMENT_ID = p.DEPARTMENT_ID;

-- ----------------------------------------------------------------
-- Dimension temps
-- Difference : DECODE() au lieu de CASE WHEN (style Snowflake)
-- Les deux syntaxes fonctionnent dans Snowflake
-- ----------------------------------------------------------------
CREATE OR REPLACE TABLE ANALYTICS.DIM_TIME AS
SELECT DISTINCT
  ORDER_DOW,
  ORDER_HOUR_OF_DAY,
  DECODE(ORDER_DOW, 0,'Dimanche', 1,'Lundi', 2,'Mardi', 3,'Mercredi',
                    4,'Jeudi', 5,'Vendredi', 'Samedi') AS DAY_NAME,
  CASE
    WHEN ORDER_HOUR_OF_DAY BETWEEN 6 AND 11 THEN 'Matin'
    WHEN ORDER_HOUR_OF_DAY BETWEEN 12 AND 17 THEN 'Apres-midi'
    WHEN ORDER_HOUR_OF_DAY BETWEEN 18 AND 21 THEN 'Soir'
    ELSE 'Nuit'
  END AS TIME_SLOT
FROM RAW.STG_ORDERS;

-- ----------------------------------------------------------------
-- Table de faits unifiee (prior + train)
-- Difference : UNION ALL identique, pas de difference syntaxique
-- En Snowflake on peut aussi utiliser CLUSTER BY pour optimiser
-- les performances sur les grandes tables
-- ----------------------------------------------------------------
CREATE OR REPLACE TABLE ANALYTICS.FACT_ORDER_LINES
-- CLUSTER BY (DEPARTMENT_ID, ORDER_DOW)  -- a activer en prod pour ameliorer les perfs
AS
WITH ALL_LINES AS (
  SELECT ORDER_ID, PRODUCT_ID, ADD_TO_CART_ORDER, REORDERED, 'prior' AS EVAL_SET
  FROM RAW.STG_ORDER_PRODUCTS_PRIOR
  UNION ALL
  SELECT ORDER_ID, PRODUCT_ID, ADD_TO_CART_ORDER, REORDERED, 'train' AS EVAL_SET
  FROM RAW.STG_ORDER_PRODUCTS_TRAIN
)
SELECT
  l.ORDER_ID, l.PRODUCT_ID, l.ADD_TO_CART_ORDER, l.REORDERED, l.EVAL_SET,
  o.USER_ID, o.ORDER_NUMBER, o.ORDER_DOW, o.ORDER_HOUR_OF_DAY,
  o.DAYS_SINCE_PRIOR_ORDER,
  p.PRODUCT_NAME, p.AISLE, p.DEPARTMENT, p.AISLE_ID, p.DEPARTMENT_ID
FROM ALL_LINES l
JOIN RAW.STG_ORDERS o ON o.ORDER_ID = l.ORDER_ID
JOIN ANALYTICS.DIM_PRODUCT p ON p.PRODUCT_ID = l.PRODUCT_ID;

-- ----------------------------------------------------------------
-- Agregats client
-- Difference : identique a DuckDB, les fonctions fenetres sont les memes
-- ----------------------------------------------------------------
CREATE OR REPLACE TABLE ANALYTICS.DIM_CUSTOMER AS
SELECT
  USER_ID,
  COUNT(DISTINCT ORDER_ID)                    AS TOTAL_ORDERS,
  SUM(1)                                      AS TOTAL_ITEMS,
  AVG(BASKET_SIZE)                            AS AVG_BASKET_SIZE,
  MAX(ORDER_NUMBER)                           AS MAX_ORDER_NUMBER,
  AVG(DAYS_SINCE_PRIOR_ORDER)                 AS AVG_DAYS_BETWEEN_ORDERS,
  AVG(REORDERED::FLOAT)                       AS REORDER_RATE,
  COUNT(DISTINCT DEPARTMENT_ID)               AS DISTINCT_DEPARTMENTS
FROM (
  SELECT
    o.USER_ID, o.ORDER_ID, o.ORDER_NUMBER, o.DAYS_SINCE_PRIOR_ORDER,
    l.REORDERED, l.DEPARTMENT_ID,
    COUNT(*) OVER (PARTITION BY o.ORDER_ID) AS BASKET_SIZE
  FROM RAW.STG_ORDERS o
  JOIN ANALYTICS.FACT_ORDER_LINES l ON l.ORDER_ID = o.ORDER_ID
) sub
GROUP BY USER_ID;

-- Verification
SELECT 'FACT_ORDER_LINES' tbl, COUNT(*) n FROM ANALYTICS.FACT_ORDER_LINES UNION ALL
SELECT 'DIM_PRODUCT', COUNT(*) FROM ANALYTICS.DIM_PRODUCT UNION ALL
SELECT 'DIM_CUSTOMER', COUNT(*) FROM ANALYTICS.DIM_CUSTOMER UNION ALL
SELECT 'DIM_TIME', COUNT(*) FROM ANALYTICS.DIM_TIME
ORDER BY tbl;
