-- =============================================================================
-- project_scaffolding_deploy.sql
-- Infrastructure provisioning for the Agentic Retail Supply Chain Inventory MVP.
-- Run this BEFORE seeding data or deploying the dbt project.
--
-- Single-role deployment: uses the caller's current role (must have
-- CREATE DATABASE ON ACCOUNT and USAGE ON a warehouse).
--
-- Execution Order:
--   1. Run this script (database + schema + tables + stages + UDF + procedure)
--   2. Run seed_source_data.sql (populate source tables)
--   3. Upload agent spec/skills to stage (PUT commands)
--   4. Run dbt (transformation model + semantic views + agent)
--
-- Execution:
--   snow sql -f deploy/project_scaffolding_deploy.sql
-- =============================================================================


-- #############################################################################
-- PART A: DATABASE & SCHEMA PROVISIONING
-- #############################################################################

USE WAREHOUSE RETAIL_SUPPLY_CHAIN_QS_WH;

-- =============================================================================
-- SECTION 1: Database & Schema Provisioning
-- =============================================================================

CREATE DATABASE IF NOT EXISTS RETAIL_SUPPLY_CHAIN_DB
  COMMENT = 'Agentic retail supply chain inventory – dbt models, semantic views, Cortex Agent';

USE DATABASE RETAIL_SUPPLY_CHAIN_DB;

-- Domain schemas aligned with dbt model folders
CREATE SCHEMA IF NOT EXISTS RETAIL_SUPPLY_CHAIN_DB.INVENTORY
  WITH MANAGED ACCESS
  COMMENT = 'Products, stock levels, and location master data';

CREATE SCHEMA IF NOT EXISTS RETAIL_SUPPLY_CHAIN_DB.ORDERS
  WITH MANAGED ACCESS
  COMMENT = 'Order headers, order lines, and demand forecasts';

CREATE SCHEMA IF NOT EXISTS RETAIL_SUPPLY_CHAIN_DB.FINANCE
  WITH MANAGED ACCESS
  COMMENT = 'Product costs, shipping costs, and disposition thresholds';

-- Cortex Agent objects (semantic views, agent definition, MCP server, stages)
CREATE SCHEMA IF NOT EXISTS RETAIL_SUPPLY_CHAIN_DB.AGENT
  WITH MANAGED ACCESS
  COMMENT = 'Cortex Agent configuration: semantic views, agent spec, MCP tools';


-- =============================================================================
-- SECTION 2: Account-Level Prerequisites (run once by an ACCOUNTADMIN)
-- The following objects must exist before this script runs:
--   CREATE NOTIFICATION INTEGRATION IF NOT EXISTS INVENTORY_EMAIL_INTEGRATION
--     TYPE = EMAIL ENABLED = TRUE;
--   GRANT USAGE ON INTEGRATION INVENTORY_EMAIL_INTEGRATION TO ROLE <your_role>;
-- =============================================================================

USE DATABASE RETAIL_SUPPLY_CHAIN_DB;

-- =============================================================================
-- SECTION 3: Source Table DDL
-- Tables are created empty; populated by seed_source_data.sql.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- INVENTORY schema tables
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS RETAIL_SUPPLY_CHAIN_DB.INVENTORY.LOCATIONS (
    LOCATION_ID     VARCHAR(10)   PRIMARY KEY,
    LOCATION_NAME   VARCHAR(100)  NOT NULL,
    LOCATION_TYPE   VARCHAR(30)   NOT NULL,
    REGION          VARCHAR(20)   NOT NULL,
    ADDRESS         VARCHAR(200),
    CAPACITY_UNITS  INTEGER       NOT NULL
);

CREATE TABLE IF NOT EXISTS RETAIL_SUPPLY_CHAIN_DB.INVENTORY.PRODUCTS (
    SKU              VARCHAR(20)    PRIMARY KEY,
    PRODUCT_NAME     VARCHAR(200)   NOT NULL,
    CATEGORY         VARCHAR(50)    NOT NULL,
    SUBCATEGORY      VARCHAR(50)    NOT NULL,
    UNIT_WEIGHT_KG   DECIMAL(6,2)   NOT NULL,
    LEAD_TIME_DAYS   INTEGER        NOT NULL COMMENT 'Supplier replenishment lead time in calendar days',
    CREATED_AT       TIMESTAMP_NTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP()
);

CREATE TABLE IF NOT EXISTS RETAIL_SUPPLY_CHAIN_DB.INVENTORY.STOCK_LEVELS (
    SKU                 VARCHAR(20)   NOT NULL,
    LOCATION_ID         VARCHAR(10)   NOT NULL,
    SNAPSHOT_DATE       DATE          NOT NULL DEFAULT CURRENT_DATE(),
    QUANTITY_ON_HAND    INTEGER       NOT NULL,
    QUANTITY_RESERVED   INTEGER       NOT NULL DEFAULT 0,
    BATCH_RECEIVED_DATE DATE,
    REORDER_POINT       INTEGER       NOT NULL,
    PRIMARY KEY (SKU, LOCATION_ID, SNAPSHOT_DATE)
);

