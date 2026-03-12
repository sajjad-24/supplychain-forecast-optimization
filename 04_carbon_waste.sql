-- ============================================================
-- 04_carbon_waste.sql
-- Quantifies CO2 emissions wasted due to over-forecasting
-- Links bad forecasts to unnecessary shipments and emissions
-- ============================================================

-- -------------------------------------------------------
-- Step 1: Calculate CO2 per shipment
-- Formula: CO2 (kg) = weight_kg/1000 * distance_km * emission_factor
-- -------------------------------------------------------
WITH shipment_emissions AS (
    SELECT
        sh.shipment_id,
        sh.shipment_date,
        sh.transport_mode,
        sh.quantity_shipped,
        sh.distance_km,
        sh.freight_cost,
        sh.was_overforecasted,
        s.sku_code,
        s.product_name,
        s.category,
        s.weight_kg,
        s.unit_cost,
        sup.supplier_name,
        r.region_name,
        cf.kg_co2_per_tonne_km,

        -- Total shipment weight in tonnes
        ROUND((s.weight_kg * sh.quantity_shipped) / 1000.0, 4)  AS total_weight_tonnes,

        -- CO2 emissions for this shipment (kg)
        ROUND(
            (s.weight_kg * sh.quantity_shipped / 1000.0)
            * sh.distance_km
            * cf.kg_co2_per_tonne_km
        , 2)                                                    AS co2_kg,

        -- Cost per unit
        ROUND(sh.freight_cost / NULLIF(sh.quantity_shipped, 0), 2) AS freight_cost_per_unit

    FROM shipments sh
    JOIN skus         s   ON sh.sku_id      = s.sku_id
    JOIN suppliers    sup ON sh.supplier_id = sup.supplier_id
    JOIN regions      r   ON sh.region_id   = r.region_id
    JOIN carbon_factors cf ON sh.transport_mode = cf.mode
),

-- -------------------------------------------------------
-- Step 2: Split into over-forecasted vs normal shipments
-- -------------------------------------------------------
overforecasted_shipments AS (
    SELECT
        *,
        CASE WHEN was_overforecasted THEN co2_kg ELSE 0 END     AS wasted_co2_kg,
        CASE WHEN was_overforecasted THEN freight_cost ELSE 0 END AS wasted_freight_cost
    FROM shipment_emissions
),

-- -------------------------------------------------------
-- Step 3: Summarize waste by transport mode
-- -------------------------------------------------------
mode_summary AS (
    SELECT
        transport_mode,
        COUNT(*)                                    AS total_shipments,
        SUM(CASE WHEN was_overforecasted THEN 1 ELSE 0 END)   AS overforecast_shipments,
        ROUND(SUM(co2_kg), 2)                       AS total_co2_kg,
        ROUND(SUM(wasted_co2_kg), 2)                AS wasted_co2_kg,
        ROUND(SUM(freight_cost), 2)                 AS total_freight_cost,
        ROUND(SUM(wasted_freight_cost), 2)          AS wasted_freight_cost,
        ROUND(
            SUM(wasted_co2_kg) / NULLIF(SUM(co2_kg), 0) * 100,
        1)                                          AS pct_co2_wasted
    FROM overforecasted_shipments
    GROUP BY transport_mode
),

-- -------------------------------------------------------
-- Step 4: SKU-level carbon waste ranking
-- -------------------------------------------------------
sku_carbon_waste AS (
    SELECT
        sku_code,
        product_name,
        category,
        COUNT(*)                                        AS shipments,
        ROUND(SUM(co2_kg), 2)                           AS total_co2_kg,
        ROUND(SUM(wasted_co2_kg), 2)                    AS wasted_co2_kg,
        ROUND(SUM(wasted_freight_cost), 2)              AS wasted_freight_cost,
        ROUND(SUM(wasted_co2_kg) / NULLIF(SUM(co2_kg),0) * 100, 1) AS pct_co2_wasted,
        RANK() OVER (ORDER BY SUM(wasted_co2_kg) DESC) AS waste_rank
    FROM overforecasted_shipments
    GROUP BY sku_code, product_name, category
)

-- -------------------------------------------------------
-- Final Output A: Overall carbon waste summary by mode
-- -------------------------------------------------------
SELECT
    transport_mode,
    total_shipments,
    overforecast_shipments,
    total_co2_kg,
    wasted_co2_kg,
    pct_co2_wasted,
    wasted_freight_cost,

    -- Equivalent trees needed to offset wasted CO2
    -- 1 mature tree absorbs ~21 kg CO2/year
    ROUND(wasted_co2_kg / 21.0, 0)     AS trees_needed_to_offset,

    -- Equivalent car km driven
    -- Average car emits ~0.12 kg CO2/km
    ROUND(wasted_co2_kg / 0.12, 0)     AS equivalent_car_km

FROM mode_summary
ORDER BY wasted_co2_kg DESC;

-- -------------------------------------------------------
-- Uncomment for SKU-level carbon waste leaderboard
-- -------------------------------------------------------
/*
SELECT
    waste_rank,
    sku_code,
    product_name,
    category,
    total_co2_kg,
    wasted_co2_kg,
    pct_co2_wasted,
    wasted_freight_cost
FROM sku_carbon_waste
ORDER BY waste_rank;
*/

-- -------------------------------------------------------
-- Uncomment for full shipment-level detail
-- -------------------------------------------------------
/*
SELECT
    shipment_date,
    sku_code,
    product_name,
    supplier_name,
    region_name,
    transport_mode,
    quantity_shipped,
    distance_km,
    total_weight_tonnes,
    co2_kg,
    freight_cost,
    was_overforecasted,
    wasted_co2_kg,
    wasted_freight_cost
FROM overforecasted_shipments
ORDER BY shipment_date, was_overforecasted DESC;
*/
