-- =============================================================================
-- deploy_eval_dataset.sql
-- Creates and populates the evaluation dataset table for the Inventory
-- Rebalancing Cortex Agent in Snowflake Agent Evaluations format.
--
-- Target agent: RETAIL_SUPPLY_CHAIN_DB.AGENT.RETAIL_OPS_AGENT
--
-- This script creates:
--   1. The evaluation dataset table with correct column types
--   2. Inserts test cases with PARSE_JSON ground truth (1 simple, 1 moderate,
--      1 complex per skill type)
--   3. Verifies the dataset with a summary query
--
-- Execution:
--   snow sql -f eval/deploy_eval_dataset.sql
--   OR paste into a Snowflake worksheet and run
-- =============================================================================

USE DATABASE RETAIL_SUPPLY_CHAIN_DB;
USE SCHEMA AGENT;

-- #############################################################################
-- SECTION 1: Create Evaluation Dataset Table
-- #############################################################################

CREATE OR REPLACE TABLE RETAIL_SUPPLY_CHAIN_DB.AGENT.RETAIL_OPS_AGENT_EVAL_DATASET (
    input_query     VARCHAR       COMMENT 'The question/prompt to send to the agent',
    ground_truth    VARIANT       COMMENT 'JSON with ground_truth_output, expected_skill, skill_indicators, and ground_truth_invocations',
    track           VARCHAR(10)   COMMENT 'ac (answer correctness) or tea (tool execution accuracy)',
    category        VARCHAR(30)   COMMENT 'Test category: stockout_risk, returns_rebalancing, cross_domain, general_query',
    difficulty      VARCHAR(10)   COMMENT 'simple, moderate, or complex',
    eval_id         NUMBER        COMMENT 'Test case identifier'
);

-- #############################################################################
-- SECTION 2: Insert Evaluation Data
-- 7 rows: 1 simple + 1 moderate + 1 complex per skill, plus 1 cross-domain
-- #############################################################################

-- --------------------------------------------------------------------------
-- 1: general_query / simple — basic inventory lookup (no skill needed)
-- --------------------------------------------------------------------------
INSERT INTO RETAIL_SUPPLY_CHAIN_DB.AGENT.RETAIL_OPS_AGENT_EVAL_DATASET
    (input_query, ground_truth, track, category, difficulty, eval_id)
SELECT
    'What''s the current stock level at LOC-001?',
    PARSE_JSON('{
        "ground_truth_output": "Stock quantities by SKU at LOC-001. No code_execution or skill needed.",
        "expected_skill": null,
        "skill_indicators": [],
        "ground_truth_invocations": [
            {"tool_name": "query_inventory", "tool_input": "Query stock levels filtered to LOC-001, return current quantities by SKU"}
        ]
    }'),
    'tea',
    'general_query',
    'simple',
    1;

-- --------------------------------------------------------------------------
-- 2: stockout_risk / moderate — stockout_risk_prioritization skill
-- --------------------------------------------------------------------------
INSERT INTO RETAIL_SUPPLY_CHAIN_DB.AGENT.RETAIL_OPS_AGENT_EVAL_DATASET
    (input_query, ground_truth, track, category, difficulty, eval_id)
SELECT
    'What''s the stockout risk for electronics SKUs at LOC-001?',
    PARSE_JSON('{
        "ground_truth_output": "P(stockout) per electronics SKU at LOC-001 via compute_stockout_probability() directly, not the full workflow.",
        "expected_skill": null,
        "skill_indicators": [],
        "ground_truth_invocations": [
            {"tool_name": "query_inventory", "tool_input": "Filter inventory to electronics category at LOC-001, retrieve available_stock and lead_time_days"},
            {"tool_name": "query_orders", "tool_input": "Retrieve daily demand history for electronics SKUs at LOC-001 to derive daily_demand_mean and daily_demand_std"},
            {"tool_name": "code_execution", "tool_input": "Call stockout_risk.compute_stockout_probability() for each electronics SKU at LOC-001"}
        ]
    }'),
    'tea',
    'stockout_risk',
    'moderate',
    2;

