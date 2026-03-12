-- ============================================================
-- 01_forecast_vs_actual.sql
-- Core comparison: forecasted qty vs actual demand
-- Calculates forecast error metrics per SKU, region, and month
-- ============================================================

-- -------------------------------------------------------
-- Step 1: Raw forecast error per SKU / region / month
-- -------------------------------------------------------
WITH forecast_actuals AS (
    SELECT
        df.forecast_month,
        s.sku_code,
        s.product_name,
        s.category,
        r.region_name,
        df.forecast_method,
        df.forecasted_qty,
        ad.actual_qty,

        -- Absolute error
        ABS(df.forecasted_qty - ad.actual_qty) AS absolute_error,

        -- Forecast error (positive = over-forecast, negative = under-forecast)
        df.forecasted_qty - ad.actual_qty AS raw_error,

        -- Mean Absolute Percentage Error (MAPE) component
        ROUND(
            ABS(df.forecasted_qty - ad.actual_qty)::NUMERIC / NULLIF(ad.actual_qty, 0) * 100,
        2) AS abs_pct_error,

        -- Direction flag
        CASE
            WHEN df.forecasted_qty > ad.actual_qty THEN 'Over-Forecast'
            WHEN df.forecasted_qty < ad.actual_qty THEN 'Under-Forecast'
            ELSE 'On Target'
        END AS forecast_direction,

        -- Severity classification
        CASE
            WHEN ABS(df.forecasted_qty - ad.actual_qty)::NUMERIC / NULLIF(ad.actual_qty, 0) <= 0.05 THEN 'Excellent (<=5%)'
            WHEN ABS(df.forecasted_qty - ad.actual_qty)::NUMERIC / NULLIF(ad.actual_qty, 0) <= 0.10 THEN 'Good (<=10%)'
            WHEN ABS(df.forecasted_qty - ad.actual_qty)::NUMERIC / NULLIF(ad.actual_qty, 0) <= 0.20 THEN 'Acceptable (<=20%)'
            ELSE 'Poor (>20%)'
        END AS accuracy_band

    FROM demand_forecasts df
    JOIN actual_demand    ad ON df.sku_id    = ad.sku_id
                             AND df.region_id = ad.region_id
                             AND df.forecast_month = ad.demand_month
    JOIN skus              s  ON df.sku_id    = s.sku_id
    JOIN regions           r  ON df.region_id = r.region_id
),

-- -------------------------------------------------------
-- Step 2: Monthly trend — are errors improving over time?
-- -------------------------------------------------------
monthly_trend AS (
    SELECT
        forecast_month,
        ROUND(AVG(abs_pct_error), 2)        AS avg_mape,
        COUNT(*)                            AS total_sku_region_combos,
        SUM(CASE WHEN forecast_direction = 'Over-Forecast'  THEN 1 ELSE 0 END) AS over_forecast_count,
        SUM(CASE WHEN forecast_direction = 'Under-Forecast' THEN 1 ELSE 0 END) AS under_forecast_count,
        SUM(CASE WHEN accuracy_band = 'Poor (>20%)'         THEN 1 ELSE 0 END) AS poor_accuracy_count
    FROM forecast_actuals
    GROUP BY forecast_month
    ORDER BY forecast_month
)

-- -------------------------------------------------------
-- Final Output A: Detailed row-level forecast accuracy
-- -------------------------------------------------------
SELECT
    forecast_month,
    sku_code,
    product_name,
    category,
    region_name,
    forecast_method,
    forecasted_qty,
    actual_qty,
    raw_error,
    absolute_error,
    abs_pct_error           AS mape_pct,
    forecast_direction,
    accuracy_band
FROM forecast_actuals
ORDER BY abs_pct_error DESC, forecast_month;

-- -------------------------------------------------------
-- Final Output B: Monthly trend summary
-- Run separately to see if forecast quality is improving
-- -------------------------------------------------------
/*
SELECT
    TO_CHAR(forecast_month, 'Mon YYYY')     AS month,
    avg_mape                                AS avg_mape_pct,
    over_forecast_count,
    under_forecast_count,
    poor_accuracy_count,
    ROUND(poor_accuracy_count::NUMERIC / total_sku_region_combos * 100, 1) AS pct_poor_accuracy
FROM monthly_trend;
*/
