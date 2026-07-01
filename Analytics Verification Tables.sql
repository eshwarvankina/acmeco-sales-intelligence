-- 1. Closing speed distribution
SELECT
    closing_speed,
    COUNT(*)                            AS rep_count,
    ROUND(AVG(avg_days_to_close), 1)    AS avg_days,
    MIN(avg_days_to_close)              AS min_days,
    MAX(avg_days_to_close)              AS max_days
FROM ACMECO_SALES.ANALYTICS_DATA.rep_performance_agg
GROUP BY closing_speed
ORDER BY avg_days;

-- 2. G4G distribution
SELECT
    g4g_status,
    COUNT(*)                            AS rep_count,
    ROUND(AVG(win_rate_pct), 1)         AS avg_win_rate,
    ROUND(AVG(total_revenue), 0)        AS avg_revenue
FROM ACMECO_SALES.ANALYTICS_DATA.rep_performance_agg
GROUP BY g4g_status
ORDER BY rep_count DESC;

-- 3. Open pipeline check
SELECT
    sales_agent,
    open_deals,
    open_pipeline_value,
    avg_order_value
FROM ACMECO_SALES.ANALYTICS_DATA.rep_performance_agg
WHERE open_deals > 0
ORDER BY open_pipeline_value DESC
LIMIT 10;