-- --------------------------------------------------------------------------
-- 3: stockout_risk / complex — stockout_risk_prioritization skill
-- --------------------------------------------------------------------------
INSERT INTO RETAIL_SUPPLY_CHAIN_DB.AGENT.RETAIL_OPS_AGENT_EVAL_DATASET
    (input_query, ground_truth, track, category, difficulty, eval_id)
SELECT
    'Which SKUs should I prioritize for reorder this week?',
    PARSE_JSON('{
        "ground_truth_output": "Ranked reorder list by expected stockout cost, using P(stockout), margin, and demand via code_execution.",
        "expected_skill": "stockout_risk_prioritization",
        "skill_indicators": [
            "Filters at-risk SKUs where available_stock / reorder_point <= 1.5",
            "Computes net_margin from COGS, selling_price, return_rate",
            "Calculates committed_demand from open orders + forecast",
            "Derives daily_demand_mean, daily_demand_std, carrying_cost_per_unit_per_day",
            "Calls stockout_risk.compute_stockout_risk() via code_execution",
            "Presents ranked table with action classification"
        ],
        "ground_truth_invocations": [
            {"tool_name": "query_inventory", "tool_input": "Retrieve current stock levels and reorder points for all SKUs"},
            {"tool_name": "query_orders", "tool_input": "Fetch demand history and open orders across all locations"},
            {"tool_name": "code_execution", "tool_input": "Calculate P(stockout) during lead time and rank SKUs by expected cost of stockout"}
        ]
    }'),
    'tea',
    'stockout_risk',
    'complex',
    3;

-- --------------------------------------------------------------------------
-- 4: general_query / simple — basic returns trend (no skill needed)
-- --------------------------------------------------------------------------
INSERT INTO RETAIL_SUPPLY_CHAIN_DB.AGENT.RETAIL_OPS_AGENT_EVAL_DATASET
    (input_query, ground_truth, track, category, difficulty, eval_id)
SELECT
    'Show me the return rate trend for the last 30 days',
    PARSE_JSON('{
        "ground_truth_output": "Time-series chart of daily return rates over 30 days.",
        "expected_skill": null,
        "skill_indicators": [],
        "ground_truth_invocations": [
            {"tool_name": "query_orders", "tool_input": "Query order and return data for the last 30 days to calculate daily return rates"},
            {"tool_name": "data_to_chart", "tool_input": "Produce a time-series visualization of daily return rate trend over 30 days"}
        ]
    }'),
    'tea',
    'general_query',
    'simple',
    4;

-- --------------------------------------------------------------------------
-- 5: returns_rebalancing / moderate — returns_rebalancing skill
-- --------------------------------------------------------------------------
INSERT INTO RETAIL_SUPPLY_CHAIN_DB.AGENT.RETAIL_OPS_AGENT_EVAL_DATASET
    (input_query, ground_truth, track, category, difficulty, eval_id)
SELECT
    'What should we do with the returned SKU-E001 units at LOC-003?',
    PARSE_JSON('{
        "ground_truth_output": "Disposition recommendation for SKU-E001 at LOC-003 with dollar-value comparison of restock vs transfer vs liquidate.",
        "expected_skill": "returns_rebalancing",
        "skill_indicators": [
            "Gets return inflow for SKU-E001 at LOC-003 with item condition",
            "Classifies stock position across locations",
            "Matches demand signals at candidate destinations",
            "Calculates transfer economics (transfer_cost, margin_uplift, net_benefit)",
            "Applies disposition logic (condition, demand, restock, transfer, liquidate)",
            "Presents recommendation with target location and rationale"
        ],
        "ground_truth_invocations": [
            {"tool_name": "query_returns", "tool_input": "Retrieve return details for SKU-E001 at LOC-003"},
            {"tool_name": "query_inventory", "tool_input": "Check local demand and stock for SKU-E001 at LOC-003 and other locations"},
            {"tool_name": "query_finance", "tool_input": "Get unit cost and margin for SKU-E001"},
            {"tool_name": "code_execution", "tool_input": "Calculate restock value vs transfer cost vs liquidation value, recommend optimal disposition with dollar amounts"}
        ]
    }'),
    'tea',
    'returns_rebalancing',
    'moderate',
    5;

