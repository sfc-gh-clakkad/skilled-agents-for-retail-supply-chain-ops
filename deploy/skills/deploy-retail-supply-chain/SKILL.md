---
name: deploy-retail-supply-chain
description: >
  Deploy the agentic retail supply chain inventory project end-to-end.
  Handles full fresh deployments and targeted incremental updates (agent,
  skills, or models only). Use when: deploy project, redeploy, update agent
  spec, update skills, rebuild semantic views, run deployment, deploy retail
  supply chain, deploy inventory agent, deploy inventory project.
---

# Deploy Retail Supply Chain Inventory

Orchestrates the full deployment from infrastructure through Cortex Agent.
All SQL executes via `snowflake_sql_execute` (CoCo's built-in Snowflake tool).
PUT commands via Bash (client-side). dbt runs server-side via `snow dbt deploy`
and `snow dbt execute`.

The working directory for Bash commands is the **project root**
(`agentic-inventory-management/`).

## Workflow

### Step 1: Confirm Role, Scope, and EAI

Ask before running anything:

```
1. Deployment role name? (default: current session role from CoCo connection)
2. External Access Integration name for dbt packages? (default: DBT_PACKAGES_EAI)
3. Deployment scope — pick one:
   a. Full   — infrastructure + data + agent (fresh or rebuild)
   b. Update — agent spec / skills / models only (skip infra + data)
   c. Data   — reseed source tables + rebuild models (skip agent deploy)
```

**MANDATORY — do this BEFORE any SQL execution:**

1. Confirm the current role via `SELECT CURRENT_ROLE();`
2. Store the role name and EAI name as variables for this session.
3. When reading SQL from `setup_prerequisites.sql` or `project_scaffolding_deploy.sql`,
   replace `<YOUR_ROLE>` with the confirmed role name **in memory** before executing.
   Do NOT edit the source `.sql` files on disk.
4. For `profiles.yml`: the `role` field is not ignored in Snowflake-managed dbt execution
   (the deployed project runs under the caller's session role). Edit this file to replace placeholder with confirmed role.

Do NOT proceed to Step 2 until the role and EAI are confirmed.

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
role name in memory, and execute each statement via `snowflake_sql_execute`.
Execute statements **one at a time** in order.

Stop immediately if any statement fails — later steps depend on objects
created here.

### Step 4: Seed Source Data — Full or Data scope

Read `seed_source_data.sql` and execute each statement via
`snowflake_sql_execute` in order.

All INSERT statements use `INSERT OVERWRITE INTO` — this makes them
idempotent (replaces existing data atomically, no separate TRUNCATE needed).
Re-running is always safe.

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

**CRITICAL: Execute the commands in this step EXACTLY as written. Do NOT
generate alternative SQL, modify the syntax, or improvise dbt commands.
These commands have been validated — any deviation will fail.**

Deploy the dbt project as a Snowflake-native dbt project object, then execute
it server-side. No local dbt installation required.

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

Do NOT rewrite this SQL. Do NOT split it into multiple statements. Do NOT
substitute the args format with JSON arrays or alternative quoting.
Execute it exactly as shown above via `snowflake_sql_execute`.

If the deploy fails with a network error, verify the EAI exists and has been
granted to your role (see `setup_prerequisites.sql`).

If a semantic view fails with a column error, the most likely cause is that
the source table was not reseeded after a schema change — re-run Step 4.

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

## Scope Matrix

| Step | Full | Update | Data only |
|------|------|--------|-----------|
| 3 — Infrastructure | yes | no | no |
| 4 — Seed data | yes | no | yes |
| 5 — Upload to stage | yes | yes | no |
| 6 — dbt deploy + run | yes | yes | yes |

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
