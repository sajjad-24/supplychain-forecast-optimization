-- ============================================================
-- vw_region_scorecard.sql
-- Reusable view: forecast performance aggregated by region
-- ============================================================

CREATE OR REPLACE VIEW vw_region_scorecard AS
WITH base AS (
    SELECT
        r.region_id,
        r.region_name,
        r.country,
        df.forecast_month,
        df.forecasted_qty,
        ad.actual_qty,
        ABS(df.forecasted_qty - ad.actual_qty)::NUMERIC / NULLIF(ad.actual_qty, 0) * 100   AS abs_pct_error,
        s.unit_cost * ABS(df.forecasted_qty - ad.actual_qty)                               AS error_dollar_value,
        df.forecasted_qty - ad.actual_qty                                                   AS raw_error
    FROM demand_forecasts df
    JOIN actual_demand ad ON  df.sku_id      = ad.sku_id
                          AND df.region_id   = ad.region_id
                          AND df.forecast_month = ad.demand_month
    JOIN regions r ON df.region_id = r.region_id
    JOIN skus    s ON df.sku_id    = s.sku_id
)
SELECT
    region_id,
    region_name,
    country,
    COUNT(DISTINCT forecast_month)                  AS months_tracked,
    ROUND(AVG(abs_pct_error), 2)                    AS avg_mape_pct,
    ROUND(MIN(abs_pct_error), 2)                    AS best_mape_pct,
    ROUND(MAX(abs_pct_error), 2)                    AS worst_mape_pct,
    SUM(CASE WHEN raw_error > 0 THEN 1 ELSE 0 END) AS over_forecast_count,
    SUM(CASE WHEN raw_error < 0 THEN 1 ELSE 0 END) AS under_forecast_count,
    ROUND(SUM(error_dollar_value), 2)               AS total_error_cost,
    ROUND(AVG(error_dollar_value), 2)               AS avg_monthly_error_cost,
    CASE
        WHEN AVG(abs_pct_error) <= 5  THEN 'A — Excellent'
        WHEN AVG(abs_pct_error) <= 10 THEN 'B — Good'
        WHEN AVG(abs_pct_error) <= 20 THEN 'C — Needs Improvement'
        ELSE                               'D — Poor'
    END                                             AS region_grade,
    RANK() OVER (ORDER BY AVG(abs_pct_error))       AS performance_rank
FROM base
GROUP BY region_id, region_name, country;