-- --------------------------------------------------------------------------
-- 6: returns_rebalancing / complex — returns_rebalancing skill
-- --------------------------------------------------------------------------
INSERT INTO RETAIL_SUPPLY_CHAIN_DB.AGENT.RETAIL_OPS_AGENT_EVAL_DATASET
    (input_query, ground_truth, track, category, difficulty, eval_id)
SELECT
    'Analyze pending returns and recommend dispositions',
    PARSE_JSON('{
        "ground_truth_output": "Disposition table per return batch (restock/transfer/liquidate) with net_benefit and total recovery value.",
        "expected_skill": "returns_rebalancing",
        "skill_indicators": [
            "Aggregates return inflow by SKU and location with condition",
            "Classifies stock position across all locations",
            "Matches demand signals, filtering forecasts to confidence >= 0.6",
            "Calculates transfer economics (transfer_cost, margin_uplift, net_benefit)",
            "Applies disposition logic (condition, demand, restock, transfer, liquidate)",
            "Presents disposition table with target location and rationale"
        ],
        "ground_truth_invocations": [
            {"tool_name": "query_returns", "tool_input": "Retrieve all pending returns with condition data"},
            {"tool_name": "query_inventory", "tool_input": "Check demand signals at potential destination locations"},
            {"tool_name": "query_finance", "tool_input": "Get cost and margin data for disposition economics"},
            {"tool_name": "code_execution", "tool_input": "Calculate transfer cost vs restock value, apply disposition logic (restock/transfer/liquidate), compute net benefit per return batch"}
        ]
    }'),
    'tea',
    'returns_rebalancing',
    'complex',
    6;

-- --------------------------------------------------------------------------
-- 7: cross_domain / complex — both skills
-- --------------------------------------------------------------------------
-- INSERT INTO RETAIL_SUPPLY_CHAIN_DB.AGENT.RETAIL_OPS_AGENT_EVAL_DATASET
--     (input_query, ground_truth, track, category, difficulty, eval_id)
-- SELECT
--     'I need a complete inventory action plan: which items to reorder urgently AND which returns to rebalance',
--     PARSE_JSON('{
--         "ground_truth_output": "A unified action plan covering both reorder prioritization (ranked by P(stockout) and expected cost) and return disposition recommendations (restock/transfer/liquidate). Uses code_execution for probability calculation and addresses both domains.",
--         "expected_skill": "stockout_risk_prioritization+returns_rebalancing",
--         "skill_indicators": [
--             "Identifies at-risk SKUs by reorder point ratio filter",
--             "Computes net margin from COGS, selling_price, and return_rate",
--             "Derives demand statistics and carrying cost from order history",
--             "Uses code_execution to call stockout_risk.compute_stockout_risk() and rank by expected cost",
--             "Presents ranked replenishment table with action classification",
--             "Analyzes return inflow by SKU and location with item condition",
--             "Assesses inventory levels and classifies stock position across locations",
--             "Matches returned SKUs against demand signals at candidate destinations",
--             "Calculates transfer economics (net_benefit) for viable routes",
--             "Applies disposition logic and presents recommendation table"
--         ],
--         "ground_truth_invocations": [
--             {"tool_name": "query_inventory", "tool_input": "Get current stock levels, reorder points, and demand signals"},
--             {"tool_name": "query_orders", "tool_input": "Retrieve demand history and open orders for stockout calculation"},
--             {"tool_name": "query_returns", "tool_input": "Get pending returns with condition data for disposition"},
--             {"tool_name": "query_finance", "tool_input": "Get margins and cost data for economic ranking"},
--             {"tool_name": "code_execution", "tool_input": "Calculate P(stockout) for reorder ranking and disposition cost-benefit for returns, produce combined action plan"}
--         ]
--     }'),
--     'tea',
--     'cross_domain',
--     'complex',
--     7;

-- #############################################################################
-- SECTION 3: Verify the dataset
-- #############################################################################

-- SELECT
--     eval_id,
--     category,
--     difficulty,
--     ground_truth:"expected_skill"::VARCHAR AS expected_skill
-- FROM RETAIL_SUPPLY_CHAIN_DB.AGENT.RETAIL_OPS_AGENT_EVAL_DATASET
-- ORDER BY eval_id;