CREATE TABLE IF NOT EXISTS RETAIL_SUPPLY_CHAIN_DB.INVENTORY.DATE_DIMENSION (
    DATE_KEY     DATE        PRIMARY KEY,
    DAY_OF_WEEK  INTEGER     NOT NULL,
    DAY_NAME     VARCHAR(10) NOT NULL,
    MONTH_NUM    INTEGER     NOT NULL,
    MONTH_NAME   VARCHAR(10) NOT NULL,
    QUARTER      INTEGER     NOT NULL,
    YEAR         INTEGER     NOT NULL,
    IS_WEEKEND   BOOLEAN     NOT NULL,
    IS_HOLIDAY   BOOLEAN     NOT NULL DEFAULT FALSE
);

-- ---------------------------------------------------------------------------
-- ORDERS schema tables
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS RETAIL_SUPPLY_CHAIN_DB.ORDERS.ORDER_HEADERS (
    ORDER_ID               VARCHAR(20)    PRIMARY KEY,
    CUSTOMER_ID            VARCHAR(20)    NOT NULL,
    ORDER_DATE             DATE           NOT NULL,
    ORDER_STATUS           VARCHAR(20)    NOT NULL,
    SALES_CHANNEL          VARCHAR(20)    NOT NULL,
    FULFILLMENT_LOCATION_ID VARCHAR(10)   NOT NULL,
    TOTAL_AMOUNT           DECIMAL(12,2)  NOT NULL,
    SHIPPING_METHOD        VARCHAR(20)    NOT NULL
);

CREATE TABLE IF NOT EXISTS RETAIL_SUPPLY_CHAIN_DB.ORDERS.ORDER_LINES (
    ORDER_LINE_ID  VARCHAR(20)    PRIMARY KEY,
    ORDER_ID       VARCHAR(20)    NOT NULL,
    SKU            VARCHAR(20)    NOT NULL,
    QUANTITY       INTEGER        NOT NULL,
    UNIT_PRICE     DECIMAL(10,2)  NOT NULL,
    LINE_TOTAL     DECIMAL(10,2)  NOT NULL,
    LINE_STATUS    VARCHAR(20)    NOT NULL
);

CREATE TABLE IF NOT EXISTS RETAIL_SUPPLY_CHAIN_DB.ORDERS.DEMAND_FORECAST (
    FORECAST_ID      VARCHAR(20)    PRIMARY KEY,
    SKU              VARCHAR(20)    NOT NULL,
    LOCATION_ID      VARCHAR(10)    NOT NULL,
    FORECAST_DATE    DATE           NOT NULL,
    FORECASTED_UNITS INTEGER        NOT NULL,
    CONFIDENCE_LEVEL DECIMAL(3,2)   NOT NULL,
    MODEL_VERSION    VARCHAR(20)    NOT NULL
);

CREATE TABLE IF NOT EXISTS RETAIL_SUPPLY_CHAIN_DB.ORDERS.CUSTOMER_RETURNS (
    RETURN_ID             VARCHAR(20)    PRIMARY KEY,
    ORDER_ID              VARCHAR(20)    NOT NULL,
    ORDER_LINE_ID         VARCHAR(20)    NOT NULL,
    SKU                   VARCHAR(20)    NOT NULL,
    RETURN_DATE           DATE           NOT NULL,
    RETURN_REASON         VARCHAR(30)    NOT NULL,
    RETURN_CHANNEL        VARCHAR(20)    NOT NULL,
    ORIGINAL_SALE_CHANNEL VARCHAR(20)    NOT NULL,
    ITEM_CONDITION        VARCHAR(20)    NOT NULL,
    QUANTITY_RETURNED     INTEGER        NOT NULL,
    RECEIVING_LOCATION_ID VARCHAR(10)    NOT NULL,
    DISPOSITION_STATUS    VARCHAR(20)    NOT NULL,
    REFUND_AMOUNT         DECIMAL(10,2)  NOT NULL,
    RETURN_INITIATED_DATE DATE           NOT NULL,
    RETURN_RECEIVED_DATE  DATE
);

-- ---------------------------------------------------------------------------
-- FINANCE schema tables
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS RETAIL_SUPPLY_CHAIN_DB.FINANCE.PRODUCT_COSTS (
    SKU               VARCHAR(20)    NOT NULL,
    CHANNEL           VARCHAR(20)    NOT NULL,
    COGS              DECIMAL(10,2)  NOT NULL,
    SELLING_PRICE     DECIMAL(10,2)  NOT NULL,
    GROSS_MARGIN      DECIMAL(5,4)   NOT NULL,
    LIQUIDATION_VALUE DECIMAL(10,2)  NOT NULL,
    PRIMARY KEY (SKU, CHANNEL)
);

