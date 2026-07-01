# AcmeCo Sales Intelligence Platform

> An end-to-end sales analytics platform built on Snowflake, Python, Apache Airflow, and Tableau — designed to give sales leadership a single, trusted source of truth for pipeline, bookings, and forecast accuracy.

---

## The business problem

AcmeCo is a B2B SaaS company with 150 sales reps across four segments. Every Monday the CRO asks one question: **"Are we going to hit the number this quarter?"**

Nobody could answer it confidently. The VP of Sales pulled pipeline from Salesforce. Finance pulled bookings from their billing system. Sales ops managed quota targets in a spreadsheet. Territory carving lived in another spreadsheet. Three teams, three tools, three versions of the truth.

This platform is the solution — a governed, historically accurate analytics layer that reconciles every source into one place and answers five specific business questions:

| Stakeholder | Question | Frequency |
|---|---|---|
| CRO | Will we hit the quarter? What is pipeline coverage? | Weekly |
| Sales manager | Which reps are at risk of missing quota? | Daily |
| Sales ops | Where are deals getting stuck in the funnel? | Weekly |
| CFO | Are we growing from new customers or just expanding existing ones? | Monthly |
| RevOps | Is our territory carving efficient? | Quarterly |

---

## Architecture overview

```
┌─────────────────────────────────────────────────┐
│                  DATA SOURCES                    │
│   Maven Analytics CSV   +   Python supplement   │
└──────────────────┬──────────────────────────────┘
                   │
            ┌──────▼──────┐
            │   Airflow   │  (Phase 2)
            │     DAG     │
            └──────┬──────┘
                   │
     ┌─────────────┼─────────────┐
     ▼             ▼             ▼
┌─────────┐  ┌──────────┐  ┌───────────┐
│ RAW     │─▶│ STAGING  │─▶│ ANALYTICS │
│ _DATA   │  │ _DATA    │  │ _DATA     │
└─────────┘  └──────────┘  └─────┬─────┘
                                  │
                           ┌──────▼──────┐
                           │   Tableau   │  (Phase 3)
                           │   Public    │
                           └─────────────┘
```

**Design principle:** Data flows in one direction only — RAW receives it, STAGING cleans it, ANALYTICS uses it. Tableau never touches RAW or STAGING. Nothing ever flows backwards.

---

## Tech stack

| Tool | Purpose | Cost |
|---|---|---|
| Snowflake (Standard, AWS US East) | Data warehouse — all three schemas | Free trial |
| Apache Airflow (Docker) | Pipeline orchestration | Free (local) |
| Python 3.11+ | Extraction, transformation, DQ checks | Free |
| Tableau Public | Dashboards | Free |
| GitHub | Version control and documentation | Free |

**Total monthly cost: ~$2–3** (Snowflake X-Small warehouse, 60-second auto-suspend, one daily pipeline run)

---

## Data source

**Maven Analytics CRM Sales Opportunities dataset**
Four CSV files representing a B2B hardware company's sales pipeline.
Structurally identical to a Salesforce CRM export.

