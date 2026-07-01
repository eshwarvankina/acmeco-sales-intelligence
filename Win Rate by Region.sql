-- ================================================================
-- ANALYTICS: Win rate by region and manager
-- Purpose: Executive view — revenue, win rate, deal velocity
--          broken down by regional office and sales manager
-- Connects to: ANALYTICS.sales_fact
-- ================================================================

select 
    regional_office,
    manager,
    count(*) as total_deals,
    sum(case when is_won then 1 else 0 end) as won_deals,
    round(sum(case when is_won then 1 else 0 end) *100
    / nullif(count(*),0)
    ,1) as win_rate_pct,
    to_char(sum(close_value), '$999,999,999') as total_revenue,
    to_char(round(avg(
        case when is_won then close_value end), 0), '$999,999') as_won_deal_value,
    round(avg(case when is_won then days_to_close end), 1) avg_days_to_close
from acmeco_sales.analytics_data.sales_fact
group by regional_office, manager
order by total_revenue desc
;


--Business Insight--
-- Rocco Neubert (East) has the highest win rate at 52.1% and highest average deal value at $2,837 — best quality pipeline, closes faster than average.
-- Melvin Marxen (Central) generates the most revenue at $2.25M through volume — most total deals despite a lower win rate of 45.7%.
-- Dustin Brinkmann (Central) has the lowest average deal value at $1,465 — significantly below everyone else. Either targeting smaller accounts or discounting heavily.
-- Days to close is remarkably consistent across all managers — 49 to 54 days. No one manager is significantly faster or slower.