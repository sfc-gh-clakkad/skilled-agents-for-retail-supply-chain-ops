# Skilled Agents for Retail Supply Chain

An AI-powered retail supply chain assistant built on [Snowflake Cortex Agents](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agent). The agent helps area managers and store managers make inventory decisions using text-to-SQL, code execution, and structured skills.

## Overview

This project demonstrates how to extend a Cortex Agent beyond basic Q&A into a system that automates real-world inventory management workflows. The agent answers natural language questions about inventory, orders, returns, and finance across a multi-location retail network — and uses two specialized skills to orchestrate multi-step analytical workflows that go beyond simple data lookups.

### What you'll build

**Two production-style agent skills** automating real inventory management workflows:

- **Returns-Driven Inventory Rebalancing** — A 7-step decision workflow that pulls return inflows, cross-references demand signals and item condition, evaluates transfer economics (shipping cost vs. margin recovery), and produces actionable RESTOCK / TRANSFER / LIQUIDATE recommendations with cost justification.

- **Stockout Risk Prioritization** — A probabilistic ranking workflow that calculates P(stockout) during lead time using a custom Python script (`stockout_risk.py`) with scipy's normal distribution CDF, then weights results by gross margin to produce a prioritized reorder list sorted by expected cost of inaction.

**Custom Python with the code execution tool** — The stockout skill shows how to pair a Cortex Agent's code execution tool with a purpose-built Python calculation. The agent fetches inventory and demand data via text-to-SQL, then passes it to `stockout_risk.py` which computes the statistical stockout probability per SKU. This pattern lets you embed domain-specific quantitative logic (forecasting models, optimization solvers, scoring algorithms) that LLMs cannot reliably perform on their own.

**A repeatable pattern** — The skill structure (markdown workflow + supporting code + semantic views) is designed to be forked and adapted. Add your own skills by following the same layout under `cortex_agents/skills/`.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   Cortex Agent                           │
│               RETAIL_OPS_AGENT                          │
├──────────┬──────────┬──────────┬────────────────────────┤
│ Text-to- │  Code    │  Chart   │  Disposition           │
│   SQL    │Execution │ Renderer │  Action (email)        │
├──────────┴──────────┴──────────┴────────────────────────┤
│  Skills                                                  │
│  ├── returns_rebalancing (7-step workflow)               │
│  └── stockout_risk_prioritization (scipy-based calc)     │
├─────────────────────────────────────────────────────────┤
│  Semantic Views (Cortex Analyst)                         │
│  ├── INVENTORY_SV   — stock levels, products, locations  │
│  ├── ORDERS_SV      — orders, returns, demand forecasts  │
│  └── FINANCE_SV     — margins, COGS, shipping costs      │
├─────────────────────────────────────────────────────────┤
│  Source Tables (synthetic data)                           │
│  INVENTORY schema │ ORDERS schema │ FINANCE schema       │
└─────────────────────────────────────────────────────────┘
```

## Repository Structure

```
├── deploy/
│   └── skills/deploy-retail-supply-chain/
│       ├── SKILL.md                      # Deployment orchestration (for Cortex Code)
│       ├── setup_prerequisites.sql       # ACCOUNTADMIN one-time setup
│       ├── project_scaffolding_deploy.sql# DB, schemas, tables, stages, UDFs
│       └── seed_source_data.sql          # Synthetic data seeding
├── eval/
│   ├── agent_eval_dataset.json           # 18 golden evaluation test cases
│   └── run_eval.py                       # Evaluation runner script
└── retail_supply_chain_dbt/
    ├── dbt_project.yml
    ├── packages.yml
    ├── profiles.yml
    ├── cortex_agents/
    │   ├── rebalancing_agent_with_skills.yml  # Agent specification
    │   └── skills/                            # Skill definitions
    ├── macros/
    │   ├── create_cortex_agent.sql            # dbt macro to CREATE AGENT
    │   └── generate_schema_name.sql
    └── models/
        ├── sources.yml
        ├── orders/                            # Transformation models
        └── semantic_views/                    # 3 semantic views
