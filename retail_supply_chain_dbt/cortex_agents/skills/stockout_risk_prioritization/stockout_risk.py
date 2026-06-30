"""
stockout_risk.py — Margin-aware stockout risk prioritization.

Computes P(stockout) during lead time for each SKU-location using a
normal-distribution model over lead-time demand, then scores by expected
cost of stockout and produces a ranked replenishment action list.

Usage (standalone):
    python stockout_risk.py --input sku_data.csv [--output results.csv]
"""

import argparse
import sys

import numpy as np
import pandas as pd
from scipy import stats

REQUIRED_COLUMNS = {
    "sku",
    "location",
    "available_stock",
    "lead_time_days",
    "daily_demand_mean",
    "daily_demand_std",
    "net_margin",
    "committed_demand",
    "carrying_cost_per_unit_per_day",
}

# Thresholds evaluated in order; first match wins.
_ACTION_RULES = [
    ("URGENT REORDER", lambda p, c: p > 0.70 or c > 3_000),
    ("REORDER",        lambda p, c: p > 0.40 or c > 1_000),
    ("MONITOR",        lambda p, c: p > 0.20),
    ("OK",             lambda p, c: True),
]


def compute_stockout_probability(
    available_stock: float,
    daily_demand_mean: float,
    daily_demand_std: float,
    lead_time_days: float,
) -> float:
    """Return P(stockout) during lead time using a normal-distribution model."""
    lt_demand_mean = daily_demand_mean * lead_time_days
    lt_demand_std = daily_demand_std * np.sqrt(lead_time_days)

    if lt_demand_std > 0:
        return 1 - stats.norm.cdf(available_stock, loc=lt_demand_mean, scale=lt_demand_std)
    return 1.0 if lt_demand_mean > available_stock else 0.0


def compute_expected_cost(
    p_stockout: float,
    net_margin: float,
    committed_demand: float,
    available_stock: float,
    daily_demand_mean: float,
    lead_time_days: float,
    carrying_cost_per_unit_per_day: float,
) -> float:
    """Return expected cost of stockout: (P(stockout) x lost margin) - avoided carrying cost."""
    lost_revenue = net_margin * committed_demand
    days_until_so = available_stock / max(daily_demand_mean, 0.01)
    avoided_carrying = (
        carrying_cost_per_unit_per_day
        * available_stock
        * max(0.0, lead_time_days - days_until_so)
    )
    return (p_stockout * lost_revenue) - avoided_carrying


def classify_action(p_stockout: float, expected_cost: float) -> str:
    """Classify replenishment urgency based on stockout probability and expected cost."""
    for label, condition in _ACTION_RULES:
        if condition(p_stockout, expected_cost):
            return label
    return "OK"


def compute_stockout_risk(sku_data: pd.DataFrame) -> pd.DataFrame:
    """
    Compute stockout probability and expected cost for each SKU-location.

    Parameters
    ----------
    sku_data : pd.DataFrame
        One row per at-risk SKU-location. Required columns:

        sku                          : str   — product identifier
        location                     : str   — location identifier
        available_stock              : float — quantity_on_hand - quantity_reserved
        lead_time_days               : float — supplier replenishment lead time
        daily_demand_mean            : float — mean daily units sold (last 90 days)
        daily_demand_std             : float — std dev of daily units sold
        net_margin                   : float — gross_margin * (1 - return_rate), per unit
        committed_demand             : float — open_orders + forecasted_demand (30 days)
        carrying_cost_per_unit_per_day : float — default: COGS * 0.25 / 365

    Returns
    -------
    pd.DataFrame
        Ranked results sorted by expected_cost_of_stockout descending. Columns:

        rank, sku, location, available_stock, lead_time_days,
        p_stockout, service_level, expected_cost_of_stockout,
        committed_demand, net_margin, action

    Raises
    ------
    ValueError
        If any required columns are missing from sku_data.
    """
    missing = REQUIRED_COLUMNS - set(sku_data.columns)
    if missing:
        raise ValueError(f"sku_data is missing required columns: {sorted(missing)}")

    if sku_data.empty:
        return pd.DataFrame(columns=[
            "rank", "sku", "location", "available_stock", "lead_time_days",
            "p_stockout", "service_level", "expected_cost_of_stockout",
            "committed_demand", "net_margin", "action",
        ])

    results = []
    for _, row in sku_data.iterrows():
        p_stockout = compute_stockout_probability(
            available_stock=row["available_stock"],
            daily_demand_mean=row["daily_demand_mean"],
            daily_demand_std=row["daily_demand_std"],
            lead_time_days=row["lead_time_days"],
        )

        expected_cost = compute_expected_cost(
            p_stockout=p_stockout,
            net_margin=row["net_margin"],
            committed_demand=row["committed_demand"],
            available_stock=row["available_stock"],
            daily_demand_mean=row["daily_demand_mean"],
            lead_time_days=row["lead_time_days"],
            carrying_cost_per_unit_per_day=row["carrying_cost_per_unit_per_day"],
        )

        results.append({
            "sku":                       row["sku"],
            "location":                  row["location"],
            "available_stock":           row["available_stock"],
            "lead_time_days":            row["lead_time_days"],
            "p_stockout":                round(p_stockout, 4),
            "service_level":             round(1 - p_stockout, 4),
            "expected_cost_of_stockout": round(expected_cost, 2),
            "committed_demand":          row["committed_demand"],
            "net_margin":                round(row["net_margin"], 2),
            "action":                    classify_action(p_stockout, expected_cost),
        })

    priority_df = (
        pd.DataFrame(results)
        .sort_values("expected_cost_of_stockout", ascending=False)
        .reset_index(drop=True)
    )
    priority_df.insert(0, "rank", range(1, len(priority_df) + 1))
    return priority_df


def print_summary(df: pd.DataFrame) -> None:
    """Print the ranked table and aggregate summary statistics."""
    print(df.to_string(index=False))
    print()
    print(f"Total at-risk SKUs   : {len(df)}")
    print(f"Total cost exposure  : ${df['expected_cost_of_stockout'].sum():,.2f}")
    print(f"Average service level: {df['service_level'].mean():.1%}")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Compute margin-aware stockout risk rankings from a CSV of SKU data."
    )
    parser.add_argument("--input",  required=True, help="Path to sku_data CSV")
    parser.add_argument("--output", default=None,  help="Path to write results CSV (optional)")
    args = parser.parse_args()

    try:
        sku_data = pd.read_csv(args.input)
    except FileNotFoundError:
        print(f"ERROR: input file not found: {args.input}", file=sys.stderr)
        sys.exit(1)

    results = compute_stockout_risk(sku_data)
    print_summary(results)

    if args.output:
        results.to_csv(args.output, index=False)
        print(f"\nResults written to {args.output}")


if __name__ == "__main__":
    main()
