    -- Check row counts for all four tables
SELECT 'sales_pipeline' AS table_name, COUNT(*) AS row_count 
FROM ACMECO_SALES.RAW_DATA.sales_pipeline

UNION ALL

SELECT 'accounts', COUNT(*) 
FROM ACMECO_SALES.RAW_DATA.accounts

UNION ALL

SELECT 'products', COUNT(*) 
FROM ACMECO_SALES.RAW_DATA.products

UNION ALL

SELECT 'sales_teams', COUNT(*) 
FROM ACMECO_SALES.RAW_DATA.sales_teams;


select *
from acmeco_sales.raw_data.sales_pipeline
;


select deal_stage, count(*) as count
from acmeco_sales.raw_data.sales_pipeline
group by deal_stage
order by count desc
;
-- got deal_stage --> header counted

SELECT * FROM ACMECO_SALES.RAW_DATA.acounts
WHERE sales_agent = 'sales_agent';

delete from acmeco_sales.raw_data.sales_teams
where sales_agent = 'sales_agent'



