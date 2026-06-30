---
name: deploy-retail-supply-chain
description: >
  Deploy the agentic retail supply chain inventory project end-to-end.
  Handles full fresh deployments, targeted incremental updates (agent,
  skills, or models only), and teardown (remove all resources). Use when:
  deploy project, redeploy, update agent spec, update skills, rebuild
  semantic views, run deployment, deploy retail supply chain, deploy inventory
  agent, deploy inventory project, teardown, remove project, cleanup, uninstall.
---

# Deploy Retail Supply Chain Inventory

Orchestrates the full deployment from infrastructure through Cortex Agent.
SQL via `snowflake_sql_execute`; PUT commands via Bash (client-side); dbt via
`snow dbt deploy` / `snow dbt execute` (server-side).

**SQL batching**: Batch independent statements (semicolon-separated) into one
`snowflake_sql_execute` call. Execute sequentially only when dependencies exist.

## Workflow

### Step 1: Confirm Role, Scope, and EAI

Ask before running anything:

```
1. Deployment role name? (default: current session role from CoCo connection)
2. External Access Integration name for dbt packages? (default: DBT_PACKAGES_EAI)
3. Deployment scope — pick one:
   a. Full     — infrastructure + data + agent (fresh or rebuild)
   b. Update   — agent spec / skills / models only (skip infra + data)
   c. Data     — reseed source tables + rebuild models (skip agent deploy)
   d. Teardown — remove ALL project resources (destructive, irreversible)
```

**Before any SQL execution:**

1. Confirm role via `SELECT CURRENT_ROLE();` and store role + EAI names.
2. Substitute `<YOUR_ROLE>` in memory when reading `.sql` files (do NOT edit files on disk).
3. Edit `profiles.yml` to set the `role` field to the confirmed role.

Do NOT proceed until role and EAI are confirmed.

### Step 2: Account-Level Prerequisites (one-time, ACCOUNTADMIN)

Read `setup_prerequisites.sql`, substitute `<YOUR_ROLE>` → confirmed role name
in memory, and present the resulting SQL to the user. Instruct them to run it
as ACCOUNTADMIN:

```
This script creates:
  - RETAIL_SUPPLY_CHAIN_QS_WH (XSMALL warehouse)
  - Grants: CREATE DATABASE, warehouse usage, CORTEX_AGENT_USER, PYPI_REPOSITORY_USER
  - INVENTORY_EMAIL_INTEGRATION (notification integration)
  - DBT_PACKAGES_EAI (external access integration for dbt hub)

Run as ACCOUNTADMIN in a Snowflake worksheet or via:
  snow sql -f <path_to_skill>/setup_prerequisites.sql
```

