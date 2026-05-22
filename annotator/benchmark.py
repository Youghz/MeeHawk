"""Compare annotation runs against ground truth.

Usage:
  uv run --project annotator python -m annotator.benchmark
  uv run --project annotator python -m annotator.benchmark --label set1-v3
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

ANNOTATOR_DIR = Path(__file__).parent
COST_LOG = ANNOTATOR_DIR / "cost_log.jsonl"
GROUND_TRUTH = ANNOTATOR_DIR / "ground_truth.json"


def load_ground_truth() -> list[dict]:
    return json.loads(GROUND_TRUTH.read_text())["rally_sequence"]


def score_accuracy(result_history: list[dict], gt_sequence: list[dict]) -> dict:
    """Compare winner sequence of a run against ground truth.

    Returns:
      matched: number of rallies where winner matches
      compared: total rallies compared (min of both lengths)
      accuracy: matched / compared
      score_drift: cumulative score difference at last compared rally
    """
    n = min(len(result_history), len(gt_sequence))
    if n == 0:
        return {"matched": 0, "compared": 0, "accuracy": 0.0, "score_drift": 0}

    matched = sum(
        1 for i in range(n)
        if result_history[i]["winner"] == gt_sequence[i]["winner"]
    )

    last_result = result_history[n - 1]
    last_gt = gt_sequence[n - 1]
    drift_e1 = abs(last_result["scoreE1"] - last_gt["score_e1"])
    drift_e2 = abs(last_result["scoreE2"] - last_gt["score_e2"])

    return {
        "matched": matched,
        "compared": n,
        "accuracy": round(matched / n, 3),
        "score_drift_e1": drift_e1,
        "score_drift_e2": drift_e2,
    }


def load_state_history(label: str) -> list[dict] | None:
    state_path = ANNOTATOR_DIR / f"match_state_{label}.json"
    if not state_path.exists():
        return None
    data = json.loads(state_path.read_text())
    return data.get("history", [])


def print_report(label: str | None = None) -> None:
    if not COST_LOG.exists():
        print("No cost_log.jsonl found.")
        return

    gt = load_ground_truth()
    runs = [json.loads(l) for l in COST_LOG.read_text().splitlines() if l.strip()]

    if label:
        runs = [r for r in runs if r.get("label") == label]

    print(f"\n{'Run':<20} {'Strategy':<16} {'Rallies':>8} {'Acc%':>6} {'Ambig':>6} {'Cost$':>7} {'Time(s)':>8}")
    print("-" * 80)

    for run in runs:
        lbl = run.get("label", "?")
        strategy = run.get("strategy", "two_pass")
        cost = run.get("total", {}).get("cost_usd", run.get("cost_usd", 0.0))
        duration = run.get("duration_s", 0.0)
        quality = run.get("quality", {})
        rallies = quality.get("rallies", 0)
        ambiguous = run.get("ambiguous_count", 0)

        # Score accuracy
        history = load_state_history(lbl)
        if history:
            acc = score_accuracy(history, gt)
            acc_str = f"{acc['accuracy']*100:.1f}"
            rallies = len(history)
        else:
            acc_str = "—"

        print(f"{lbl:<20} {strategy:<16} {rallies:>8} {acc_str:>6} {ambiguous:>6} {cost:>7.4f} {duration:>8.1f}")

    print()


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--label", help="Filter by run label")
    args = ap.parse_args()
    print_report(args.label)


if __name__ == "__main__":
    main()
