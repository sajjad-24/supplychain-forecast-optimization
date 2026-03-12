-- ============================================================
-- vw_sku_performance.sql
-- Reusable view: full SKU performance summary
-- ============================================================

CREATE OR REPLACE VIEW vw_sku_performance AS
WITH base AS (
    SELECT
        s.sku_id,
        s.sku_code,
        s.product_name,
        s.category,
        s.unit_cost,
        df.forecast_month,
        df.forecasted_qty,
        df.forecast_method,
        ad.actual_qty,
        ABS(df.forecasted_qty - ad.actual_qty)                                          AS abs_error,
        df.forecasted_qty - ad.actual_qty                                               AS raw_error,
        ABS(df.forecasted_qty - ad.actual_qty)::NUMERIC / NULLIF(ad.actual_qty, 0) * 100 AS abs_pct_error,
        s.unit_cost * ABS(df.forecasted_qty - ad.actual_qty)                           AS error_dollar_value
    FROM demand_forecasts df
    JOIN actual_demand ad ON  df.sku_id      = ad.sku_id
                          AND df.region_id   = ad.region_id
                          AND df.forecast_month = ad.demand_month
    JOIN skus s ON df.sku_id = s.sku_id
)
SELECT
    sku_id,
    sku_code,
    product_name,
    category,
    unit_cost,
    COUNT(*)                                        AS months_tracked,
    ROUND(AVG(abs_pct_error), 2)                    AS avg_mape_pct,
    ROUND(STDDEV(abs_pct_error), 2)                 AS mape_volatility,
    SUM(CASE WHEN raw_error > 0 THEN 1 ELSE 0 END) AS over_forecast_count,
    SUM(CASE WHEN raw_error < 0 THEN 1 ELSE 0 END) AS under_forecast_count,
    ROUND(SUM(error_dollar_value), 2)               AS total_error_cost,
    CASE
        WHEN AVG(abs_pct_error) <= 5  THEN 'A'
        WHEN AVG(abs_pct_error) <= 10 THEN 'B'
        WHEN AVG(abs_pct_error) <= 20 THEN 'C'
        ELSE 'D'
    END                                             AS forecast_grade,
    RANK() OVER (ORDER BY AVG(abs_pct_error) DESC)  AS worst_performer_rank
FROM base
GROUP BY sku_id, sku_code, product_name, category, unit_cost;
