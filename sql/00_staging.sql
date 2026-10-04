-- 00_staging.sql : chargement brut des CSV Instacart
-- Schéma : https://www.kaggle.com/c/instacart-market-basket-analysis/data
-- ${RAW_DIR} est remplacé par le chemin réel au moment de l'exécution

CREATE OR REPLACE TABLE stg_orders AS
SELECT * FROM read_csv('${RAW_DIR}/orders.csv', header=true, nullstr='',
  columns={
    'order_id':'INTEGER','user_id':'INTEGER','eval_set':'VARCHAR',
    'order_number':'INTEGER','order_dow':'INTEGER','order_hour_of_day':'INTEGER',
    'days_since_prior_order':'DOUBLE'
  });

CREATE OR REPLACE TABLE stg_order_products_prior AS
SELECT * FROM read_csv('${RAW_DIR}/order_products__prior.csv', header=true,
  columns={'order_id':'INTEGER','product_id':'INTEGER','add_to_cart_order':'INTEGER','reordered':'INTEGER'});

CREATE OR REPLACE TABLE stg_order_products_train AS
SELECT * FROM read_csv('${RAW_DIR}/order_products__train.csv', header=true,
  columns={'order_id':'INTEGER','product_id':'INTEGER','add_to_cart_order':'INTEGER','reordered':'INTEGER'});

CREATE OR REPLACE TABLE stg_products AS
SELECT * FROM read_csv('${RAW_DIR}/products.csv', header=true,
  columns={'product_id':'INTEGER','product_name':'VARCHAR','aisle_id':'INTEGER','department_id':'INTEGER'});

CREATE OR REPLACE TABLE stg_aisles AS
SELECT * FROM read_csv('${RAW_DIR}/aisles.csv', header=true,
  columns={'aisle_id':'INTEGER','aisle':'VARCHAR'});

CREATE OR REPLACE TABLE stg_departments AS
SELECT * FROM read_csv('${RAW_DIR}/departments.csv', header=true,
  columns={'department_id':'INTEGER','department':'VARCHAR'});
