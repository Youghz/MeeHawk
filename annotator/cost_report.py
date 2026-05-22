"""Display a cost & quality summary of all annotation runs.

Usage:
    uv run --project annotator python -m annotator.cost_report           # all runs
    uv run --project annotator python -m annotator.cost_report --last 5  # last N runs
    uv run --project annotator python -m annotator.cost_report --totals  # totals only
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

COST_LOG = Path(__file__).parent / "cost_log.jsonl"

_COL = {
    "ts":         12,
    "video":      30,
    "model":      18,
    "dur":         6,
    "in_tok":      8,
    "out_tok":     8,
    "think":       7,
    "cost":        8,
    "rallies":     7,
    "x_std":       6,
    "y_std":       6,
    "vt%":         5,
}

_HEADER = (
    f"{'date':<{_COL['ts']}}  "
    f"{'video':<{_COL['video']}}  "
    f"{'model':<{_COL['model']}}  "
    f"{'dur(s)':>{_COL['dur']}}  "
    f"{'in_tok':>{_COL['in_tok']}}  "
    f"{'out_tok':>{_COL['out_tok']}}  "
    f"{'think':>{_COL['think']}}  "
    f"{'cost($)':>{_COL['cost']}}  "
    f"{'rallies':>{_COL['rallies']}}  "
    f"{'x_std':>{_COL['x_std']}}  "
    f"{'y_std':>{_COL['y_std']}}  "
    f"{'vt%':>{_COL['vt%']}}"
)


def _short_video(uri: str) -> str:
    """Shorten a GCS URI or path to fit the column."""
    if uri.startswith("gs://"):
        parts = uri.split("/")
        return "/".join(parts[-2:]) if len(parts) >= 2 else uri
    return Path(uri).name


def _row(r: dict) -> str:
    ts = r.get("ts", "")[:10]
    video = _short_video(r.get("video", ""))[:_COL["video"]]
    model = r.get("model", "")[:_COL["model"]]
    dur = r.get("duration_s", 0)
    t = r.get("total", {})
    q = r.get("quality", {})
    return (
        f"{ts:<{_COL['ts']}}  "
        f"{video:<{_COL['video']}}  "
        f"{model:<{_COL['model']}}  "
        f"{dur:>{_COL['dur']}.1f}  "
        f"{t.get('input_tokens', 0):>{_COL['in_tok']},}  "
        f"{t.get('output_tokens', 0):>{_COL['out_tok']},}  "
        f"{t.get('thinking_tokens', 0):>{_COL['think']},}  "
        f"{t.get('cost_usd', 0):>{_COL['cost']}.4f}  "
        f"{q.get('rallies', '-'):>{_COL['rallies']}}  "
        f"{q.get('x_stddev', '-'):>{_COL['x_std']}}  "
        f"{q.get('y_stddev', '-'):>{_COL['y_std']}}  "
        f"{q.get('video_time_pct', '-'):>{_COL['vt%']}}"
    )


def _totals_row(records: list[dict]) -> str:
    total_in = sum(r.get("total", {}).get("input_tokens", 0) for r in records)
    total_out = sum(r.get("total", {}).get("output_tokens", 0) for r in records)
    total_think = sum(r.get("total", {}).get("thinking_tokens", 0) for r in records)
    total_cost = sum(r.get("total", {}).get("cost_usd", 0.0) for r in records)
    n = len(records)
    sep = "─" * len(_HEADER)
    return (
        f"{sep}\n"
        f"{'TOTAL / ' + str(n) + ' runs':<{_COL['ts'] + 2 + _COL['video'] + 2 + _COL['model']}}  "
        f"{'':>{_COL['dur']}}  "
        f"{total_in:>{_COL['in_tok']},}  "
        f"{total_out:>{_COL['out_tok']},}  "
        f"{total_think:>{_COL['think']},}  "
        f"{total_cost:>{_COL['cost']}.4f}"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="MeeHawk annotation cost report")
    parser.add_argument("--last", type=int, default=0, metavar="N", help="Show only the last N runs")
    parser.add_argument("--totals", action="store_true", help="Show totals only")
    args = parser.parse_args()

    if not COST_LOG.exists():
        print(f"No cost log found at {COST_LOG}. Run an annotation first.")
        return

    records = [json.loads(line) for line in COST_LOG.read_text().splitlines() if line.strip()]

    if not records:
        print("Cost log is empty.")
        return

    if args.last:
        records = records[-args.last:]

    if not args.totals:
        sep = "─" * len(_HEADER)
        print(sep)
        print(_HEADER)
        print(sep)
        for r in records:
            print(_row(r))

    print(_totals_row(records))

    # Column legend
    print()
    print("  x_std / y_std : stddev of ball-impact coordinates (higher = more varied, better)")
    print("  vt%           : % of impacts with video_time_sec set")


if __name__ == "__main__":
    main()
