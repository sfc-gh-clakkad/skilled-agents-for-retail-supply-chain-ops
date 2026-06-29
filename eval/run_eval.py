"""
Cortex Agent Evaluation Runner
Measures agent efficacy with and without skills for inventory rebalancing.

Usage:
    python run_eval.py [--dataset eval/agent_eval_dataset.json] [--output eval/results.json]

Prerequisites:
    - snowflake-connector-python installed
    - Valid Snowflake connection (uses default connection from ~/.snowflake/connections.toml)
"""

import json
import argparse
import sys
from pathlib import Path
from datetime import datetime
from dataclasses import dataclass, field, asdict

try:
    import snowflake.connector
    from snowflake.connector import DictCursor
except ImportError:
    print("ERROR: snowflake-connector-python required. Install with: pip install snowflake-connector-python")
    sys.exit(1)


@dataclass
class EvalResult:
    """Result of a single evaluation case."""
    id: str
    category: str
    question: str
    skill_mode: str
    difficulty: str
    passed: bool = False
    score: float = 0.0
    tools_called: list = field(default_factory=list)
    skill_used: str = ""
    assertions_passed: list = field(default_factory=list)
    assertions_failed: list = field(default_factory=list)
    response_summary: str = ""
    error: str = ""
    latency_seconds: float = 0.0


def get_snowflake_connection():
    """Create Snowflake connection using default connection config."""
    try:
        conn = snowflake.connector.connect(
            connection_name="default"
        )
        return conn
    except Exception as e:
        print(f"Connection error: {e}")
        print("Ensure ~/.snowflake/connections.toml has a valid 'default' connection.")
        sys.exit(1)


def call_cortex_agent(conn, question: str, skill_mode: str = "enabled") -> dict:
    """
    Call the Cortex Agent and return structured response.

    Args:
        conn: Snowflake connection
        question: User question to send
        skill_mode: 'enabled' or 'disabled' — controls whether skills are available

    Returns:
        dict with keys: tools_called, skill_used, response_text, latency_seconds
    """
    import time

    agent_name = "RETAIL_SUPPLY_CHAIN_INV.AGENT.REBALANCING_AGENT"

    if skill_mode == "disabled":
        prompt_prefix = "[EVALUATION MODE: Do not use skills. Answer using only direct tool calls.] "
        question_with_mode = prompt_prefix + question
    else:
        question_with_mode = question

    sql = f"""
        SELECT SNOWFLAKE.CORTEX.INVOKE_AGENT(
            '{agent_name}',
            '{question_with_mode.replace("'", "''")}'
        ) AS RESPONSE
    """

    start_time = time.time()
    try:
        cur = conn.cursor(DictCursor)
        cur.execute(sql)
        result = cur.fetchone()
        latency = time.time() - start_time

        response_text = result["RESPONSE"] if result else ""

        tools_called = extract_tools_from_response(response_text)
        skill_used = extract_skill_from_response(response_text)

        return {
            "tools_called": tools_called,
            "skill_used": skill_used,
            "response_text": response_text,
            "latency_seconds": round(latency, 2)
        }
    except Exception as e:
        latency = time.time() - start_time
        return {
            "tools_called": [],
            "skill_used": "",
            "response_text": "",
            "latency_seconds": round(latency, 2),
            "error": str(e)
        }


def extract_tools_from_response(response_text: str) -> list:
    """Extract tool names from agent response metadata."""
    tools = []
    tool_names = [
        "query_inventory", "query_orders", "query_finance",
        "query_returns", "query_logistics", "code_execution", "data_to_chart"
    ]
    response_lower = response_text.lower()
    for tool in tool_names:
        if tool in response_lower:
            tools.append(tool)
    return tools


def extract_skill_from_response(response_text: str) -> str:
    """Extract which skill was activated from agent response."""
    response_lower = response_text.lower()
    if "stockout_risk_prioritization" in response_lower or "stockout risk" in response_lower:
        return "stockout_risk_prioritization"
    elif "returns_rebalancing" in response_lower or "returns-driven" in response_lower:
        return "returns_rebalancing"
    return ""


