---
name: stockout-risk-prioritization
description: >
  Use for ALL requests involving stockout risk, replenishment prioritization,
  reorder decisions, or "which SKUs should I reorder." Calculates probability
  of stockout during lead time using statistical models, scores by expected cost
  (lost margin × committed demand), and produces a margin-weighted priority list.
  DO NOT handle replenishment/reorder questions without this skill.
  Triggers: stockout risk, reorder priority, replenishment list, which SKUs to reorder,
  probability of stockout, risk-ranked inventory, reorder point analysis,
  margin-weighted replenishment, expected cost of stockout, service level optimization.
---

# Margin-Aware Stockout Risk Prioritization

Do NOT use for: returns-driven rebalancing (use `returns_rebalancing`), simple stock level queries, or financial lookups without a replenishment context.

## Workflow

### Step 1: Identify SKUs Approaching Reorder Point

Use `query_inventory` to pull: SKU, location_id, location_name, quantity_on_hand, quantity_reserved, reorder_point, lead_time_days.

Filter to rows where `(quantity_on_hand - quantity_reserved) / reorder_point <= 1.5`.

**⚠️ STOP if results > 20**: Ask user to narrow scope by category, location, or region before continuing.

### Step 2: Score by Margin

Use `query_finance` for COGS and selling_price per SKU/channel. Use `query_orders` for return_rate per SKU.

```
gross_margin = selling_price - COGS
net_margin   = gross_margin * (1 - return_rate)
```

### Step 3: Check Committed and Forecasted Demand

Use `query_orders` for open orders + demand forecast (confidence ≥ 0.6, next 30 days) per at-risk SKU-location.

```
committed_demand = open_order_quantity + forecasted_demand
```

### Step 4: Gather Lead Time Inputs

Use `query_inventory` to retrieve `lead_time_days` per SKU — this field is available in the `INVENTORY_SV` semantic view from the `PRODUCTS` table. Use `query_orders` for daily order quantities over the last 90 days to derive `daily_demand_mean` and `daily_demand_std`.

Compute: `carrying_cost_per_unit_per_day = COGS * 0.25 / 365` (use this default when a carrying cost rate is not explicitly available from `query_finance`).

### Step 5: Compute P(Stockout) and Rank — CODE EXECUTION

Assemble a DataFrame `sku_data` (one row per at-risk SKU-location) from Steps 1-4:

| Column | Source |
|--------|--------|
| sku | Step 1 |
| location | Step 1 |
| available_stock | Step 1: `quantity_on_hand - quantity_reserved` |
| lead_time_days | Step 1 / Step 4 |
| daily_demand_mean | Step 4 |
| daily_demand_std | Step 4 |
| net_margin | Step 2 |
| committed_demand | Step 3 |
| carrying_cost_per_unit_per_day | Step 4 |

Use `code_execution` to run the canonical `stockout_risk.py` script in this skill folder. You MUST use this script. Do NOT write new probability calculation code — the validated implementation already exists.

```python
import stockout_risk

priority_df = compute_stockout_risk(sku_data)
print_summary(priority_df)
```

If the script fails to load, STOP and report the error. Do NOT fall back to writing your own implementation.

### Step 6: Present Prioritized Replenishment List

Present as a ranked table:

| Rank | SKU | Location | P(Stockout) | Expected Cost | Net Margin | Committed Demand | Action |
|------|-----|----------|-------------|---------------|------------|------------------|--------|
| 1 | SKU-E001 | LOC-001 | 87.3% | $4,280 | $12.50 | 342 units | URGENT REORDER |
| 2 | SKU-A003 | LOC-002 | 64.1% | $2,150 | $8.75 | 245 units | REORDER |
| 3 | SKU-H002 | LOC-003 | 41.8% | $890 | $15.20 | 58 units | MONITOR |

Classification:
- **URGENT REORDER**: P(stockout) > 70% OR expected_cost > $3,000
- **REORDER**: P(stockout) > 40% OR expected_cost > $1,000
- **MONITOR**: P(stockout) > 20%
- **OK**: P(stockout) ≤ 20%

Include summary: total at-risk SKUs, total cost exposure, average service level.

**⚠️ MANDATORY STOP**: Present the full list. Ask area managers whether to proceed with reorders for URGENT items. Store managers receive results only.

## Constraints

- If demand history < 30 days, note the caveat and continue with available data
- If lead_time_days is missing for a SKU, use the category average and note the assumption
- P(stockout) assumes normally distributed demand — state this assumption in the output

## Output

Ranked replenishment table with P(stockout), expected cost of stockout, and action classification per SKU-location, plus summary statistics (total SKUs at risk, total cost exposure, average service level).
