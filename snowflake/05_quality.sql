-- ============================================================
-- 05_quality.sql : controles qualite et monitoring Snowflake
-- Snowflake ajoute des capacites de monitoring natives : QUERY_HISTORY,
-- INFORMATION_SCHEMA, et les alerts/tasks pour automatiser
-- ============================================================

USE WAREHOUSE RETAIL_WH;
USE DATABASE INSTACART_DB;

-- ----------------------------------------------------------------
-- 1. Controles qualite (memes logiques que DuckDB)
-- ----------------------------------------------------------------
SELECT 'chk_orders_grain_unique' AS controle,
  COUNT(*) - COUNT(DISTINCT ORDER_ID) AS violations
FROM RAW.STG_ORDERS

UNION ALL SELECT 'chk_no_orphan_products',
  COUNT(*) FROM ANALYTICS.FACT_ORDER_LINES WHERE PRODUCT_NAME IS NULL

UNION ALL SELECT 'chk_reordered_binary',
  COUNT(*) FROM ANALYTICS.FACT_ORDER_LINES WHERE REORDERED NOT IN (0, 1)

UNION ALL SELECT 'chk_hour_range',
  COUNT(*) FROM RAW.STG_ORDERS WHERE ORDER_HOUR_OF_DAY NOT BETWEEN 0 AND 23

UNION ALL SELECT 'chk_dow_range',
  COUNT(*) FROM RAW.STG_ORDERS WHERE ORDER_DOW NOT BETWEEN 0 AND 6

UNION ALL SELECT 'chk_products_no_orphan_aisle',
  COUNT(*) FROM RAW.STG_PRODUCTS p
  LEFT JOIN RAW.STG_AISLES a ON a.AISLE_ID = p.AISLE_ID WHERE a.AISLE_ID IS NULL

ORDER BY controle;

-- ----------------------------------------------------------------
-- 2. Monitoring Snowflake (specifique - pas disponible dans DuckDB)
-- Utile a mentionner en entretien : Snowflake trace tout nativement
-- ----------------------------------------------------------------

-- Historique des requetes recentes (derniere heure)
SELECT
  QUERY_TEXT,
  EXECUTION_STATUS,
  TOTAL_ELAPSED_TIME / 1000 AS duree_secondes,
  BYTES_SCANNED / 1e6 AS MB_scannes,
  CREDITS_USED_CLOUD_SERVICES AS credits
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY(
  DATEADD('hour', -1, CURRENT_TIMESTAMP()), CURRENT_TIMESTAMP()))
WHERE EXECUTION_STATUS = 'SUCCESS'
ORDER BY START_TIME DESC
LIMIT 10;

-- Consommation de credits par warehouse
SELECT
  WAREHOUSE_NAME,
  SUM(CREDITS_USED) AS TOTAL_CREDITS,
  SUM(CREDITS_USED_COMPUTE) AS CREDITS_COMPUTE,
  SUM(CREDITS_USED_CLOUD_SERVICES) AS CREDITS_SERVICES
FROM TABLE(INFORMATION_SCHEMA.WAREHOUSE_METERING_HISTORY(
  DATEADD('day', -7, CURRENT_TIMESTAMP()), CURRENT_TIMESTAMP()))
GROUP BY WAREHOUSE_NAME;

-- ----------------------------------------------------------------
-- 3. Optimisation : CLUSTERING et RESULT CACHE
-- Specifique Snowflake - concepts a mentionner en entretien
-- ----------------------------------------------------------------

-- Verifier le clustering de la table de faits
-- En prod, on ajouterait : ALTER TABLE ANALYTICS.FACT_ORDER_LINES CLUSTER BY (DEPARTMENT_ID, ORDER_DOW);
SELECT SYSTEM$CLUSTERING_INFORMATION('ANALYTICS.FACT_ORDER_LINES');

-- Le result cache de Snowflake reutilise automatiquement les resultats
-- des requetes identiques pendant 24h -> les dashboards Power BI
-- beneficient de temps de reponse quasi-instantanes si la donnee n'a pas change
-- Test : executer deux fois la meme requete et comparer les temps
SELECT COUNT(*), AVG(REORDER_RATE) FROM ANALYTICS.DIM_CUSTOMER;
-- La 2e execution sera ~0ms grace au result cache
SELECT COUNT(*), AVG(REORDER_RATE) FROM ANALYTICS.DIM_CUSTOMER;
