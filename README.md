# 📦 Supply Chain Forecast Performance Optimizer

A SQL-based analytics project that measures demand forecast accuracy across SKUs, regions, and suppliers — and quantifies the operational and environmental cost of forecast errors in a logistics supply chain.

---

## 🧠 Business Problem

Inaccurate demand forecasting is one of the most costly problems in supply chain management. Over-forecasting leads to excess inventory, unnecessary shipments, and wasted freight costs. Under-forecasting causes stockouts, lost revenue, and emergency airfreight. Both erode profitability and — in the case of excess shipments — contribute unnecessarily to carbon emissions.

This project simulates a real-world scenario where a logistics company wants to:
1. **Measure** forecast accuracy per SKU, region, and forecast method
2. **Identify** which suppliers contribute most to planning uncertainty
3. **Quantify** the carbon footprint of shipments driven by poor forecasts
4. **Score** and rank performance to drive targeted improvements

---

## 🗂️ Project Structure

```
supply-chain-forecast-optimizer/
│
├── data/
│   ├── schema.sql              ← Table definitions (8 tables)
│   └── seed_data.sql           ← Sample data (12 months, 8 SKUs, 5 regions)
│
├── analysis/
│   ├── 01_forecast_vs_actual.sql   ← Row-level error + monthly trend
│   ├── 02_accuracy_scorecard.sql   ← SKU / region / method scorecards
│   ├── 03_supplier_impact.sql      ← Supplier risk & cost leaderboard
│   └── 04_carbon_waste.sql         ← CO2 emissions wasted by over-forecasting
│
└── views/
    ├── vw_sku_performance.sql      ← Reusable SKU performance view
    └── vw_region_scorecard.sql     ← Reusable region scorecard view
```

---

## 🗃️ Data Model

| Table | Description |
|---|---|
| `regions` | Markets / geographies (5 regions across US, Europe, Asia, Middle East) |
| `skus` | Product catalog with unit cost and weight |
| `suppliers` | Supplier profiles with lead time, reliability score, and on-time rate |
| `sku_suppliers` | Many-to-many mapping of SKUs to primary/backup suppliers |
| `demand_forecasts` | Monthly forecasted quantities per SKU/region/method |
| `actual_demand` | Actual quantities sold per SKU/region/month |
| `shipments` | Shipment records with transport mode, distance, and cost |
| `carbon_factors` | CO2 emission factors (kg per tonne-km) by transport mode |

---

## 🔍 Analysis Modules

### 01 — Forecast vs Actual
Compares forecasted and actual demand at the row level. Calculates:
- **MAPE** (Mean Absolute Percentage Error) per SKU/region/month
- Forecast direction (over vs under-forecast)
- Accuracy band classification (Excellent / Good / Acceptable / Poor)
- Monthly trend to detect whether forecast quality is improving

**Key SQL techniques:** CTEs, CASE statements, window functions, NULLIF

---

### 02 — Accuracy Scorecard
Aggregates error metrics into graded scorecards at three levels:
- **SKU scorecard** — grade (A–D), bias type, dollar impact, volatility
- **Region scorecard** — which markets have the worst forecast discipline
- **Method scorecard** — compares `moving_average` vs `ml_model` vs `manual`

**Key SQL techniques:** Multi-CTE chaining, RANK(), STDDEV(), conditional aggregation

---

### 03 — Supplier Impact Analysis
Maps suppliers to SKU forecast errors and builds a composite risk score based on:
- Supplier reliability score (0–10)
- On-time delivery rate
- Average MAPE of their supplied SKUs
- Lead time risk category

Outputs a ranked leaderboard with actionable recommendations (retain / monitor / replace).

**Key SQL techniques:** Multi-table JOINs, composite scoring formula, RANK(), filtered aggregation

---

### 04 — Carbon Waste Analysis
Estimates CO2 emissions (kg) for every shipment using the formula:

```
CO2 (kg) = (weight_kg × qty / 1000) × distance_km × emission_factor
```

Then isolates shipments flagged as driven by over-forecasting to calculate:
- Total CO2 wasted by transport mode
- Equivalent trees needed to offset
- Equivalent car kilometres driven
- Wasted freight cost per SKU

**Key SQL techniques:** Numeric formula in SQL, CTEs, conditional SUM, RANK()

---

## 📊 Key Findings (Sample Data)

| Finding | Detail |
|---|---|
| Worst SKU by MAPE | SKU-007 (Forklift Battery Pack) — avg 37% error, highly volatile demand |
| Chronic over-forecast | SKU-001 (Industrial Pump A) — 20% over-forecast every month in Northeast US |
| Stockout risk | SKU-002 (Hydraulic Seal Kit) — actual demand 30–35% above forecast in Southeast Asia |
| Best forecast method | `ml_model` outperforms `manual` by ~12 MAPE points |
| Highest-risk supplier | FastTrack Supplies (India) — reliability 6.4/10, 74% on-time rate |
| Carbon waste leader | Air shipments account for >90% of avoidable CO2 despite lowest shipment count |

---

## ⚙️ How to Run

### Prerequisites
- PostgreSQL 13+ (recommended) or any SQL-compatible database
- psql CLI or a GUI like DBeaver / TablePlus


## 🛠️ SQL Skills Demonstrated

- **Window Functions** — `RANK()`, `STDDEV()` over partitions
- **CTEs** — multi-step, chained common table expressions
- **Conditional Aggregation** — `SUM(CASE WHEN ... END)`
- **Numeric Formulas** — CO2 calculations, composite scoring
- **Multi-table JOINs** — up to 5-way joins across normalized schema
- **NULLIF / COALESCE** — safe division and null handling
- **CASE statements** — classification, grading, recommendations
- **Reusable Views** — abstracted logic for downstream reporting

---

