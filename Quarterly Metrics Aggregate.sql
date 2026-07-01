
-- ================================================================
-- ANALYTICS: quarterly_metrics_agg
-- Purpose: Quarter level revenue, pipeline and win rate trends
-- Used in: Tableau Dashboard 1 — CRO View (trend charts)
-- ================================================================
CREATE TABLE ACMECO_SALES.ANALYTICS_DATA.quarterly_metrics_agg AS
SELECT
    deal_close_quarter,
    regional_office,

    -- Volume metrics
    COUNT(*)                                        AS total_deals,
    SUM(CASE WHEN is_won  THEN 1 ELSE 0 END)        AS won_deals,
    SUM(CASE WHEN is_lost THEN 1 ELSE 0 END)        AS lost_deals,
    COUNT(*) -
        SUM(CASE WHEN is_won  THEN 1 ELSE 0 END) -
        SUM(CASE WHEN is_lost THEN 1 ELSE 0 END)    AS open_deals,

    -- Win rate
    ROUND(
        SUM(CASE WHEN is_won THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0)
    , 1)                                            AS win_rate_pct,

    -- Revenue metrics
    SUM(CASE WHEN is_won
             THEN close_value ELSE 0 END)           AS total_revenue,

    -- Pipegen — all deals created regardless of outcome
    SUM(close_value)                                AS total_pipeline_value,

    -- AOV — average order value on won deals only
    ROUND(AVG(
        CASE WHEN is_won THEN close_value END)
    , 0)                                            AS avg_order_value,

    -- Deal velocity
    ROUND(AVG(
        CASE WHEN is_won THEN days_to_close END)
    , 1)                                            AS avg_days_to_close_won,

    -- Deal size distribution 
    SUM(CASE WHEN deal_size_category = 'Large'
             THEN 1 ELSE 0 END)                     AS large_deals,
    SUM(CASE WHEN deal_size_category = 'Medium'
             THEN 1 ELSE 0 END)                     AS medium_deals,
    SUM(CASE WHEN deal_size_category = 'Small'
             THEN 1 ELSE 0 END)                     AS small_deals,

    CURRENT_TIMESTAMP()                             AS loaded_at

FROM ACMECO_SALES.ANALYTICS_DATA.sales_fact
WHERE deal_close_quarter IS NOT NULL
GROUP BY deal_close_quarter, regional_office
ORDER BY deal_close_quarter, regional_office;