def evaluate_case(response: dict, test_case: dict) -> EvalResult:
    """Score a single test case against expected behavior."""
    expected = test_case["expected_behavior"]
    result = EvalResult(
        id=test_case["id"],
        category=test_case["category"],
        question=test_case["question"],
        skill_mode=test_case["skill_mode"],
        difficulty=test_case["difficulty"],
        tools_called=response.get("tools_called", []),
        skill_used=response.get("skill_used", ""),
        response_summary=response.get("response_text", "")[:500],
        error=response.get("error", ""),
        latency_seconds=response.get("latency_seconds", 0.0)
    )

    if result.error:
        result.passed = False
        result.score = 0.0
        return result

    total_assertions = len(expected.get("key_assertions", []))
    passed_assertions = 0

    for assertion in expected.get("key_assertions", []):
        assertion_passed = check_assertion(assertion, response, expected)
        if assertion_passed:
            result.assertions_passed.append(assertion)
            passed_assertions += 1
        else:
            result.assertions_failed.append(assertion)

    if expected.get("skill_used"):
        if result.skill_used == expected["skill_used"]:
            passed_assertions += 1
            result.assertions_passed.append(f"Correct skill: {expected['skill_used']}")
        else:
            result.assertions_failed.append(
                f"Expected skill '{expected['skill_used']}', got '{result.skill_used}'"
            )
        total_assertions += 1

    expected_tools = set(expected.get("tools_invoked", []))
    actual_tools = set(response.get("tools_called", []))
    tool_overlap = expected_tools.intersection(actual_tools)
    if expected_tools:
        tool_score = len(tool_overlap) / len(expected_tools)
        if tool_score >= 0.8:
            passed_assertions += 1
            result.assertions_passed.append(f"Tool coverage: {tool_score:.0%}")
        else:
            result.assertions_failed.append(
                f"Tool coverage {tool_score:.0%} — missing: {expected_tools - actual_tools}"
            )
        total_assertions += 1

    result.score = passed_assertions / max(total_assertions, 1)
    result.passed = result.score >= 0.7

    return result


def check_assertion(assertion: str, response: dict, expected: dict) -> bool:
    """Check a specific assertion against the response."""
    assertion_lower = assertion.lower()
    response_text = response.get("response_text", "").lower()
    tools_called = response.get("tools_called", [])

    if "code_execution" in assertion_lower:
        return "code_execution" in tools_called
    elif "probability" in assertion_lower or "p(stockout)" in assertion_lower:
        return any(kw in response_text for kw in ["probability", "p(stockout)", "stockout risk", "%"])
    elif "margin" in assertion_lower:
        return any(kw in response_text for kw in ["margin", "profit", "cogs", "net margin"])
    elif "ranked" in assertion_lower or "priorit" in assertion_lower:
        return any(kw in response_text for kw in ["rank", "priority", "priorit", "#1", "#2", "| 1 |", "| 2 |"])
    elif "disposition" in assertion_lower:
        return any(kw in response_text for kw in ["restock", "transfer", "liquidate", "disposition"])
    elif "demand" in assertion_lower:
        return any(kw in response_text for kw in ["demand", "forecast", "order", "committed"])
    elif "cost" in assertion_lower or "economic" in assertion_lower:
        return any(kw in response_text for kw in ["cost", "$", "economic", "benefit", "net_benefit"])
    elif "condition" in assertion_lower:
        return any(kw in response_text for kw in ["condition", "new", "like_new", "refurbish"])
    elif "visualization" in assertion_lower or "chart" in assertion_lower:
        return "data_to_chart" in tools_called

    terms = [t for t in assertion_lower.split() if len(t) > 3]
    matches = sum(1 for t in terms if t in response_text)
    return matches >= len(terms) * 0.5


def generate_report(results: list) -> dict:
    """Generate evaluation summary report."""
    total = len(results)
    passed = sum(1 for r in results if r.passed)

    categories = {}
    for r in results:
        key = f"{r.category}_{r.skill_mode}"
        if key not in categories:
            categories[key] = {"total": 0, "passed": 0, "avg_score": 0.0, "avg_latency": 0.0}
        categories[key]["total"] += 1
        categories[key]["passed"] += 1 if r.passed else 0
        categories[key]["avg_score"] += r.score
        categories[key]["avg_latency"] += r.latency_seconds

    for key in categories:
        n = categories[key]["total"]
        categories[key]["avg_score"] = round(categories[key]["avg_score"] / n, 3)
        categories[key]["avg_latency"] = round(categories[key]["avg_latency"] / n, 2)

    enabled_results = [r for r in results if r.skill_mode == "enabled"]
    disabled_results = [r for r in results if r.skill_mode == "disabled"]

    enabled_pass_rate = sum(1 for r in enabled_results if r.passed) / max(len(enabled_results), 1)
    disabled_pass_rate = sum(1 for r in disabled_results if r.passed) / max(len(disabled_results), 1)

    enabled_avg_score = sum(r.score for r in enabled_results) / max(len(enabled_results), 1)
    disabled_avg_score = sum(r.score for r in disabled_results) / max(len(disabled_results), 1)

    report = {
        "summary": {
            "total_cases": total,
            "passed": passed,
            "failed": total - passed,
            "overall_pass_rate": round(passed / max(total, 1), 3),
            "overall_avg_score": round(sum(r.score for r in results) / max(total, 1), 3),
        },
        "skill_comparison": {
            "with_skills": {
                "cases": len(enabled_results),
                "pass_rate": round(enabled_pass_rate, 3),
                "avg_score": round(enabled_avg_score, 3),
            },
            "without_skills": {
                "cases": len(disabled_results),
                "pass_rate": round(disabled_pass_rate, 3),
                "avg_score": round(disabled_avg_score, 3),
            },
            "skill_delta": round(enabled_avg_score - disabled_avg_score, 3),
        },
        "by_category": categories,
        "timestamp": datetime.now().isoformat(),
    }

    return report


