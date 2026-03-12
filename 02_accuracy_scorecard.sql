-- ============================================================
-- 02_accuracy_scorecard.sql
-- Aggregated performance scorecard per SKU and per region
-- Surfaces worst performers and ranks forecast methods
-- ============================================================

-- -------------------------------------------------------
-- Base CTE: error calculations (reusable across scorecards)
-- -------------------------------------------------------
WITH base_errors AS (
    SELECT
        s.sku_id,
        s.sku_code,
        s.product_name,
        s.category,
        r.region_id,
        r.region_name,
        df.forecast_method,
        df.forecast_month,
        df.forecasted_qty,
        ad.actual_qty,
        ABS(df.forecasted_qty - ad.actual_qty)                                              AS abs_error,
        (df.forecasted_qty - ad.actual_qty)                                                 AS raw_error,
        ABS(df.forecasted_qty - ad.actual_qty)::NUMERIC / NULLIF(ad.actual_qty, 0) * 100   AS abs_pct_error,
        s.unit_cost * ABS(df.forecasted_qty - ad.actual_qty)                               AS error_dollar_value
    FROM demand_forecasts df
    JOIN actual_demand ad ON  df.sku_id    = ad.sku_id
                          AND df.region_id = ad.region_id
                          AND df.forecast_month = ad.demand_month
    JOIN skus     s ON df.sku_id    = s.sku_id
    JOIN regions  r ON df.region_id = r.region_id
),

-- -------------------------------------------------------
-- Scorecard A: SKU-level performance (across all regions)
-- -------------------------------------------------------
sku_scorecard AS (
    SELECT
        sku_code,
        product_name,
        category,
        COUNT(*)                                AS months_tracked,
        ROUND(AVG(abs_pct_error), 2)            AS avg_mape_pct,
        ROUND(MIN(abs_pct_error), 2)            AS best_month_mape,
        ROUND(MAX(abs_pct_error), 2)            AS worst_month_mape,
        ROUND(STDDEV(abs_pct_error), 2)         AS mape_std_dev,        -- volatility of forecast quality
        SUM(CASE WHEN raw_error > 0 THEN 1 ELSE 0 END) AS over_forecast_months,
        SUM(CASE WHEN raw_error < 0 THEN 1 ELSE 0 END) AS under_forecast_months,
        ROUND(SUM(error_dollar_value), 2)       AS total_error_dollar_value,
        ROUND(AVG(error_dollar_value), 2)       AS avg_monthly_error_cost,

        -- Overall grade
        CASE
            WHEN AVG(abs_pct_error) <= 5  THEN 'A — Excellent'
            WHEN AVG(abs_pct_error) <= 10 THEN 'B — Good'
            WHEN AVG(abs_pct_error) <= 20 THEN 'C — Needs Improvement'
            ELSE                               'D — Poor'
        END AS forecast_grade,

        -- Bias flag
        CASE
            WHEN SUM(raw_error) > 0 THEN 'Systematic Over-Forecast'
            WHEN SUM(raw_error) < 0 THEN 'Systematic Under-Forecast'
            ELSE 'Balanced'
        END AS bias_type

    FROM base_errors
    GROUP BY sku_code, product_name, category
),

-- -------------------------------------------------------
-- Scorecard B: Region-level performance
-- -------------------------------------------------------
region_scorecard AS (
    SELECT
        region_name,
        COUNT(DISTINCT sku_id)                  AS skus_tracked,
        COUNT(*)                                AS total_observations,
        ROUND(AVG(abs_pct_error), 2)            AS avg_mape_pct,
        ROUND(SUM(error_dollar_value), 2)       AS total_error_dollar_value,
        SUM(CASE WHEN abs_pct_error > 20 THEN 1 ELSE 0 END) AS poor_forecast_months,
        ROUND(
            SUM(CASE WHEN abs_pct_error > 20 THEN 1 ELSE 0 END)::NUMERIC / COUNT(*) * 100,
        1)                                      AS pct_poor_months,

        CASE
            WHEN AVG(abs_pct_error) <= 5  THEN 'A — Excellent'
            WHEN AVG(abs_pct_error) <= 10 THEN 'B — Good'
            WHEN AVG(abs_pct_error) <= 20 THEN 'C — Needs Improvement'
            ELSE                               'D — Poor'
        END AS region_forecast_grade

    FROM base_errors
    GROUP BY region_name
),

-- -------------------------------------------------------
-- Scorecard C: Forecast method comparison
-- -------------------------------------------------------
method_scorecard AS (
    SELECT
        forecast_method,
        COUNT(*)                                AS total_forecasts,
        ROUND(AVG(abs_pct_error), 2)            AS avg_mape_pct,
        ROUND(STDDEV(abs_pct_error), 2)         AS consistency_std_dev,
        SUM(CASE WHEN abs_pct_error <= 10 THEN 1 ELSE 0 END) AS accurate_forecasts,
        ROUND(
            SUM(CASE WHEN abs_pct_error <= 10 THEN 1 ELSE 0 END)::NUMERIC / COUNT(*) * 100,
        1)                                      AS pct_within_10pct,
        RANK() OVER (ORDER BY AVG(abs_pct_error)) AS accuracy_rank
    FROM base_errors
    GROUP BY forecast_method
)

-- -------------------------------------------------------
-- Output: SKU Scorecard (ranked worst to best)
-- -------------------------------------------------------
SELECT
    RANK() OVER (ORDER BY avg_mape_pct DESC)    AS rank,
    sku_code,
    product_name,
    category,
    avg_mape_pct,
    forecast_grade,
    bias_type,
    over_forecast_months,
    under_forecast_months,
    total_error_dollar_value                    AS total_dollar_error,
    mape_std_dev                                AS forecast_volatility
FROM sku_scorecard
ORDER BY avg_mape_pct DESC;

-- -------------------------------------------------------
-- Uncomment to view Region Scorecard
-- -------------------------------------------------------
/*
SELECT * FROM region_scorecard ORDER BY avg_mape_pct DESC;
*/

-- -------------------------------------------------------
-- Uncomment to view Forecast Method Scorecard
-- -------------------------------------------------------
/*
SELECT * FROM method_scorecard ORDER BY accuracy_rank;
*/
