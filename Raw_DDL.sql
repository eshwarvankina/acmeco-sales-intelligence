CREATE TABLE ACMECO_SALES.RAW_DATA.sales_pipeline (
    opportunity_id   VARCHAR(50),
    sales_agent      VARCHAR(100),
    product          VARCHAR(100),
    account          VARCHAR(100),
    deal_stage       VARCHAR(50),
    engage_date      VARCHAR(20),
    close_date       VARCHAR(20),
    close_value      VARCHAR(20)
);

CREATE TABLE ACMECO_SALES.RAW_DATA.accounts (
    account          VARCHAR(100),
    sector           VARCHAR(100),
    year_established VARCHAR(10),
    revenue          VARCHAR(50),
    employees        VARCHAR(20),
    office_location  VARCHAR(100),
    subsidiary_of    VARCHAR(100)
);

CREATE TABLE ACMECO_SALES.RAW_DATA.products (
    product          VARCHAR(100),
    series           VARCHAR(100),
    sales_price      VARCHAR(20)
);

CREATE TABLE ACMECO_SALES.RAW_DATA.sales_teams (
    sales_agent      VARCHAR(100),
    manager          VARCHAR(100),
    regional_office  VARCHAR(100)
);

--making sure tables are created under ACMECO_SALES schema
SHOW TABLES IN SCHEMA ACMECO_SALES.RAW_DATA;