Download: [mavenanalytics.io/data-playground](https://mavenanalytics.io/data-playground/crm-sales-opportunities)

| File | Rows | Description |
|---|---|---|
| `sales_pipeline.csv` | 8,800 | Opportunity pipeline with stages and close values |
| `accounts.csv` | 85 | Company/account master data |
| `products.csv` | 7 | Product catalogue with list prices |
| `sales_teams.csv` | 35 | Sales reps, managers, and regional offices |

---

## Phase 1 — Snowflake data model ✓ Complete

### Layer 1: RAW_DATA

Data lands here exactly as-is from the source. No transformations, no renaming, no business logic. Every column is `VARCHAR`. This is the immutable source of record — if anything breaks downstream, everything can be re-derived from here.

```
ACMECO_SALES.RAW_DATA
  ├── sales_pipeline    8,800 rows
  ├── accounts             85 rows
  ├── products              7 rows
  └── sales_teams          35 rows
```

**Data quality issue found and fixed:**
The CSV header row was loaded as a data row in `sales_pipeline`. Identified via `SELECT DISTINCT deal_stage` profiling and removed:
```sql
DELETE FROM RAW_DATA.sales_pipeline
WHERE deal_stage = 'deal_stage';
```

---

### Layer 2: STAGING_DATA

Data is cleaned, typed, and normalised here. No business logic yet — only making the data trustworthy. Every staging table has an audit `loaded_at` timestamp.

```
ACMECO_SALES.STAGING_DATA
  ├── stg_sales_pipeline    8,800 rows
  ├── stg_accounts             85 rows
  ├── stg_products              7 rows
  └── stg_sales_teams          35 rows
```

**Key transformations on `stg_sales_pipeline`:**

```sql
-- Stage label normalisation
CASE TRIM(LOWER(deal_stage))
    WHEN 'won'         THEN 'closed_won'
    WHEN 'lost'        THEN 'closed_lost'
    WHEN 'engaging'    THEN 'engaging'
    WHEN 'prospecting' THEN 'prospecting'
    ELSE 'unknown'
END AS deal_stage

-- Safe type casting
TRY_TO_DATE(engage_date)                    AS engage_date
TRY_TO_DATE(deal_closing_date)              AS deal_closing_date
TRY_TO_NUMBER(NULLIF(TRIM(close_value),'')) AS close_value

-- Derived columns
CASE WHEN deal_stage = 'won' THEN TRUE ELSE FALSE END  AS is_won
CASE WHEN deal_stage = 'lost' THEN TRUE ELSE FALSE END AS is_lost
DATEDIFF('day', engage_date, deal_closing_date)        AS days_to_close
```

**Why `TRY_TO_*` functions over `CAST`:**
`TRY_TO_DATE` and `TRY_TO_NUMBER` return NULL on failure instead of throwing an error. The RAW layer may contain malformed values — safe casting means one bad row never breaks the entire pipeline.

---

### Layer 3: ANALYTICS_DATA

Business logic lives here. Metrics are computed, tables are joined, and aggregations are pre-built for Tableau performance. This is the only layer Tableau connects to.

```
ACMECO_SALES.ANALYTICS_DATA
  ├── sales_fact                8,800 rows
  ├── quarterly_metrics_agg        12 rows
  └── rep_performance_agg          30 rows
```

---

#### `sales_fact` — central fact table

One row per opportunity. Joins all four staging tables into a single wide denormalised table. Powers all drill-down analysis in Tableau.

**Join strategy — no shared primary keys across sources:**
```sql
pipeline → products  : TRIM(LOWER(product))     = TRIM(LOWER(product))
pipeline → accounts  : TRIM(LOWER(account))     = TRIM(LOWER(account))
pipeline → teams     : TRIM(LOWER(sales_agent)) = TRIM(LOWER(sales_agent))
```

Account name is the only shared key between pipeline and accounts. `TRIM(LOWER(...))` normalises capitalisation and whitespace before joining — without this, "Momentum Corp" and "momentum corp" would not match.

**Key derived columns:**
```sql
-- Deal size segmentation
CASE
    WHEN close_value >= 30000 THEN 'Large'
    WHEN close_value >= 10000 THEN 'Medium'
    WHEN close_value > 0      THEN 'Small'
    ELSE 'Unknown'
END AS deal_size_category

-- Sales cycle speed
CASE
    WHEN days_to_close <= 30 THEN 'Fast'
    WHEN days_to_close <= 60 THEN 'Normal'
    ELSE 'Slow'
END AS sales_cycle_category

-- Fiscal quarter
CONCAT(YEAR(deal_closing_date), '-Q',
       QUARTER(deal_closing_date)) AS deal_close_quarter
```

---

#### `quarterly_metrics_agg` — CRO trend view

Pre-aggregated quarterly metrics by region. One row per quarter per regional office (12 rows total). Powers revenue trend charts and pipeline coverage views.

**Key metrics:**
```
total_deals, won_deals, lost_deals, open_deals
win_rate_pct
total_revenue
total_pipeline_value    (pipegen)
avg_order_value         (AOV)
avg_days_to_close_won
large_deals, medium_deals, small_deals
```

**Window function analysis built on top:**
```sql
-- Quarter average win rate
AVG(win_rate_pct) OVER (
    PARTITION BY deal_close_quarter
) AS avg_win_rate_for_quarter

-- Each region's variance from quarter average
win_rate_pct - AVG(win_rate_pct) OVER (
    PARTITION BY deal_close_quarter
) AS variance_from_quarter_avg

-- Rank regions within each quarter
RANK() OVER (
    PARTITION BY deal_close_quarter
    ORDER BY win_rate_pct DESC
) AS rank_in_quarter
```

---

#### `rep_performance_agg` — manager G4G view

Rep-level performance metrics with fully dynamic thresholds. One row per sales rep (30 rows total). Powers the manager dashboard G4G heatmap.

**Architect-level decision — dynamic thresholds via CTEs:**

No hardcoded values anywhere in the classification logic. All thresholds are derived from the actual data distribution using `PERCENTILE_CONT`:

```sql
-- CTE 1: rep_base
-- Rep level aggregations — one row per rep

-- CTE 2: thresholds
-- Closing speed cut points derived from actual distribution
PERCENTILE_CONT(0.25) → p25  (Fast Closer cutoff)
PERCENTILE_CONT(0.75) → p75  (Slow Closer cutoff)
PERCENTILE_CONT(0.90) → p90  (Needs Coaching cutoff)

-- CTE 3: win_rate_stats
-- G4G status cut points derived from actual win rate distribution
PERCENTILE_CONT(0.50) → p50  (Red/Yellow boundary)
PERCENTILE_CONT(0.75) → p75  (Yellow/Green boundary)

-- CROSS JOIN broadcasts single-row threshold values
-- onto all 30 rep rows for use in CASE statements
FROM rep_base r
CROSS JOIN thresholds t
CROSS JOIN win_rate_stats w
```

**Closing speed classification (data-driven):**
```
Fast Closer     < p25          faster than 75% of all reps
Average         p25 to p75     middle 50% of reps
Slow Closer     p75 to p90     slower than 75%, not bottom 10%
Needs Coaching  > p90          slowest 10% — management action required
```

**G4G status classification (data-driven):**
```
Green   >= p75 win rate    top 25% of reps
Yellow  >= p50 win rate    middle 50% of reps
Red      < p50 win rate    below median — at risk
```

**Open pipeline value:**
`close_value` is NULL for open deals in the source data — Maven only populates it on closed deals. Resolution: use `list_price` from the products table as the estimated value of open pipeline. This is standard practice when opportunity value has not yet been entered by the rep.

---

## Key metrics defined

| Metric | Definition | SQL |
|---|---|---|
| ACV | Annual Contract Value | `amount / (contract_months / 12)` |
| Pipegen | New pipeline created in period | `SUM(amount) WHERE created_date IN period` |
| AOV | Average Order Value | `AVG(close_value) WHERE is_won = TRUE` |
| Win rate | Closed won / total opportunities | `SUM(is_won) / COUNT(*) * 100` |
| Days to close | Engage date to close date | `DATEDIFF('day', engage_date, deal_closing_date)` |
| G4G status | Rep attainment vs peers | Dynamic p50/p75 win rate classification |

---

## Data observations

### Q1 2017 win rate anomaly
Q1 2017 shows an unusually high win rate of ~82% compared to ~61% for all subsequent quarters. Hypothesis: Q1 data likely contains only closed deals, not the full pipeline. Engaging and Prospecting deals from Q1 may not have been captured in the source data. Q1 2017 should be treated as incomplete and excluded from win rate trend analysis.

### West region volatility
West region shows the highest variance from the quarterly average — swinging from +2.7% above average in Q1 to -1.2% below in Q3. Warrants further investigation into rep turnover or territory changes in that region.

### Central region: volume vs quality
Central consistently generates the highest deal volume but does not lead in win rate. Suggests a quantity-over-quality prospecting approach compared to the East region.

### Open pipeline value gap
`close_value` is only populated for closed won deals in the source data. Open pipeline value is estimated using product list price from the products table. This is documented as a known limitation of the Maven Analytics dataset.

---

## Snowflake worksheets

All SQL development was done in named, numbered Snowflake worksheets:

```
01_raw_ddl              CREATE TABLE statements for RAW_DATA layer
02_raw_load_verify      Row count validation and header row cleanup
03_staging_transforms   stg_sales_pipeline transformation
04_staging_dimensions   stg_accounts, stg_products, stg_sales_teams
05_analytics_fact       sales_fact wide table construction
06_analytics_agg        quarterly_metrics_agg and rep_performance_agg
07_analytics_verify     Final validation queries across all tables
```

---

## Repository structure

```
acmeco-sales-intelligence/
│
├── README.md
│
├── snowflake/
│   ├── 01_raw_ddl/
│   │   └── raw_tables.sql
│   ├── 02_staging/
│   │   ├── stg_sales_pipeline.sql
│   │   └── stg_dimensions.sql
│   └── 03_analytics/
│       ├── sales_fact.sql
│       ├── quarterly_metrics_agg.sql
│       └── rep_performance_agg.sql
│
├── docs/
│   └── data_observations.md
│
├── .gitignore
└── .env.example
```

---

## What is coming next

### Phase 2 — Python and Airflow (in progress)
- `load_maven.py` — reads CSVs, loads to RAW_DATA (replaces manual UI upload)
- `run_staging.py` — executes staging SQL via Python connector
- `dq_checks.py` — validates row counts, nulls, referential integrity
- `sales_pipeline_dag.py` — Airflow DAG orchestrating all steps on daily schedule

### Phase 3 — Tableau dashboards (planned)
- CRO view — revenue trend, pipeline coverage, forecast vs actual
- Manager view — G4G heatmap by rep, slippage tracker
- Territory view — AOV by segment, carving efficiency

---

## How to run locally

### Prerequisites
```bash
pip install snowflake-connector-python pandas python-dotenv
```

### Environment setup
Create a `.env` file in the project root:
```
SNOWFLAKE_ACCOUNT=your_account_identifier
SNOWFLAKE_USER=your_username
SNOWFLAKE_PASSWORD=your_password
SNOWFLAKE_WAREHOUSE=ACMECO_WH
SNOWFLAKE_DATABASE=ACMECO_SALES
SNOWFLAKE_SCHEMA=RAW_DATA
```

### Run the SQL layers in order
```
01_raw_ddl          → creates RAW_DATA tables
02_staging          → creates STAGING_DATA tables
03_analytics        → creates ANALYTICS_DATA tables
```

---

## Author

Eshwar Vankina — Data Engineer
[github.com/eshwarvankina](https://github.com/eshwarvankina)
