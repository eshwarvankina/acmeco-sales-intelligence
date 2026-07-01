

select *
from acmeco_sales.analytics_data.quarterly_metrics_agg
;


select 
    deal_close_quarter,
    regional_office,
    total_deals,
    win_rate_pct,

    round(avg(win_rate_pct) over (partition by deal_close_quarter),1) as avg_win_rate_for_quarter,

    --diff between this region and the quarter average
    round(win_rate_pct - avg(win_rate_pct) over (partition by deal_close_quarter), 1)
        as variance_from_quarter_avg,

    --rank regions within quarters
    rank() over (partition by deal_close_quarter order by win_rate_pct desc) as rank_in_quarter
from acmeco_sales.analytics_data.quarterly_metrics_agg
order by deal_close_quarter, rank_in_quarter
    