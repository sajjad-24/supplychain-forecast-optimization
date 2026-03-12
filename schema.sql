-- ============================================================
-- Supply Chain Forecast Performance Optimizer
-- Schema Definition
-- ============================================================

-- Regions / Markets
CREATE TABLE regions (
    region_id       SERIAL PRIMARY KEY,
    region_name     VARCHAR(100) NOT NULL,
    country         VARCHAR(100) NOT NULL,
    climate_zone    VARCHAR(50)  -- used for seasonal analysis
);

-- Product SKUs
CREATE TABLE skus (
    sku_id          SERIAL PRIMARY KEY,
    sku_code        VARCHAR(50)  NOT NULL UNIQUE,
    product_name    VARCHAR(200) NOT NULL,
    category        VARCHAR(100) NOT NULL,
    unit_cost       NUMERIC(10,2) NOT NULL,
    weight_kg       NUMERIC(8,3) NOT NULL   -- used for carbon calculations
);

-- Suppliers
CREATE TABLE suppliers (
    supplier_id         SERIAL PRIMARY KEY,
    supplier_name       VARCHAR(200) NOT NULL,
    country             VARCHAR(100) NOT NULL,
    avg_lead_time_days  INT          NOT NULL,
    reliability_score   NUMERIC(4,2) NOT NULL CHECK (reliability_score BETWEEN 0 AND 10),
    on_time_rate        NUMERIC(5,2) NOT NULL CHECK (on_time_rate BETWEEN 0 AND 100)
);

-- SKU-Supplier mapping (a SKU can have multiple suppliers)
CREATE TABLE sku_suppliers (
    sku_supplier_id SERIAL PRIMARY KEY,
    sku_id          INT NOT NULL REFERENCES skus(sku_id),
    supplier_id     INT NOT NULL REFERENCES suppliers(supplier_id),
    is_primary      BOOLEAN DEFAULT TRUE
);

-- Monthly demand forecasts (what was predicted)
CREATE TABLE demand_forecasts (
    forecast_id     SERIAL PRIMARY KEY,
    sku_id          INT          NOT NULL REFERENCES skus(sku_id),
    region_id       INT          NOT NULL REFERENCES regions(region_id),
    forecast_month  DATE         NOT NULL,  -- first day of month
    forecasted_qty  INT          NOT NULL,
    forecast_method VARCHAR(100),           -- e.g. 'moving_average', 'ml_model', 'manual'
    created_at      TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

-- Actual demand / sales (what actually happened)
CREATE TABLE actual_demand (
    actual_id       SERIAL PRIMARY KEY,
    sku_id          INT  NOT NULL REFERENCES skus(sku_id),
    region_id       INT  NOT NULL REFERENCES regions(region_id),
    demand_month    DATE NOT NULL,
    actual_qty      INT  NOT NULL
);

-- Shipments (used for carbon footprint analysis)
CREATE TABLE shipments (
    shipment_id         SERIAL PRIMARY KEY,
    sku_id              INT          NOT NULL REFERENCES skus(sku_id),
    supplier_id         INT          NOT NULL REFERENCES suppliers(supplier_id),
    region_id           INT          NOT NULL REFERENCES regions(region_id),
    shipment_date       DATE         NOT NULL,
    quantity_shipped    INT          NOT NULL,
    transport_mode      VARCHAR(50)  NOT NULL CHECK (transport_mode IN ('air', 'sea', 'road', 'rail')),
    distance_km         NUMERIC(10,2) NOT NULL,
    freight_cost        NUMERIC(12,2) NOT NULL,
    was_overforecasted  BOOLEAN      DEFAULT FALSE  -- flagged if shipment driven by bad forecast
);

-- Carbon emission factors by transport mode (kg CO2 per tonne-km)
CREATE TABLE carbon_factors (
    mode            VARCHAR(50) PRIMARY KEY,
    kg_co2_per_tonne_km NUMERIC(8,4) NOT NULL
);
