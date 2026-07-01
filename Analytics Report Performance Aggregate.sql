-- ================================================================
-- ANALYTICS: rep_performance_agg
-- Purpose: Rep level performance metrics with dynamic thresholds
-- Source: ANALYTICS_DATA.sales_fact
-- Key decisions:
--   1. Closing speed thresholds derived from p25/p75/p90
--      distribution — no hardcoded numbers
--   2. Open pipeline value estimated from product list price
--      since source data has no value for open deals
--   3. Mean days separated from percentile thresholds
--      for single responsibility per CTE
-- ================================================================

DROP TABLE IF EXISTS ACMECO_SALES.ANALYTICS_DATA.rep_performance_agg;

CREATE TABLE ACMECO_SALES.ANALYTICS_DATA.rep_performance_agg AS

-- ----------------------------------------------------------------
-- CTE 1: Rep level base aggregations
-- One row per rep with all raw metrics computed
-- ----------------------------------------------------------------
WITH rep_base AS (
    SELECT
        sales_agent,
        manager,
        regional_office,

        -- Volume
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

        -- Revenue from closed won deals only
        SUM(CASE WHEN is_won
                 THEN close_value ELSE 0 END)           AS total_revenue,

        -- AOV on won deals
        ROUND(AVG(
            CASE WHEN is_won THEN close_value END)
        , 0)                                            AS avg_order_value,

        -- Deal velocity on won deals only
        ROUND(AVG(
            CASE WHEN is_won THEN days_to_close END)
        , 1)                                            AS avg_days_to_close,

        -- Open pipeline value using product list price
        -- Rationale: close_value is NULL for open deals in source data
        -- list_price from products table is the best available estimate
        SUM(CASE WHEN is_won = FALSE
                 AND is_lost = FALSE
                 THEN list_price ELSE 0 END)            AS open_pipeline_value

    FROM ACMECO_SALES.ANALYTICS_DATA.sales_fact
    GROUP BY sales_agent, manager, regional_office
),

-- ----------------------------------------------------------------
-- CTE 2: Percentile thresholds for closing speed classification
-- Computed from actual rep distribution — no hardcoded values
-- p25 = faster than 75% of reps
-- p75 = faster than 25% of reps
-- p90 = slowest 10% of reps threshold
-- ----------------------------------------------------------------
thresholds AS (
    SELECT
        ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP
            (ORDER BY avg_days_to_close), 1)            AS p25,
        ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP
            (ORDER BY avg_days_to_close), 1)            AS p75,
        ROUND(PERCENTILE_CONT(0.90) WITHIN GROUP
            (ORDER BY avg_days_to_close), 1)            AS p90
    FROM rep_base
    WHERE avg_days_to_close IS NOT NULL
),

-- ----------------------------------------------------------------
-- CTE 3: Win rate thresholds for G4G classification
-- p75 = top performers (Green)
-- p50 = median performers (Yellow)
-- below p50 = underperforming (Red)
-- ----------------------------------------------------------------
win_rate_stats AS (
    SELECT
        ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP
            (ORDER BY win_rate_pct), 1)                 AS p75_win_rate,
        ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP
            (ORDER BY win_rate_pct), 1)                 AS p50_win_rate,
        ROUND(AVG(win_rate_pct), 1)                     AS mean_win_rate
    FROM rep_base
    WHERE win_rate_pct IS NOT NULL
),

-- ----------------------------------------------------------------
-- CTE 4: Mean days — reference value for Tableau visualisation
-- Separated from thresholds CTE for single responsibility
-- Not used in CASE logic — purely a reference line for charts
-- ----------------------------------------------------------------
mean_stats AS (
    SELECT
        ROUND(AVG(avg_days_to_close), 1)                AS mean_days
    FROM rep_base
    WHERE avg_days_to_close IS NOT NULL
)

-- ----------------------------------------------------------------
-- Final SELECT: Join all CTEs and apply business logic
-- ----------------------------------------------------------------
SELECT
    r.sales_agent,
    r.manager,
    r.regional_office,

    -- Volume metrics
    r.total_deals,
    r.won_deals,
    r.lost_deals,
    r.open_deals,

    -- Performance metrics
    r.win_rate_pct,
    r.total_revenue,
    r.avg_order_value,
    r.avg_days_to_close,

    -- Pipeline
    r.open_pipeline_value,

    -- Expose thresholds as columns for Tableau reference lines
    t.p25                                               AS threshold_fast_closer,
    t.p75                                               AS threshold_slow_closer,
    t.p90                                               AS threshold_needs_coaching,
    m.mean_days                                         AS threshold_mean_days,

-- G4G status — fully dynamic using p50/p75 win rate distribution
CASE
    WHEN r.win_rate_pct >= w.p75_win_rate
        THEN 'Green'
        -- top 25% of reps by win rate

    WHEN r.win_rate_pct >= w.p50_win_rate
        THEN 'Yellow'
        -- middle 25% to 75% of reps

    ELSE 'Red'
        -- bottom 50% of reps by win rate
END                                                     AS g4g_status,

    -- Closing speed — fully dynamic using p25/p75/p90
    CASE
        WHEN r.avg_days_to_close IS NULL
            THEN 'No Closed Deals'

        WHEN r.avg_days_to_close < t.p25
            THEN 'Fast Closer'
            -- below p25 — faster than 75% of all reps

        WHEN r.avg_days_to_close BETWEEN t.p25 AND t.p75
            THEN 'Average'
            -- between p25 and p75 — middle 50% of reps

        WHEN r.avg_days_to_close BETWEEN t.p75 AND t.p90
            THEN 'Slow Closer'
            -- above p75 but not in bottom 10%

        ELSE 'Needs Coaching'
            -- above p90 — slowest 10% of reps
    END                                                 AS closing_speed,

    CURRENT_TIMESTAMP()                                 AS loaded_at

FROM rep_base        r
CROSS JOIN thresholds t
CROSS JOIN mean_stats m
Cross join win_rate_stats w
ORDER BY r.total_revenue DESC;

select *
from ACMECO_SALES.ANALYTICS_DATA.rep_performance_agg
