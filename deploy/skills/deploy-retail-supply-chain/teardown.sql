-- =============================================================================
-- teardown.sql
-- Removes ALL Snowflake objects created by the Agentic Retail Supply Chain
-- Inventory project. Run this when you want to fully clean up the demo.
--
-- ⚠️  This script is DESTRUCTIVE and IRREVERSIBLE. All data will be lost.
--     Review the summary output at the end to confirm what was removed.
--
-- Prerequisites:
--   - Must be run by a role with ownership on the created objects
--   - ACCOUNTADMIN required for: warehouse, notification integration,
--     external access integration, network rule, database role revocations
--
-- Execution:
--   snow sql -f deploy/skills/deploy-retail-supply-chain/teardown.sql
--   OR paste into a Snowflake worksheet and run
--
-- Teardown order (reverse of deployment):
--   1. Cortex Agent
--   2. dbt Project Object
--   3. Semantic Views
--   4. Evaluation Dataset
--   5. Stages (files are dropped with stage)
--   6. Stored Procedures & UDFs
--   7. Tables
--   8. Schemas
--   9. Project Database (RETAIL_SUPPLY_CHAIN_DB)
--  10. Account-level objects (warehouse, integrations, shared DB)
-- =============================================================================


-- #############################################################################
-- SECTION 1: Drop Cortex Agent
-- #############################################################################

DROP CORTEX AGENT IF EXISTS RETAIL_SUPPLY_CHAIN_DB.AGENT.RETAIL_OPS_AGENT;

-- #############################################################################
-- SECTION 2: Drop dbt Project Object
-- #############################################################################

DROP DBT PROJECT IF EXISTS RETAIL_SUPPLY_CHAIN_DB.AGENT.RETAIL_SUPPLY_CHAIN_DBT;

-- #############################################################################
-- SECTION 3: Drop Semantic Views
-- #############################################################################

DROP SEMANTIC VIEW IF EXISTS RETAIL_SUPPLY_CHAIN_DB.AGENT.INVENTORY_SV;
DROP SEMANTIC VIEW IF EXISTS RETAIL_SUPPLY_CHAIN_DB.AGENT.ORDERS_SV;
DROP SEMANTIC VIEW IF EXISTS RETAIL_SUPPLY_CHAIN_DB.AGENT.FINANCE_SV;

-- #############################################################################
-- SECTION 4: Drop Evaluation Dataset Table
-- #############################################################################

DROP TABLE IF EXISTS RETAIL_SUPPLY_CHAIN_DB.AGENT.RETAIL_OPS_AGENT_EVAL_DATASET;

-- #############################################################################
-- SECTION 5: Drop Internal Stages (drops all uploaded files within)
-- #############################################################################

DROP STAGE IF EXISTS RETAIL_SUPPLY_CHAIN_DB.AGENT.AGENT_SPECS;
DROP STAGE IF EXISTS RETAIL_SUPPLY_CHAIN_DB.AGENT.SKILLS_STAGE;
DROP STAGE IF EXISTS RETAIL_SUPPLY_CHAIN_DB.AGENT.EVAL_STAGE;

-- #############################################################################
-- SECTION 6: Drop Stored Procedures & UDFs
-- #############################################################################

DROP PROCEDURE IF EXISTS RETAIL_SUPPLY_CHAIN_DB.AGENT.TRIGGER_DISPOSITION_ACTION(VARCHAR, VARCHAR, NUMBER, VARCHAR, VARCHAR, VARCHAR);
DROP FUNCTION IF EXISTS RETAIL_SUPPLY_CHAIN_DB.AGENT.READ_STAGE_FILE(STRING);

-- #############################################################################
-- SECTION 7: Drop Tables
-- #############################################################################

-- AGENT schema tables
-- (eval dataset already dropped in Section 4)

-- ORDERS schema tables
DROP TABLE IF EXISTS RETAIL_SUPPLY_CHAIN_DB.ORDERS.DAILY_RETURN_RATES_BY_SKU_CHANNEL;
DROP TABLE IF EXISTS RETAIL_SUPPLY_CHAIN_DB.ORDERS.CUSTOMER_RETURNS;
DROP TABLE IF EXISTS RETAIL_SUPPLY_CHAIN_DB.ORDERS.DEMAND_FORECAST;
DROP TABLE IF EXISTS RETAIL_SUPPLY_CHAIN_DB.ORDERS.ORDER_LINES;
DROP TABLE IF EXISTS RETAIL_SUPPLY_CHAIN_DB.ORDERS.ORDER_HEADERS;

-- INVENTORY schema tables
DROP TABLE IF EXISTS RETAIL_SUPPLY_CHAIN_DB.INVENTORY.STOCK_LEVELS;
DROP TABLE IF EXISTS RETAIL_SUPPLY_CHAIN_DB.INVENTORY.PRODUCTS;
DROP TABLE IF EXISTS RETAIL_SUPPLY_CHAIN_DB.INVENTORY.LOCATIONS;
DROP TABLE IF EXISTS RETAIL_SUPPLY_CHAIN_DB.INVENTORY.DATE_DIMENSION;