def print_console_report(report: dict, results: list):
    """Print human-readable evaluation report to console."""
    print("\n" + "=" * 70)
    print("  CORTEX AGENT EVALUATION REPORT")
    print("  Inventory Rebalancing Agent — Skill Efficacy Assessment")
    print("=" * 70)

    s = report["summary"]
    print(f"\n  Total cases: {s['total_cases']}")
    print(f"  Passed:      {s['passed']} ({s['overall_pass_rate']:.0%})")
    print(f"  Failed:      {s['failed']}")
    print(f"  Avg Score:   {s['overall_avg_score']:.1%}")

    sc = report["skill_comparison"]
    print(f"\n  {'─' * 50}")
    print(f"  SKILL EFFICACY COMPARISON")
    print(f"  {'─' * 50}")
    print(f"  With skills:    {sc['with_skills']['pass_rate']:.0%} pass rate, "
          f"{sc['with_skills']['avg_score']:.1%} avg score ({sc['with_skills']['cases']} cases)")
    print(f"  Without skills: {sc['without_skills']['pass_rate']:.0%} pass rate, "
          f"{sc['without_skills']['avg_score']:.1%} avg score ({sc['without_skills']['cases']} cases)")
    print(f"  Skill Delta:    +{sc['skill_delta']:.1%} improvement with skills")

    print(f"\n  {'─' * 50}")
    print(f"  RESULTS BY CATEGORY")
    print(f"  {'─' * 50}")
    for key, val in report["by_category"].items():
        print(f"  {key:40s} {val['passed']}/{val['total']} passed "
              f"(score: {val['avg_score']:.1%}, latency: {val['avg_latency']:.1f}s)")

    failed = [r for r in results if not r.passed]
    if failed:
        print(f"\n  {'─' * 50}")
        print(f"  FAILED CASES ({len(failed)})")
        print(f"  {'─' * 50}")
        for r in failed:
            print(f"\n  [{r.id}] {r.question[:60]}...")
            print(f"    Score: {r.score:.1%} | Skill mode: {r.skill_mode}")
            if r.assertions_failed:
                for a in r.assertions_failed:
                    print(f"    ✗ {a}")
            if r.error:
                print(f"    ERROR: {r.error[:100]}")

    print("\n" + "=" * 70)


def main():
    parser = argparse.ArgumentParser(description="Run Cortex Agent evaluation")
    parser.add_argument("--dataset", default="eval/agent_eval_dataset.json",
                        help="Path to evaluation dataset JSON")
    parser.add_argument("--output", default="eval/results.json",
                        help="Path to write results JSON")
    parser.add_argument("--dry-run", action="store_true",
                        help="Validate dataset without calling the agent")
    args = parser.parse_args()

    dataset_path = Path(args.dataset)
    if not dataset_path.exists():
        print(f"ERROR: Dataset not found at {dataset_path}")
        sys.exit(1)

    with open(dataset_path) as f:
        dataset = json.load(f)

    test_cases = dataset["test_cases"]
    print(f"Loaded {len(test_cases)} test cases from {dataset_path}")

    if args.dry_run:
        print("DRY RUN — validating dataset structure...")
        for tc in test_cases:
            required = ["id", "category", "question", "expected_behavior", "skill_mode", "difficulty"]
            missing = [k for k in required if k not in tc]
            if missing:
                print(f"  WARNING [{tc.get('id', '?')}]: missing keys: {missing}")
        print("Dataset validation complete.")
        return

    conn = get_snowflake_connection()
    print("Connected to Snowflake. Running evaluation...\n")

    results = []
    for i, tc in enumerate(test_cases, 1):
        print(f"  [{i}/{len(test_cases)}] {tc['id']} ({tc['skill_mode']}) — {tc['question'][:50]}...")

        response = call_cortex_agent(conn, tc["question"], tc["skill_mode"])
        result = evaluate_case(response, tc)
        results.append(result)

        status = "PASS" if result.passed else "FAIL"
        print(f"           {status} (score: {result.score:.1%}, latency: {result.latency_seconds:.1f}s)")

    report = generate_report(results)
    report["detailed_results"] = [asdict(r) for r in results]

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w") as f:
        json.dump(report, f, indent=2)

    print(f"\nResults saved to {output_path}")
    print_console_report(report, results)

    conn.close()


if __name__ == "__main__":
    main()
