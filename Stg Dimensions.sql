-- ================================================================
-- STAGING: Dimension tables
-- Sources: RAW_DATA.accounts, RAW_DATA.products, RAW_DATA.sales_teams
-- Transforms: type casting, trimming, header row filtering
-- Run order: after stg_sales_pipeline.sql
-- ================================================================

-- ----------------------------------------------------------------
-- 1. Accounts
-- ----------------------------------------------------------------
CREATE TABLE ACMECO_SALES.STAGING_DATA.stg_accounts AS
SELECT
    TRIM(account)                               AS account,
    TRIM(sector)                                AS sector,
    TRY_TO_NUMBER(year_established)             AS year_established,
    TRIM(revenue)                               AS revenue,
    TRY_TO_NUMBER(NULLIF(TRIM(employees), ''))  AS employees,
    TRIM(office_location)                       AS office_location,
    TRIM(subsidiary_of)                         AS subsidiary_of,
    CURRENT_TIMESTAMP()                         AS loaded_at
FROM ACMECO_SALES.RAW_DATA.accounts
WHERE account != 'account';

-- ----------------------------------------------------------------
-- 2. Products
-- ----------------------------------------------------------------
CREATE TABLE ACMECO_SALES.STAGING_DATA.stg_products AS
SELECT
    TRIM(product)                                   AS product,
    TRIM(series)                                    AS series,
    TRY_TO_NUMBER(NULLIF(TRIM(sales_price), ''))    AS sales_price,
    CURRENT_TIMESTAMP()                             AS loaded_at
FROM ACMECO_SALES.RAW_DATA.products
WHERE product != 'product';

-- ----------------------------------------------------------------
-- 3. Sales teams
-- ----------------------------------------------------------------
CREATE TABLE ACMECO_SALES.STAGING_DATA.stg_sales_teams AS
SELECT
    TRIM(sales_agent)       AS sales_agent,
    TRIM(manager)           AS manager,
    TRIM(regional_office)   AS regional_office,
    CURRENT_TIMESTAMP()     AS loaded_at
FROM ACMECO_SALES.RAW_DATA.sales_teams
WHERE sales_agent != 'sales_agent';

-- ----------------------------------------------------------------
-- VALIDATION: run after every load
-- ----------------------------------------------------------------
SELECT 'stg_accounts'     AS table_name, 
COUNT(*) AS number_of_rows 
FROM ACMECO_SALES.STAGING_DATA.stg_accounts
UNION ALL
SELECT 'stg_products',    COUNT(*) 
FROM ACMECO_SALES.STAGING_DATA.stg_products
UNION ALL
SELECT 'stg_sales_teams', COUNT(*) 
FROM ACMECO_SALES.STAGING_DATA.stg_sales_teams;