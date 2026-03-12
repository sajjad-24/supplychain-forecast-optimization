-- ============================================================
-- 03_supplier_impact.sql
-- Analyzes how supplier reliability correlates with forecast error
-- Identifies which suppliers contribute most to planning uncertainty
-- ============================================================

-- -------------------------------------------------------
-- Step 1: Supplier reliability profile
-- -------------------------------------------------------
WITH supplier_profile AS (
    SELECT
        sup.supplier_id,
        sup.supplier_name,
        sup.country,
        sup.avg_lead_time_days,
        sup.reliability_score,
        sup.on_time_rate,

        -- Lead time risk category
        CASE
            WHEN sup.avg_lead_time_days <= 10 THEN 'Low Risk'
            WHEN sup.avg_lead_time_days <= 18 THEN 'Medium Risk'
            ELSE 'High Risk'
        END AS lead_time_risk,

        -- Reliability tier
        CASE
            WHEN sup.reliability_score >= 9.0 THEN 'Tier 1 — Premium'
            WHEN sup.reliability_score >= 7.5 THEN 'Tier 2 — Standard'
            ELSE 'Tier 3 — At Risk'
        END AS supplier_tier

    FROM suppliers sup
),

-- -------------------------------------------------------
-- Step 2: Map supplier to SKU forecast errors
-- Joins SKU-Supplier mapping → demand forecasts → actuals
-- -------------------------------------------------------
supplier_forecast_errors AS (
    SELECT
        sp.supplier_id,
        sp.supplier_name,
        sp.supplier_tier,
        sp.lead_time_risk,
        sp.reliability_score,
        sp.on_time_rate,
        s.sku_code,
        s.product_name,
        ss.is_primary,
        df.forecast_month,
        df.forecasted_qty,
        ad.actual_qty,
        ABS(df.forecasted_qty - ad.actual_qty)::NUMERIC
            / NULLIF(ad.actual_qty, 0) * 100                        AS abs_pct_error,
        s.unit_cost * ABS(df.forecasted_qty - ad.actual_qty)        AS error_dollar_value

    FROM sku_suppliers ss
    JOIN supplier_profile sp ON ss.supplier_id = sp.supplier_id
    JOIN skus             s  ON ss.sku_id       = s.sku_id
    JOIN demand_forecasts df ON s.sku_id        = df.sku_id
    JOIN actual_demand    ad ON df.sku_id       = ad.sku_id
                             AND df.region_id    = ad.region_id
                             AND df.forecast_month = ad.demand_month
    WHERE ss.is_primary = TRUE   -- focus on primary suppliers only
),

-- -------------------------------------------------------
-- Step 3: Aggregate performance per supplier
-- -------------------------------------------------------
supplier_summary AS (
    SELECT
        supplier_id,
        supplier_name,
        supplier_tier,
        lead_time_risk,
        reliability_score,
        on_time_rate,
        COUNT(DISTINCT sku_code)                AS skus_supplied,
        COUNT(*)                                AS total_observations,
        ROUND(AVG(abs_pct_error), 2)            AS avg_forecast_mape,
        ROUND(STDDEV(abs_pct_error), 2)         AS forecast_error_volatility,
        ROUND(SUM(error_dollar_value), 2)       AS total_error_cost,

        -- Composite risk score (higher = more problematic)
        ROUND(
            (10 - reliability_score) * 0.4
            + (100 - on_time_rate) * 0.4
            + AVG(abs_pct_error) * 0.2
        , 2)                                    AS composite_risk_score

    FROM supplier_forecast_errors
    GROUP BY
        supplier_id, supplier_name, supplier_tier,
        lead_time_risk, reliability_score, on_time_rate
),

-- -------------------------------------------------------
-- Step 4: Rank suppliers by risk
-- -------------------------------------------------------
ranked_suppliers AS (
    SELECT
        *,
        RANK() OVER (ORDER BY composite_risk_score DESC) AS risk_rank,
        RANK() OVER (ORDER BY total_error_cost DESC)     AS cost_impact_rank
    FROM supplier_summary
)

-- -------------------------------------------------------
-- Final Output: Supplier Risk & Impact Leaderboard
-- -------------------------------------------------------
SELECT
    risk_rank,
    supplier_name,
    supplier_tier,
    lead_time_risk,
    reliability_score,
    on_time_rate,
    skus_supplied,
    avg_forecast_mape           AS avg_mape_pct,
    forecast_error_volatility   AS error_volatility,
    total_error_cost            AS dollar_impact,
    composite_risk_score,

    -- Recommendation
    CASE
        WHEN composite_risk_score >= 15 THEN '🔴 Review & Consider Replacing'
        WHEN composite_risk_score >= 10 THEN '🟡 Monitor Closely / Renegotiate SLA'
        ELSE '🟢 Retain — Performing Well'
    END AS recommendation

FROM ranked_suppliers
ORDER BY risk_rank;
