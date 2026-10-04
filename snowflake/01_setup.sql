-- ============================================================
-- 01_setup.sql : initialisation de l'environnement Snowflake
-- A executer UNE SEULE FOIS, en tant qu'ACCOUNTADMIN
-- ============================================================

-- 1. Warehouse (puissance de calcul)
-- X-SMALL suffit largement pour ce projet (consomme 1 credit/heure)
-- AUTO_SUSPEND = s'eteint apres 60s d'inactivite -> economise les credits
CREATE WAREHOUSE IF NOT EXISTS RETAIL_WH
  WAREHOUSE_SIZE = 'X-SMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  COMMENT = 'Warehouse projet Instacart retail analytics';

-- 2. Database et schemas
CREATE DATABASE IF NOT EXISTS INSTACART_DB
  COMMENT = 'Analyse operationnelle retail - Instacart Market Basket Analysis';

CREATE SCHEMA IF NOT EXISTS INSTACART_DB.RAW
  COMMENT = 'Donnees brutes chargees depuis les CSV';

CREATE SCHEMA IF NOT EXISTS INSTACART_DB.ANALYTICS
  COMMENT = 'Modele analytique : tables de faits et dimensions';

CREATE SCHEMA IF NOT EXISTS INSTACART_DB.REPORTING
  COMMENT = 'Vues et agregats pour Power BI et les equipes metier';

-- 3. Contexte de travail
USE WAREHOUSE RETAIL_WH;
USE DATABASE INSTACART_DB;
USE SCHEMA INSTACART_DB.RAW;

-- Verification
SHOW WAREHOUSES LIKE 'RETAIL_WH';
SHOW SCHEMAS IN DATABASE INSTACART_DB;