```

## Getting Started

This project is designed to be deployed using [Cortex Code](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code) — Snowflake's AI-powered IDE. A deployment skill automates the entire setup end-to-end, handling infrastructure creation, data seeding, dbt deployment, and agent creation interactively.

### Prerequisites

- A Snowflake account with [Cortex Agents](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agent) enabled
- [Cortex Code](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code) installed and connected to your Snowflake account
- [Snowflake CLI](https://docs.snowflake.com/en/developer-guide/snowflake-cli/index) (`snow`) installed and configured
- A role with `CREATE DATABASE` privilege
- ACCOUNTADMIN access for one-time integration setup

### Step 1: Clone and Open in Cortex Code

```bash
git clone https://github.com/Snowflake-Labs/skilled-agents-for-retail-supply-chain.git
```

Open the cloned directory in Cortex Code.

### Step 2: Deploy with Cortex Code

In the Cortex Code chat panel, type:

> **"Deploy the retail supply chain project"**

Cortex Code will activate the deployment skill (`deploy/skills/deploy-retail-supply-chain/SKILL.md`) and walk you through the process interactively:

1. **Confirm configuration** — Cortex Code asks for your deployment role and external access integration name
2. **Account prerequisites** — Presents the ACCOUNTADMIN setup SQL (warehouse, integrations, grants) for you to run
3. **Infrastructure** — Creates the database, schemas, tables, stages, and UDFs
4. **Seed data** — Populates tables with synthetic retail data (50 products, 5 locations, ~250 stock records, 200 orders, ~150 returns)
5. **Upload to stage** — PUTs the agent spec and skill files to internal stages
6. **dbt deploy + execute** — Deploys and runs the dbt project server-side (builds transformation model + 3 semantic views)
7. **Create agent** — Creates `RETAIL_OPS_AGENT` via dbt macro
8. **Verify** — Confirms the agent and semantic views are live

The skill handles role substitution, execution ordering, and error recovery automatically. You only need to confirm the ACCOUNTADMIN step and answer the initial configuration prompts.

### Deployment Scope Options

The skill supports three deployment scopes:

| Scope | What it does | When to use |
|-------|-------------|-------------|
| **Full** | Infrastructure + data + agent (all steps) | First-time setup or full rebuild |
| **Update** | Agent spec + skills + models only | After editing agent YAML or skill files |
| **Data** | Reseed source tables + rebuild models | After modifying seed data |

### Incremental Updates

After the initial deployment, use Cortex Code for targeted updates:

- **Changed agent behavior?** — "Redeploy the retail supply chain agent" (Update scope)
- **Modified skills?** — "Update the retail supply chain skills" (Update scope)
- **Changed source data?** — "Reseed the retail supply chain data" (Data scope)

### Verification

After deployment completes, Cortex Code runs verification automatically. You can also check manually:

```sql
SHOW AGENTS IN DATABASE RETAIL_SUPPLY_CHAIN_DB;
SHOW SEMANTIC VIEWS IN SCHEMA RETAIL_SUPPLY_CHAIN_DB.AGENT;
```

Expected output: `RETAIL_OPS_AGENT` and three semantic views (`INVENTORY_SV`, `ORDERS_SV`, `FINANCE_SV`).

## Using the Agent

Once deployed, interact with the agent via Snowflake Intelligence or the API:

```sql
SELECT SNOWFLAKE.CORTEX.INVOKE_AGENT(
    'RETAIL_SUPPLY_CHAIN_DB.AGENT.RETAIL_OPS_AGENT',
    'Which returned SKUs should be rebalanced this week?'
) AS RESPONSE;
```

**Example questions:**
- "Which returned SKUs should be rebalanced this week?"
- "Show me the return rate trends for electronics"
- "What is the current stock status across my locations?"
- "Analyze pending returns and recommend dispositions"
- "Which SKUs should I prioritize for reorder this week?"

## Evaluation

The `eval/` directory contains an evaluation framework with 18 golden test cases that measure agent efficacy with and without skills. Run it directly from Cortex Code.

In the Cortex Code chat panel:

> **"Run the agent evaluation"**

Cortex Code will:
1. Install `snowflake-connector-python` if needed
2. Validate the dataset structure (dry run)
3. Execute all 18 test cases against the deployed agent in both modes (skills enabled vs. disabled)
4. Output a summary report with pass rates, score deltas, and latency by category
5. Save detailed results to `eval/results.json`

You can also ask for specific evaluation tasks:

- **"Dry run the eval dataset"** — validates dataset structure without calling the agent
- **"Run eval and show me the skill comparison"** — runs the eval and highlights the with-skills vs. without-skills delta
- **"Run eval for stockout risk cases only"** — targets a specific category

The evaluation reports:
- Overall pass rate and average score
- Skill efficacy comparison (with vs. without skills)
- Per-category breakdown (score + latency)
- Detailed failure analysis with assertion-level diagnostics

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Schema does not exist` in dbt | Infrastructure not created | Redeploy with Full scope |
| `Invalid identifier LEAD_TIME_DAYS` | Source tables empty | Redeploy with Data scope |
| `PUT: file not found` | Wrong working directory | Ensure Cortex Code is opened at the project root |
| `Network access denied` during dbt deploy | EAI not configured | Run prerequisites as ACCOUNTADMIN |
| Agent spec invalid | YAML field unsupported | Check spec against [Cortex Agent docs](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agent) |
| `READ_STAGE_FILE error` on agent creation | Spec not uploaded to stage | Redeploy with Update scope |

## License

Apache 2.0 — see [LICENSE](LICENSE).
