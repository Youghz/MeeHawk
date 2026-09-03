"""Token accounting, run cost logging, and accuracy scoring against ground truth."""
from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

PKG_DIR = Path(__file__).parent
COST_LOG = PKG_DIR / "cost_log.jsonl"
GROUND_TRUTH = PKG_DIR / "ground_truth.json"

#: Vertex AI pricing, USD per 1M tokens. Update when Google changes the rate card.
PRICE_PER_MTOK = {"input": 0.075, "output": 0.30, "thinking": 3.50}


class Usage:
    """Accumulates token counts across every API call of a run."""

    def __init__(self) -> None:
        self.inp = 0
        self.out = 0
        self.think = 0
        self.cached = 0

    def add(self, meta: Any) -> None:
        """Fold in one response's ``usage_metadata``. Tolerates None."""
        if meta is None:
            return
        self.inp += meta.prompt_token_count or 0
        self.out += meta.candidates_token_count or 0
        self.think += meta.thoughts_token_count or 0
        self.cached += meta.cached_content_token_count or 0

    def cost_usd(self) -> float:
        return (
            self.inp * PRICE_PER_MTOK["input"]
            + self.out * PRICE_PER_MTOK["output"]
            + self.think * PRICE_PER_MTOK["thinking"]
        ) / 1_000_000


def score_accuracy(state: dict[str, Any]) -> dict[str, Any] | None:
    """Compare an annotated match against ``ground_truth.json``.

    Returns None when there is no ground truth to compare against. Otherwise
    reports per-rally winner accuracy and the final score drift.
    """
    if not GROUND_TRUTH.exists():
        return None
    truth = json.loads(GROUND_TRUTH.read_text())["rally_sequence"]
    history = state.get("history", [])
    n = min(len(history), len(truth))
    if n == 0:
        return None

    matched = sum(1 for i in range(n) if history[i]["winner"] == truth[i]["winner"])
    return {
        "compared_rallies": n,
        "winner_accuracy": round(matched / n, 3),
        "score_drift_e1": abs(history[n - 1]["scoreE1"] - truth[n - 1]["score_e1"]),
        "score_drift_e2": abs(history[n - 1]["scoreE2"] - truth[n - 1]["score_e2"]),
    }


def log_run(
    *,
    label: str,
    model: str,
    video: str,
    duration_s: float,
    usage: Usage,
    rallies: int,
    ambiguous: int,
    accuracy: dict[str, Any] | None,
) -> dict[str, Any]:
    """Append one run to ``cost_log.jsonl`` and return the logged entry."""
    entry: dict[str, Any] = {
        "ts": datetime.now(timezone.utc).isoformat(),
        "label": label,
        "video": video,
        "model": model,
        "duration_s": round(duration_s, 1),
        "input_tokens": usage.inp,
        "output_tokens": usage.out,
        "thinking_tokens": usage.think,
        "cached_tokens": usage.cached,
        "cost_usd": round(usage.cost_usd(), 6),
        "rallies": rallies,
        "ambiguous_count": ambiguous,
    }
    if accuracy:
        entry["score_accuracy"] = accuracy
    with COST_LOG.open("a", encoding="utf-8") as f:
        f.write(json.dumps(entry) + "\n")
    return entry
