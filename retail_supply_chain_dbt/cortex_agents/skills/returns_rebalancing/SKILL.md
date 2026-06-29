---
name: returns-rebalancing
description: >
  Use for ALL requests involving return analysis, disposition decisions, rebalancing
  recommendations, or "what to do with returns." Identifies returned SKUs, evaluates
  inventory positions, matches against demand, calculates transfer economics, and
  produces a disposition recommendation (RESTOCK, TRANSFER, or LIQUIDATE).
  DO NOT handle returns-driven rebalancing without this skill.
  Triggers: analyze returns, rebalance inventory, disposition decisions, returned
  SKUs, pending returns, what should we do with returns, optimize return placement,
  returns-driven rebalancing, transfer returned inventory.
---

# Returns-Driven Inventory Rebalancing
---

## When to Trigger

Activate for ANY of:
- Analyzing returned inventory for rebalancing opportunities
- Deciding what to do with returned products (restock, transfer, liquidate)
- Finding where returned items should be sent based on demand
- Evaluating cost-effectiveness of transferring returned goods
- "Which returns should be rebalanced?"
- "What should we do with returned SKU X?"
- "Analyze pending returns for my region/location"

Do NOT use for: simple stock queries, order history lookups, or financial questions without a returns context.

## Workflow

### Step 1: Analyze Return Inflow

**Goal**: Identify return volumes by SKU and receiving location.

**Action**: Use `query_orders` with the `current_return_inflow` metric to pull aggregated return inflow, grouped by SKU and receiving location.

**Outcome**: SKU, units returned (inflow), receiving location, item condition.

If user specified SKUs, filter to those. Otherwise, surface top 5-10 by inflow volume.

**⚠️ STOP if user did not specify SKUs**: Present the top candidates by return volume across all sales channels so far and confirm scope before proceeding.

### Step 2: Assess Current Inventory Levels Across Locations Without Returns

**Goal**: Understand current stock position at all locations for the identified SKUs, including returned units that are sellable.

**Action**: Use `query_inventory` for each SKU across all locations. 

Calculate adjusted position per SKU per location:
```
adjusted_available = quantity_on_hand - quantity_reserved
```

Classify each location using `adjusted_available`:
- **Overstocked**: adjusted_available > 2× reorder point
- **Adequately stocked**: reorder point ≤ adjusted_available ≤ 2× reorder point
- **Understocked**: adjusted_available < reorder point
- **Out-of-stock**: adjusted_available = 0

**Output**: per sku per location get quantity on hand, quantity reserved, available quantity (adjusted_available metric), reorder point, capacity units (location-level max storage), location classification label.

### Step 3: Match Against Demand Signals

**Goal**: Identify where the returned SKUs are actually needed.

**Action**: Use `query_orders` to pull open/forecasted orders by fulfillment location for the identified SKUs. Filter out any forecasts with confidence level below 60%.

Calculate: `demand_signal = open_orders + forecasted_units`

Rank candidate destinations by demand_signal, excluding locations already well-stocked (from Step 2).

**Output**: for each sku and location get open order quantity, forecasted demand (next 30 days, confidence ≥ 0.6 only), fulfillment location.

**If `query_orders` returns no data**: State that no forward demand signal is available and recommend RESTOCK at current location or LIQUIDATE based on condition.

### Step 4: Calculate Transfer Economics

**Goal**: Determine whether transferring returned goods is financially justified.

**Action**: Use `query_finance` for each viable SKU-destination pair to retrieve costs and pricing. Use `query_inventory` for product weight (needed for weight-based shipping calculation).

Calculate per route:
```
transfer_cost = (cost_per_unit + cost_per_kg * unit_weight_kg) * quantity
margin_at_destination = selling_price - COGS
margin_uplift = margin_at_destination - liquidation_value
net_benefit = (margin_uplift * quantity) - transfer_cost
```

**Output**:

from `query_finance`
- COGS, selling price (by channel), liquidation value
- Shipping cost per route: cost_per_unit, cost_per_kg, transit_days

from `query_inventory`:
- unit_weight_kg

**Why each signal matters:**
- **transfer_cost**: The direct cost to move goods — must be exceeded by margin uplift for a transfer to make sense.
- **margin_at_destination**: Revenue potential if restocked at the destination vs. liquidated.
- **margin_uplift**: The incremental value of selling at full price vs. liquidating — this is the core TRANSFER vs. LIQUIDATE decision metric.
- **net_benefit**: Final economic answer after accounting for shipping. Negative = transfer destroys value.

**If `query_finance` returns incomplete data**: State what's missing rather than guessing. Proceed only with available signals.

### Step 5: Determine Optimal Disposition

**Goal**: Assign each SKU batch to RESTOCK, TRANSFER, or LIQUIDATE.

Apply the following checks **in order**. Stop at the first match — each check is mandatory and sequential:

| # | Check | Disposition | Rationale |
|---|-------|-------------|-----------|
| 1 | item_condition NOT IN ('NEW', 'LIKE_NEW') | LIQUIDATE | Only good-condition items are worth restocking or transferring |
| 2 | No demand signal for this SKU at any location (Step 3 returned zero) | LIQUIDATE | No path to full-price sale anywhere in the network |
| 3 | Local (receiving) location has demand_signal > 0 AND is classified as understocked or out-of-stock (Step 2) | RESTOCK | Cheapest path to sale — no shipping cost, immediate availability |
| 4 | net_benefit > 0 AND margin_uplift > transfer_cost (Step 4) | TRANSFER | Send to the closest location with demand_signal > 40% of the highest demand_signal across all locations |
| 5 | None of the above conditions met | LIQUIDATE | Transfer economics are unfavorable — recover value via liquidation channel |

For TRANSFER: select the destination with the shortest transit_days among locations whose demand_signal exceeds 40% of the max demand_signal and where net_benefit > 0.

### Step 6: Present Recommendation

**Goal**: Deliver actionable disposition plan for approval.

Present all SKUs in a single table:

| SKU | Disposition | Qty | Current Location | Target Location | Rationale |
|-----|-------------|-----|------------------|-----------------|-----------|
| SKU-E001 | RESTOCK | 25 | LOC-003 | LOC-003 (same) | Local demand signal 120 units, location understocked |
| SKU-A002 | TRANSFER | 40 | LOC-003 | LOC-001 | Closest location with demand > 40% of peak, net benefit $320 |
| SKU-H005 | LIQUIDATE | 12 | LOC-004 | — | — |

For RESTOCK and TRANSFER rows, always populate Target Location and Rationale. For LIQUIDATE rows, leave Target Location and Rationale as "—".

**⚠️ MANDATORY STOP**: Present the full recommendation. Do NOT proceed to execution without explicit user approval.

### Step 7: Execute

After user approves:
- Use `trigger_disposition_action` with action_type='REBALANCE' for TRANSFER dispositions
- Use `trigger_disposition_action` with action_type='LIQUIDATE' for LIQUIDATE dispositions

## Stopping Points

- ✋ After Step 1: if user didn't specify SKUs, confirm scope. For multi-SKU analyses, process top 5-10 by volume unless user specifies otherwise
- ✋ After Step 6: present recommendation, await approval before execution

## Constraints

- If data is insufficient for a decision, state what's missing rather than guessing
- If a query fails (e.g., table not found, permission denied), do NOT proceed — inform the user and stop.