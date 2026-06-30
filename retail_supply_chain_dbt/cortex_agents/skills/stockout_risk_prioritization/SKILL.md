---
name: stockout-risk-prioritization
description: >
  Use for requests requiring a PRIORITIZED replenishment list combining
  stockout probability, expected cost, AND action classification to rank SKUs.
  DO NOT run the full workflow for isolated metric queries — call functions directly.
  Triggers: reorder priority, replenishment list, which SKUs to reorder,
  risk-ranked inventory, margin-weighted replenishment, prioritize reorders,
  ranked replenishment, reorder decision list.
---

# Margin-Aware Stockout Risk Prioritization

Do NOT use for: returns-driven rebalancing (`returns_rebalancing`), simple stock level queries, or financial lookups without replenishment context.

## When NOT to Run the Full Workflow

For single-SKU or non-ranking queries, call functions from `stockout_risk.py` directly via `code_execution`. Gather only the inputs needed for that SKU from `query_inventory`, `query_orders`, `query_finance`.

| User intent | Function |
|-------------|----------|
| P(stockout) for a SKU | `compute_stockout_probability(available_stock, daily_demand_mean, daily_demand_std, lead_time_days)` |
| Cost exposure for a SKU | `compute_expected_cost(p_stockout, net_margin, committed_demand, available_stock, daily_demand_mean, lead_time_days, carrying_cost_per_unit_per_day)` |
| Should I reorder this SKU? | `classify_action(p_stockout, expected_cost)` |

- "Stockout risk across my warehouse" without ranking → compute probabilities, present as list. Do NOT classify or rank.

## Full Prioritization Workflow

Run ONLY when the user wants a ranked replenishment list.

### Step 1: Identify At-Risk SKUs

`query_inventory` → SKU, location_id, location_name, quantity_on_hand, quantity_reserved, reorder_point, lead_time_days.

Filter: `(quantity_on_hand - quantity_reserved) / reorder_point <= 1.5`

**⚠️ STOP if results > 20**: Ask user to narrow scope.

### Step 2: Compute Net Margin

`query_finance` → COGS, selling_price. `query_orders` → return_rate.

```
net_margin = (selling_price - COGS) * (1 - return_rate)
```

### Step 3: Committed Demand

`query_orders` → open orders + demand forecast (confidence ≥ 0.6, next 30 days).

```
committed_demand = open_order_quantity + forecasted_demand
```

### Step 4: Demand Statistics & Carrying Cost

- `query_inventory` → `lead_time_days` (from `INVENTORY_SV` / `PRODUCTS` table)
- `query_orders` → daily order quantities (last 90 days) → derive `daily_demand_mean`, `daily_demand_std`
- `carrying_cost_per_unit_per_day = COGS * 0.25 / 365` (default when not available from `query_finance`)

### Step 5: Compute & Rank — CODE EXECUTION

Assemble DataFrame `sku_data` (one row per at-risk SKU-location):

| Column | Source |
|--------|--------|
| sku, location, available_stock | Step 1 |
| lead_time_days | Step 1 / Step 4 |
| daily_demand_mean, daily_demand_std | Step 4 |
| net_margin | Step 2 |
| committed_demand | Step 3 |
| carrying_cost_per_unit_per_day | Step 4 |

```python
import stockout_risk

priority_df = stockout_risk.compute_stockout_risk(sku_data)
stockout_risk.print_summary(priority_df)
```

Do NOT write custom calculation code. If the script fails, STOP and report the error.

### Step 6: Present Results

**⚠️ MANDATORY STOP**: Present ranked table and summary. Ask area managers whether to proceed with reorders for URGENT items.

Action thresholds (for reference — computed by the script):
- **URGENT REORDER**: P(stockout) > 70% OR expected_cost > $3,000
- **REORDER**: P(stockout) > 40% OR expected_cost > $1,000
- **MONITOR**: P(stockout) > 20%
- **OK**: P(stockout) ≤ 20%

## Constraints

- Demand history < 30 days → note caveat, continue with available data
- Missing lead_time_days → use category average, note assumption
- State in output: P(stockout) assumes normally distributed demand

## Output

Ranked replenishment table with P(stockout), expected cost, action per SKU-location. Summary: total at-risk SKUs, total cost exposure, average service level.
