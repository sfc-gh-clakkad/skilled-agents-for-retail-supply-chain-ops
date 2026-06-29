-- =============================================================================
-- setup_prerequisites.sql
-- One-time account-level setup for the Agentic Retail Supply Chain project.
--
-- ⚠️  REQUIRES ACCOUNTADMIN privileges.
--     Run this ONCE before proceeding with the main deployment.
--     Safe to re-run — all statements use IF NOT EXISTS or OR REPLACE.
--
-- This script creates:
--   1. Account-level grants for the deployment role (CREATE DATABASE, warehouse)
--   2. Cortex Agent and PyPI database role grants
--   3. A notification integration for email-based disposition alerts
--   4. A network rule + external access integration for dbt package resolution
--   5. Grants USAGE on both integrations to the deployment role
--
-- After running this script, the deployment role can
-- execute the rest of the project setup without elevated privileges.
--
-- Execution:
--   snow sql -f deploy/setup_prerequisites.sql
--   OR paste into a Snowflake worksheet and run as ACCOUNTADMIN
-- =============================================================================

USE ROLE ACCOUNTADMIN;

-- #############################################################################
-- SECTION 1: Account-Level Privileges for Deployment Role
-- These allow the deployment role to create the project database and use
-- compute. One-time grants that persist across deployments.
-- ⚠️  Replace <YOUR_ROLE> below with your deployment role name.
-- #############################################################################

GRANT CREATE DATABASE ON ACCOUNT TO ROLE <YOUR_ROLE>;

CREATE OR REPLACE WAREHOUSE RETAIL_SUPPLY_CHAIN_QS_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  COMMENT = 'XSmall warehouse for the Retail Supply Chain quickstart';

GRANT USAGE ON WAREHOUSE RETAIL_SUPPLY_CHAIN_QS_WH TO ROLE <YOUR_ROLE>;

-- Cortex Agent and PyPI access (required for agent creation + Python UDFs)
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_AGENT_USER TO ROLE <YOUR_ROLE>;
GRANT DATABASE ROLE SNOWFLAKE.PYPI_REPOSITORY_USER TO ROLE <YOUR_ROLE>;

-- #############################################################################
-- SECTION 2: Email Notification Integration
-- Used by TRIGGER_DISPOSITION_ACTION procedure to send rebalance/liquidation
-- notification emails via SYSTEM$SEND_EMAIL.
-- #############################################################################

CREATE OR REPLACE NOTIFICATION INTEGRATION INVENTORY_EMAIL_INTEGRATION
  TYPE = EMAIL
  ENABLED = TRUE
  COMMENT = 'Email notification integration for inventory disposition alerts (rebalance/liquidate)';

-- #############################################################################
-- SECTION 3: External Access Integration for dbt Package Resolution
-- The dbt project uses the Snowflake-Labs/dbt_semantic_view package from the
-- dbt hub. When deployed as a Snowflake-native dbt project (via snow dbt deploy),
-- Snowflake needs network egress to resolve this dependency.
-- #############################################################################

CREATE OR REPLACE NETWORK RULE DBT_PACKAGES_NETWORK_RULE
  MODE = EGRESS
  TYPE = HOST_PORT
  VALUE_LIST = (
    'hub.getdbt.com',
    'codeload.github.com'
  )
  COMMENT = 'Allows dbt deps to fetch packages from dbt hub and GitHub';

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION DBT_PACKAGES_EAI
  ALLOWED_NETWORK_RULES = (DBT_PACKAGES_NETWORK_RULE)
  ENABLED = TRUE
  COMMENT = 'EAI for dbt package resolution (dbt_semantic_view from hub.getdbt.com)';

-- #############################################################################
-- SECTION 4: Grant Usage to Deployment Role
-- Replace <YOUR_ROLE> with your deployment role if different.
-- #############################################################################

GRANT USAGE ON INTEGRATION INVENTORY_EMAIL_INTEGRATION TO ROLE <YOUR_ROLE>;
GRANT USAGE ON INTEGRATION DBT_PACKAGES_EAI TO ROLE <YOUR_ROLE>;

-- =============================================================================
-- DONE. You can now proceed with:
--   snow sql -f deploy/project_scaffolding_deploy.sql
-- =============================================================================
