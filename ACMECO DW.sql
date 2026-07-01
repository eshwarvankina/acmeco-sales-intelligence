--================================================================
-- ACMECO SALES INTELLIGENCE PLATFORM
-- Environment setup
-- ================================================================

CREATE WAREHOUSE IF NOT EXISTS ACMECO_DW
    WAREHOUSE_SIZE = 'X-SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
;
-- DATABASE CREATTION - ACMECO_DB
CREATE DATABASE IF NOT EXISTS ACMECO_SALES
COMMENT = 'AcmeCo Sales Intelligence Platform - single source of truth';

USE DATABASE ACMECO_SALES;

CREATE SCHEMA IF NOT EXISTS RAW 
COMMENT = 'Landed data, raw, untouched, immutable';

CREATE SCHEMA IF NOT EXISTS STAGING 
COMMENT = 'cleaned business data - no business logic - Dq validated';

CREATE SCHEMA IF NOT EXISTS ANALYTICS
COMMENT = 'business ready layer - connected to tablaue for dashboard';

SHOW WAREHOUSES LIKE 'ACMECO_WH';
SHOW SCHEMAS IN DATABASE ACMECO_SALES;




