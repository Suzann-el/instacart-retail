-- ============================================================
-- 02_staging.sql : chargement des CSV Instacart dans Snowflake
-- via un INTERNAL STAGE (upload depuis ma machine locale)
-- ============================================================
-- Difference cle avec DuckDB :
--   DuckDB lit directement les CSV avec read_csv()
--   Snowflake utilise un STAGE comme zone de transit, puis COPY INTO
--   En production : le stage serait externe (S3, Azure Blob, GCS)
--   Ici : stage interne pour le trial (upload via Snowsight ou SnowSQL)

USE WAREHOUSE RETAIL_WH;
USE DATABASE INSTACART_DB;
USE SCHEMA INSTACART_DB.RAW;

-- ----------------------------------------------------------------
-- 1. Creer un stage interne pour uploader les CSV
-- ----------------------------------------------------------------
CREATE STAGE IF NOT EXISTS INSTACART_STAGE
  FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"'
                 SKIP_HEADER = 1 NULL_IF = ('', 'NULL') EMPTY_FIELD_AS_NULL = TRUE)
  COMMENT = 'Zone de transit pour les CSV Instacart';

-- Pour uploader depuis ma machine (dans SnowSQL ou via Snowsight > Data > Stages) :
-- PUT file://C:/Users/asus/Desktop/instacart-retail/data/raw/orders.csv @INSTACART_STAGE;
-- PUT file://C:/Users/asus/Desktop/instacart-retail/data/raw/order_products__prior.csv @INSTACART_STAGE;
-- PUT file://C:/Users/asus/Desktop/instacart-retail/data/raw/order_products__train.csv @INSTACART_STAGE;
-- PUT file://C:/Users/asus/Desktop/instacart-retail/data/raw/products.csv @INSTACART_STAGE;
-- PUT file://C:/Users/asus/Desktop/instacart-retail/data/raw/aisles.csv @INSTACART_STAGE;
-- PUT file://C:/Users/asus/Desktop/instacart-retail/data/raw/departments.csv @INSTACART_STAGE;

-- Verifier que les fichiers sont bien uploades
LIST @INSTACART_STAGE;

-- ----------------------------------------------------------------
-- 2. Tables de staging (schema brut, types stricts)
-- ----------------------------------------------------------------
CREATE OR REPLACE TABLE RAW.STG_ORDERS (
  ORDER_ID        INTEGER       NOT NULL,
  USER_ID         INTEGER       NOT NULL,
  EVAL_SET        VARCHAR(10)   NOT NULL,
  ORDER_NUMBER    INTEGER       NOT NULL,
  ORDER_DOW       INTEGER       NOT NULL,   -- 0=dimanche, 6=samedi
  ORDER_HOUR_OF_DAY INTEGER     NOT NULL,
  DAYS_SINCE_PRIOR_ORDER FLOAT           -- NULL pour la 1ere commande
);

CREATE OR REPLACE TABLE RAW.STG_ORDER_PRODUCTS_PRIOR (
  ORDER_ID            INTEGER NOT NULL,
  PRODUCT_ID          INTEGER NOT NULL,
  ADD_TO_CART_ORDER   INTEGER NOT NULL,
  REORDERED           INTEGER NOT NULL    -- 0 ou 1
);

CREATE OR REPLACE TABLE RAW.STG_ORDER_PRODUCTS_TRAIN (
  ORDER_ID            INTEGER NOT NULL,
  PRODUCT_ID          INTEGER NOT NULL,
  ADD_TO_CART_ORDER   INTEGER NOT NULL,
  REORDERED           INTEGER NOT NULL
);

CREATE OR REPLACE TABLE RAW.STG_PRODUCTS (
  PRODUCT_ID      INTEGER     NOT NULL,
  PRODUCT_NAME    VARCHAR(500) NOT NULL,
  AISLE_ID        INTEGER     NOT NULL,
  DEPARTMENT_ID   INTEGER     NOT NULL
);

CREATE OR REPLACE TABLE RAW.STG_AISLES (
  AISLE_ID    INTEGER     NOT NULL,
  AISLE       VARCHAR(100) NOT NULL
);

CREATE OR REPLACE TABLE RAW.STG_DEPARTMENTS (
  DEPARTMENT_ID   INTEGER     NOT NULL,
  DEPARTMENT      VARCHAR(100) NOT NULL
);

-- ----------------------------------------------------------------
-- 3. Chargement des CSV avec COPY INTO
-- Difference DuckDB -> Snowflake :
--   DuckDB : SELECT * FROM read_csv('fichier.csv', ...)
--   Snowflake : COPY INTO table FROM @stage/fichier
-- ----------------------------------------------------------------
COPY INTO RAW.STG_ORDERS
FROM @INSTACART_STAGE/orders.csv.gz
ON_ERROR = 'CONTINUE';

COPY INTO RAW.STG_ORDER_PRODUCTS_PRIOR
FROM @INSTACART_STAGE/order_products__prior.csv.gz
ON_ERROR = 'CONTINUE';

COPY INTO RAW.STG_ORDER_PRODUCTS_TRAIN
FROM @INSTACART_STAGE/order_products__train.csv.gz
ON_ERROR = 'CONTINUE';

COPY INTO RAW.STG_PRODUCTS
FROM @INSTACART_STAGE/products.csv.gz
ON_ERROR = 'CONTINUE';

COPY INTO RAW.STG_AISLES
FROM @INSTACART_STAGE/aisles.csv.gz
ON_ERROR = 'CONTINUE';

COPY INTO RAW.STG_DEPARTMENTS
FROM @INSTACART_STAGE/departments.csv.gz
ON_ERROR = 'CONTINUE';

-- Verification des lignes chargees
SELECT 'STG_ORDERS' tbl, COUNT(*) n FROM RAW.STG_ORDERS UNION ALL
SELECT 'STG_ORDER_PRODUCTS_PRIOR', COUNT(*) FROM RAW.STG_ORDER_PRODUCTS_PRIOR UNION ALL
SELECT 'STG_ORDER_PRODUCTS_TRAIN', COUNT(*) FROM RAW.STG_ORDER_PRODUCTS_TRAIN UNION ALL
SELECT 'STG_PRODUCTS', COUNT(*) FROM RAW.STG_PRODUCTS UNION ALL
SELECT 'STG_AISLES', COUNT(*) FROM RAW.STG_AISLES UNION ALL
SELECT 'STG_DEPARTMENTS', COUNT(*) FROM RAW.STG_DEPARTMENTS
ORDER BY tbl;
