CREATE TABLE ACMECO_SALES.STAGING_DATA.stg_sales_pipeline AS
SELECT
    opportunity_id,
    TRIM(sales_agent)                               AS sales_agent,
    TRIM(product)                                   AS product,
    TRIM(account)                                   AS account,

    -- Normalise stage labels
    CASE TRIM(LOWER(deal_stage))
        WHEN 'won'         THEN 'closed_won'
        WHEN 'lost'        THEN 'closed_lost'
        WHEN 'engaging'    THEN 'engaging'
        WHEN 'prospecting' THEN 'prospecting'
        ELSE 'unknown'
    END                                             AS deal_stage,

    -- Cast dates
    TRY_TO_DATE(engage_date, 'YYYY-MM-DD')          AS engage_date,
    TRY_TO_DATE(close_date,  'YYYY-MM-DD')          AS close_date,

    -- Cast close_value — NULL if empty or non-numeric
    TRY_TO_NUMBER(NULLIF(TRIM(close_value), ''))    AS close_value,

    -- is_won and is_lost now reference normalised stage via subquery
    CASE WHEN TRIM(LOWER(deal_stage)) = 'won'
         THEN TRUE ELSE FALSE
    END                                             AS is_won,

    CASE WHEN TRIM(LOWER(deal_stage)) = 'lost'
         THEN TRUE ELSE FALSE
    END                                             AS is_lost,

    -- Deal velocity in days
    DATEDIFF('day',
        TRY_TO_DATE(engage_date, 'YYYY-MM-DD'),
        TRY_TO_DATE(close_date,  'YYYY-MM-DD')
    )                                               AS days_to_close,

    CURRENT_TIMESTAMP()                             AS loaded_at

FROM ACMECO_SALES.RAW_DATA.sales_pipeline
WHERE opportunity_id != 'opportunity_id';


----validation query----data quality checks!!


select deal_stage,
count(*) as total_deals,
sum(close_value) as total_revenue,
round(avg(close_value), 2) as avg_deal_value,
round(avg(days_to_close), 1) as avg_days_to_close,
sum(case when is_won then 1 else 0 end) as won_count,
sum(case when is_lost then 1 else 0 end) as lost_count,
from acmeco_sales.staging_data.stg_sales_pipeline
group by deal_stage
order by total_Deals desc
;


select *
from acmeco_sales.staging_data.stg_sales_pipeline