**⚠️ STOP**: Ask the user to confirm the following objects were created:
- `RETAIL_SUPPLY_CHAIN_QS_WH` warehouse
- `INVENTORY_EMAIL_INTEGRATION` integration
- `DBT_PACKAGES_EAI` integration (or the user's custom EAI name)

Do NOT proceed until confirmation is received.

### Step 3: Infrastructure — Full scope only

Read `project_scaffolding_deploy.sql`, substitute `<YOUR_ROLE>` → confirmed
role, execute statements one at a time in order. Stop on any failure.

### Step 4: Seed Source Data — Full or Data scope

Read `seed_source_data.sql` and execute each statement in order.
Statements use `INSERT OVERWRITE INTO` (idempotent, safe to re-run).

### Step 5: Upload Agent Spec and Skills to Stage

PUT commands are client-side and must run via Bash from the project root.

```bash
snow sql --query "PUT file://./retail_supply_chain_dbt/cortex_agents/rebalancing_agent_with_skills.yml @RETAIL_SUPPLY_CHAIN_DB.AGENT.AGENT_SPECS/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE;"

snow sql --query "PUT file://./retail_supply_chain_dbt/cortex_agents/skills/returns_rebalancing/SKILL.md @RETAIL_SUPPLY_CHAIN_DB.AGENT.SKILLS_STAGE/skills/returns_rebalancing/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE;"

snow sql --query "PUT file://./retail_supply_chain_dbt/cortex_agents/skills/stockout_risk_prioritization/SKILL.md @RETAIL_SUPPLY_CHAIN_DB.AGENT.SKILLS_STAGE/skills/stockout_risk_prioritization/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE;"

snow sql --query "PUT file://./retail_supply_chain_dbt/cortex_agents/skills/stockout_risk_prioritization/stockout_risk.py @RETAIL_SUPPLY_CHAIN_DB.AGENT.SKILLS_STAGE/skills/stockout_risk_prioritization/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE;"
```

**⚠️ STOP**: Verify all 4 PUT commands succeeded (status = UPLOADED) before
proceeding. If any fail, check the working directory and file paths.

### Step 6: Deploy & Execute dbt Project

**Execute commands in this step EXACTLY as written — any deviation will fail.**

**6a. Deploy** (creates or updates the project object — always include EAI):

```bash
snow dbt deploy RETAIL_SUPPLY_CHAIN_DBT \
  --source ./retail_supply_chain_dbt \
  --database RETAIL_SUPPLY_CHAIN_DB \
  --schema AGENT \
  --external-access-integration <EAI_NAME>
```

Replace `<EAI_NAME>` with the EAI confirmed in Step 1 (default: `DBT_PACKAGES_EAI`).

**6b. Execute** (runs models server-side):

```bash
snow dbt execute \
  --database RETAIL_SUPPLY_CHAIN_DB \
  --schema AGENT \
  RETAIL_SUPPLY_CHAIN_DBT run
```

This builds in dependency order:
1. `ORDERS.DAILY_RETURN_RATES_BY_SKU_CHANNEL` (transformation)
2. `AGENT.INVENTORY_SV`, `AGENT.ORDERS_SV`, `AGENT.FINANCE_SV` (semantic views)

**6c. Create the Cortex Agent** (via dbt macro — copy this SQL VERBATIM):

```sql
EXECUTE DBT PROJECT RETAIL_SUPPLY_CHAIN_DB.AGENT.RETAIL_SUPPLY_CHAIN_DBT args=$$run-operation create_cortex_agent --args '{"agent_name": "RETAIL_OPS_AGENT", "database": "RETAIL_SUPPLY_CHAIN_DB", "schema": "AGENT", "stage_name": "AGENT_SPECS", "agent_spec_file": "rebalancing_agent_with_skills.yml", "next_version": "1.0.0"}'$$;
```

Execute this SQL verbatim via `snowflake_sql_execute`. Do not modify or split it.

**⚠️ STOP**: Report dbt execution results (PASS/ERROR counts) and agent
creation status before proceeding to verification.

### Step 7: Verify

Execute via `snowflake_sql_execute`:

```sql
SHOW AGENTS IN DATABASE RETAIL_SUPPLY_CHAIN_DB;
SHOW SEMANTIC VIEWS IN SCHEMA RETAIL_SUPPLY_CHAIN_DB.AGENT;
```

A successful deployment shows:
- `RETAIL_OPS_AGENT` in the agents list
- `INVENTORY_SV`, `ORDERS_SV`, `FINANCE_SV` in the semantic views list

Report the output and call the deployment complete.

### Step 8 (Optional): Deploy Evaluation Framework

Ask the user if they want to deploy the agent evaluation dataset and custom metric config.
If they decline, skip to Output.

**8a. Create evaluation dataset table and insert test cases:**

Read `eval/deploy_eval_dataset.sql` and execute each statement via
`snowflake_sql_execute` in order. The script creates the table
`RETAIL_SUPPLY_CHAIN_DB.AGENT.RETAIL_OPS_AGENT_EVAL_DATASET` and inserts 7
test cases covering stockout risk, returns rebalancing, cross-domain, and
general queries.

**8b. Create stage and upload eval config:**

```sql
CREATE STAGE IF NOT EXISTS RETAIL_SUPPLY_CHAIN_DB.AGENT.EVAL_STAGE
  FILE_FORMAT = (TYPE = 'CSV' FIELD_DELIMITER = NONE RECORD_DELIMITER = '\n'
                 SKIP_HEADER = 0 FIELD_OPTIONALLY_ENCLOSED_BY = NONE
                 ESCAPE_UNENCLOSED_FIELD = NONE);
```

```bash
snow sql --query "PUT file://./eval/agent_eval_config.yaml @RETAIL_SUPPLY_CHAIN_DB.AGENT.EVAL_STAGE/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE;"
```

**8c. Run the evaluation (optional):**

```sql
CALL EXECUTE_AI_EVALUATION(
  'START',
  OBJECT_CONSTRUCT('run_name', 'baseline-v1'),
  '@RETAIL_SUPPLY_CHAIN_DB.AGENT.EVAL_STAGE/agent_eval_config.yaml'
);
```

**⚠️ STOP**: Ask whether the user wants to start the evaluation run now or
just deploy the dataset and config for later use.

### Step 9 (Optional): Teardown — Remove All Project Resources

Ask the user if they want to tear down the project and remove all created
resources. **This is destructive and irreversible.** If they decline, skip.

**9a. Confirm teardown:**

```
⚠️  This will permanently delete ALL objects created by this project:
  agent, dbt project, semantic views, eval dataset, stages, tables,
  schemas, database (RETAIL_SUPPLY_CHAIN_DB), warehouse, and integrations.

Proceed with full teardown? (yes/no)
```

**9b. Execute teardown:**

Read `teardown.sql` and execute each statement via `snowflake_sql_execute`
in order.

- **Sections 1–9** (agent, dbt project, semantic views, stages, procedures,
  tables, schemas, database) — run under the deployment role. No elevated
  privileges required.
- **Section 10** (warehouse, notification integration, external access
  integration, network rule, `SHARED_OBJECTS` database) — **requires
  ACCOUNTADMIN**. These statements are commented out by default. Present them
  to the user and instruct them to run as ACCOUNTADMIN in a Snowflake
  worksheet. Skip if the objects are shared with other projects.
- **Section 11** (database role revocations) — commented out by default. Only
  present to the user if they explicitly want to revoke `CORTEX_AGENT_USER`
  and `PYPI_REPOSITORY_USER` grants.

**9c. Report summary:**

Execute the final SELECT (Section 11 summary report) and display the results
to confirm what was removed.

## Scope Matrix

| Step | Full | Update | Data only | Teardown |
|------|------|--------|-----------|----------|
| 3 — Infrastructure | yes | no | no | — |
| 4 — Seed data | yes | no | yes | — |
| 5 — Upload to stage | yes | yes | no | — |
| 6 — dbt deploy + run | yes | yes | yes | — |
| 9 — Teardown | no | no | no | yes |

## Error Reference

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Schema does not exist` in dbt | Scaffolding incomplete | Re-run Step 3 |
| `Invalid identifier LEAD_TIME_DAYS` | PRODUCTS not reseeded | Re-run Step 4 |
| `Agent spec invalid: unrecognized field` | YAML field unsupported | Check spec against Cortex Agent docs |
| `PUT: file not found` | Wrong working directory | Run from project root |
| dbt macro fails with `READ_STAGE_FILE error` | Spec not uploaded | Re-run Step 5 before Step 6 |
| `Network access denied` during dbt deploy | EAI not configured | Run `setup_prerequisites.sql` as ACCOUNTADMIN |
| `Unsupported fields: password` | profiles.yml has auth fields | Remove `password`/`authenticator` from profiles.yml |

## Output

Deployed objects: database + schemas, source tables, dbt transformation model,
three semantic views, Cortex Agent with two skills.
