"""Cost and accuracy report over past annotation runs.

Reads ``cost_log.jsonl``, written by :func:`annotator.cost.log_run`.

Usage:
    uv run --project annotator python -m annotator.report
    uv run --project annotator python -m annotator.report --last 5
    uv run --project annotator python -m annotator.report --label set1-v5
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from .cost import COST_LOG

_HEADER = (
    f"{'date':<11} {'label':<18} {'model':<20} {'dur(s)':>7} "
    f"{'in_tok':>10} {'out_tok':>8} {'think':>8} {'cost($)':>8} "
    f"{'rallies':>8} {'ambig':>6} {'acc%':>6}"
)


def _short_video(uri: str) -> str:
    if uri.startswith(("gs://", "http://", "https://")):
        return uri.rsplit("/", 1)[-1]
    return Path(uri).name


def _row(r: dict[str, Any]) -> str:
    accuracy = r.get("score_accuracy") or {}
    acc = f"{accuracy['winner_accuracy'] * 100:.1f}" if accuracy else "—"
    return (
        f"{r.get('ts', '')[:10]:<11} "
        f"{r.get('label', '?')[:18]:<18} "
        f"{r.get('model', '')[:20]:<20} "
        f"{r.get('duration_s', 0):>7.1f} "
        f"{r.get('input_tokens', 0):>10,} "
        f"{r.get('output_tokens', 0):>8,} "
        f"{r.get('thinking_tokens', 0):>8,} "
        f"{r.get('cost_usd', 0.0):>8.4f} "
        f"{r.get('rallies', 0):>8} "
        f"{r.get('ambiguous_count', 0):>6} "
        f"{acc:>6}"
    )


def _totals(records: list[dict[str, Any]]) -> str:
    return (
        f"{'TOTAL / ' + str(len(records)) + ' runs':<58} "
        f"{sum(r.get('input_tokens', 0) for r in records):>10,} "
        f"{sum(r.get('output_tokens', 0) for r in records):>8,} "
        f"{sum(r.get('thinking_tokens', 0) for r in records):>8,} "
        f"{sum(r.get('cost_usd', 0.0) for r in records):>8.4f}"
    )


def main() -> None:
    ap = argparse.ArgumentParser(description="Annotation cost & accuracy report")
    ap.add_argument("--last", type=int, metavar="N", help="Show only the last N runs")
    ap.add_argument("--label", help="Show only runs with this label")
    args = ap.parse_args()

    if not COST_LOG.exists():
        print(f"No cost log at {COST_LOG}. Run an annotation first.")
        return

    records = [
        json.loads(line)
        for line in COST_LOG.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]
    if args.label:
        records = [r for r in records if r.get("label") == args.label]
    if args.last:
        records = records[-args.last:]

    if not records:
        print("No matching runs.")
        return

    sep = "─" * len(_HEADER)
    print(sep)
    print(_HEADER)
    print(sep)
    for r in records:
        print(_row(r))
    print(sep)
    print(_totals(records))
    print("\n  acc% : per-rally winner accuracy vs ground_truth.json")


if __name__ == "__main__":
    main()