CREATE TABLE IF NOT EXISTS RETAIL_SUPPLY_CHAIN_DB.FINANCE.SHIPPING_COSTS (
    ORIGIN_LOCATION_ID      VARCHAR(10)   NOT NULL,
    DESTINATION_LOCATION_ID VARCHAR(10)   NOT NULL,
    COST_PER_UNIT           DECIMAL(10,2) NOT NULL,
    COST_PER_KG             DECIMAL(10,2) NOT NULL,
    TRANSIT_DAYS            INTEGER       NOT NULL,
    CARRIER                 VARCHAR(20)   NOT NULL,
    PRIMARY KEY (ORIGIN_LOCATION_ID, DESTINATION_LOCATION_ID)
);

-- =============================================================================
-- SECTION 4: Internal Stages
-- =============================================================================

CREATE STAGE IF NOT EXISTS RETAIL_SUPPLY_CHAIN_DB.AGENT.AGENT_SPECS
  DIRECTORY = (ENABLE = TRUE)
  COMMENT = 'Cortex Agent specification YAML files'
  ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE');

CREATE STAGE IF NOT EXISTS RETAIL_SUPPLY_CHAIN_DB.AGENT.SKILLS_STAGE
  DIRECTORY = (ENABLE = TRUE)
  COMMENT = 'Cortex Agent skill markdown files'
  ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE');

-- =============================================================================
-- SECTION 5: Utility UDF – READ_STAGE_FILE
-- Required by the create_cortex_agent macro to read spec YAML from stage.
-- =============================================================================

CREATE OR REPLACE FUNCTION RETAIL_SUPPLY_CHAIN_DB.AGENT.READ_STAGE_FILE(
  file_path STRING
)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
HANDLER = 'read_file_from_stage'
PACKAGES = ('snowflake-snowpark-python')
COMMENT = 'Reads a file from an internal stage and returns its contents as a string'
AS
$$
from snowflake.snowpark.files import SnowflakeFile

def read_file_from_stage(file_path: str) -> str:
    try:
        with SnowflakeFile.open(file_path, 'r') as f:
            return f.read()
    except Exception as e:
        return f"Error reading file: {str(e)}"
$$;

-- =============================================================================
-- SECTION 6: Disposition Action Procedure
-- =============================================================================

CREATE OR REPLACE PROCEDURE RETAIL_SUPPLY_CHAIN_DB.AGENT.TRIGGER_DISPOSITION_ACTION(
    ACTION_TYPE VARCHAR,
    SKU VARCHAR,
    QUANTITY NUMBER,
    FROM_LOCATION VARCHAR,
    TO_LOCATION VARCHAR,
    RECIPIENT_EMAIL VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
BEGIN
    LET email_body VARCHAR;
    LET email_subject VARCHAR;
    LET prompt VARCHAR;

    IF (:ACTION_TYPE NOT IN ('REBALANCE', 'LIQUIDATE')) THEN
        RETURN 'ERROR: ACTION_TYPE must be REBALANCE or LIQUIDATE';
    END IF;

    IF (:ACTION_TYPE = 'REBALANCE') THEN
        prompt := 'Write a concise professional email body (no subject line) notifying the warehouse team of an approved inventory transfer. Details: '
            || :QUANTITY || ' units of SKU ' || :SKU
            || ' to be transferred from ' || :FROM_LOCATION || ' to ' || :TO_LOCATION
            || '. Include a request to confirm receipt upon delivery. Keep it under 150 words.';
      email_subject := 'Inventory Transfer Approved: ' || :SKU || ' (' || :FROM_LOCATION || ' → ' || :TO_LOCATION || ')';
    ELSE
        prompt := 'Write a concise professional email body (no subject line) notifying the liquidation team of an approved liquidation order. Details: '
            || :QUANTITY || ' units of SKU ' || :SKU
            || ' at location ' || :FROM_LOCATION
            || ' to be routed to liquidation channel. Include a request to confirm pickup scheduling. Keep it under 150 words.';
        email_subject := 'Liquidation Order Approved: ' || :SKU || ' at ' || :FROM_LOCATION;
    END IF;

    email_body := (SELECT SNOWFLAKE.CORTEX.COMPLETE('llama3.1-8b', :prompt)::VARCHAR);

    CALL SYSTEM$SEND_EMAIL(
        'inventory_email_integration',
        :recipient_email::STRING,
        :email_subject::STRING,
        :email_body::STRING
    );

    RETURN 'Action triggered: ' || :ACTION_TYPE || ' for ' || :QUANTITY || ' units of ' || :SKU || '. Email sent to ' || :RECIPIENT_EMAIL;
END;


-- =============================================================================
-- END OF SCAFFOLDING
-- Next: run seed_source_data.sql to populate source tables.
-- =============================================================================