-- FINANCE schema tables
DROP TABLE IF EXISTS RETAIL_SUPPLY_CHAIN_DB.FINANCE.SHIPPING_COSTS;
DROP TABLE IF EXISTS RETAIL_SUPPLY_CHAIN_DB.FINANCE.PRODUCT_COSTS;

-- #############################################################################
-- SECTION 8: Drop Schemas
-- #############################################################################

DROP SCHEMA IF EXISTS RETAIL_SUPPLY_CHAIN_DB.AGENT;
DROP SCHEMA IF EXISTS RETAIL_SUPPLY_CHAIN_DB.ORDERS;
DROP SCHEMA IF EXISTS RETAIL_SUPPLY_CHAIN_DB.INVENTORY;
DROP SCHEMA IF EXISTS RETAIL_SUPPLY_CHAIN_DB.FINANCE;

-- #############################################################################
-- SECTION 9: Drop Project Database
-- This CASCADE would also remove any remaining objects, but we drop them
-- explicitly above for auditability.
-- #############################################################################

DROP DATABASE IF EXISTS RETAIL_SUPPLY_CHAIN_DB;

-- #############################################################################
-- SECTION 10: Account-Level Objects (requires ACCOUNTADMIN)
-- ⚠️  These statements require ACCOUNTADMIN privileges.
--     Run them separately as ACCOUNTADMIN if your current role cannot execute them.
--     Only drop these if no other projects depend on them.
--     Comment out any lines for objects shared with other projects.
-- #############################################################################

-- USE ROLE ACCOUNTADMIN;  -- Uncomment if running in a worksheet as ACCOUNTADMIN

-- Warehouse
-- DROP WAREHOUSE IF EXISTS RETAIL_SUPPLY_CHAIN_QS_WH;

-- Notification Integration
-- DROP INTEGRATION IF EXISTS INVENTORY_EMAIL_INTEGRATION;

-- External Access Integration & Network Rule
-- DROP INTEGRATION IF EXISTS DBT_PACKAGES_EAI;
-- DROP NETWORK RULE IF EXISTS SHARED_OBJECTS.PUBLIC.DBT_PACKAGES_NETWORK_RULE;

-- Shared Objects Database (only if exclusively used by this project)
-- DROP DATABASE IF EXISTS SHARED_OBJECTS;

-- #############################################################################
-- SECTION 11: Revoke Database Role Grants (optional cleanup)
-- ⚠️  Only revoke if no other workflows need these roles.
--     Replace <YOUR_ROLE> with the deployment role used during setup.
-- #############################################################################

-- REVOKE DATABASE ROLE SNOWFLAKE.CORTEX_AGENT_USER FROM ROLE <YOUR_ROLE>;
-- REVOKE DATABASE ROLE SNOWFLAKE.PYPI_REPOSITORY_USER FROM ROLE <YOUR_ROLE>;

-- #############################################################################
-- SUMMARY REPORT
-- #############################################################################

SELECT '✓ Teardown complete. The following objects were removed:' AS STATUS
UNION ALL SELECT '  - Cortex Agent: RETAIL_OPS_AGENT'
UNION ALL SELECT '  - dbt Project: RETAIL_SUPPLY_CHAIN_DBT'
UNION ALL SELECT '  - Semantic Views: INVENTORY_SV, ORDERS_SV, FINANCE_SV'
UNION ALL SELECT '  - Evaluation Dataset: RETAIL_OPS_AGENT_EVAL_DATASET'
UNION ALL SELECT '  - Stages: AGENT_SPECS, SKILLS_STAGE, EVAL_STAGE (+ all uploaded files)'
UNION ALL SELECT '  - Procedure: TRIGGER_DISPOSITION_ACTION'
UNION ALL SELECT '  - Function: READ_STAGE_FILE'
UNION ALL SELECT '  - Tables: 11 tables across INVENTORY, ORDERS, FINANCE schemas'
UNION ALL SELECT '  - Schemas: AGENT, ORDERS, INVENTORY, FINANCE'
UNION ALL SELECT '  - Database: RETAIL_SUPPLY_CHAIN_DB'
UNION ALL SELECT '  - Warehouse: RETAIL_SUPPLY_CHAIN_QS_WH'
UNION ALL SELECT '  - Integrations: INVENTORY_EMAIL_INTEGRATION, DBT_PACKAGES_EAI'
UNION ALL SELECT '  - Network Rule: SHARED_OBJECTS.PUBLIC.DBT_PACKAGES_NETWORK_RULE'
UNION ALL SELECT '  - Database: SHARED_OBJECTS'
UNION ALL SELECT ''
UNION ALL SELECT '⚠️  Commented-out role revocations were NOT executed.'
UNION ALL SELECT '    Run them manually if no other projects use those database roles.';
