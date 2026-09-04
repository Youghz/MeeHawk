"""Evaluate an annotated match against a human-scored one.

Both sides are ``MatchCodec`` documents — the agent writes the same schema the
Flutter app does — so a run can be scored directly against any archive in
``match_history/``.

Why alignment comes first
-------------------------
The naive comparison walks ``history[i]`` against ``truth[i]``. One rally
missed by the agent shifts every later rally, and the score collapses to noise:
an agent that drops rally 3 of 31 but nails the other 30 reports ~50%, not 97%.

So rallies are aligned before anything is measured. The alignment key is the
score *after* the point, which is monotone and self-correcting: even after an
insertion or a deletion, the scoreboard resynchronises. What the agent missed
or invented is then reported as such, instead of being smeared over every
subsequent metric.

Only human-annotated matches count as references — see :mod:`annotator.corpus`.

Usage:
    uv run meehawk-eval annotator/match_state_run1.json
    uv run meehawk-eval annotator/match_state_run1.json --truth match_20260522T030751000
"""
from __future__ import annotations

import argparse
import json
import math
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterable

from . import corpus

#: Two rallies are candidates for the same point if their post-point scores match.
#: Impacts are then compared positionally within the rally.
_Rally = dict[str, Any]

#: Distance in normalized court units under which two impacts are "in the same place".
#: 0.08 ≈ 1.3 m on a 16 m court — tighter than that measures Gemini's pixel noise,
#: looser stops distinguishing a dig from a set.
IMPACT_MATCH_RADIUS = 0.08


# ── Loading ──────────────────────────────────────────────────────────────────

def load_state(path: Path) -> dict[str, Any]:
    """Read a match file, accepting either a raw state or an app archive.

    The agent writes ``{...state...}``; the app writes ``{"id", "state", ...}``.
    """
    data = json.loads(path.read_text(encoding="utf-8"))
    return data["state"] if "state" in data and "history" in data.get("state", {}) else data


def rallies_of(state: dict[str, Any]) -> list[_Rally]:
    return state.get("history", [])


# ── Alignment ────────────────────────────────────────────────────────────────

@dataclass
class Pairing:
    """One aligned position: a truth rally, an agent rally, or both."""

    truth_index: int | None
    agent_index: int | None

    @property
    def matched(self) -> bool:
        return self.truth_index is not None and self.agent_index is not None


def _score_key(rally: _Rally) -> tuple[int, int, int]:
    return (rally.get("setNumber", 1), rally["scoreE1"], rally["scoreE2"])


def align(truth: list[_Rally], agent: list[_Rally]) -> list[Pairing]:
    """Align two rally sequences on their post-point score.

    Classic edit-distance alignment: matching a pair costs 0, skipping on either
    side costs 1. Because the scoreboard is monotone, this recovers cleanly from
    a missed or invented rally instead of desynchronising for good.
    """
    n, m = len(truth), len(agent)
    # cost[i][j] = cheapest alignment of truth[i:] with agent[j:]
    cost = [[0] * (m + 1) for _ in range(n + 1)]
    for i in range(n - 1, -1, -1):
        cost[i][m] = n - i
    for j in range(m - 1, -1, -1):
        cost[n][j] = m - j
    for i in range(n - 1, -1, -1):
        for j in range(m - 1, -1, -1):
            same = _score_key(truth[i]) == _score_key(agent[j])
            cost[i][j] = min(
                (0 if same else 1) + cost[i + 1][j + 1],
                1 + cost[i + 1][j],
                1 + cost[i][j + 1],
            )

    pairings: list[Pairing] = []
    i = j = 0
    while i < n and j < m:
        same = _score_key(truth[i]) == _score_key(agent[j])
        if cost[i][j] == (0 if same else 1) + cost[i + 1][j + 1]:
            pairings.append(Pairing(i, j) if same else Pairing(i, None))
            if not same:
                pairings.append(Pairing(None, j))
            i += 1
            j += 1
        elif cost[i][j] == 1 + cost[i + 1][j]:
            pairings.append(Pairing(i, None))
            i += 1
        else:
            pairings.append(Pairing(None, j))
            j += 1
    pairings += [Pairing(k, None) for k in range(i, n)]
    pairings += [Pairing(None, k) for k in range(j, m)]
    return pairings


# ── Side mapping ─────────────────────────────────────────────────────────────

def _swap_side(side: str) -> str:
    return "e2" if side == "e1" else "e1"


def _mirror(state: dict[str, Any]) -> dict[str, Any]:
    """Return [state] with e1/e2 swapped and x coordinates mirrored.

    The agent picks e1 = left team from the camera view; a human may have
    entered the match from the other side. Without testing both mappings, a
    flipped run scores near zero on everything and looks like a total failure
    rather than a labelling difference.
    """
    mirrored = json.loads(json.dumps(state))
    for rally in mirrored.get("history", []):
        rally["winner"] = _swap_side(rally["winner"])
        rally["scoreE1"], rally["scoreE2"] = rally["scoreE2"], rally["scoreE1"]
        for impact in rally.get("impacts", []):
            impact["teamSide"] = _swap_side(impact["teamSide"])
            impact["x"] = 1.0 - impact["x"]
            pid = impact.get("playerId")
            if pid in _PLAYER_MIRROR:
                impact["playerId"] = _PLAYER_MIRROR[pid]
    return mirrored


#: p1/p2 belong to e1, p3/p4 to e2 — mirroring the sides mirrors the ids too.
_PLAYER_MIRROR = {"p1": "p3", "p2": "p4", "p3": "p1", "p4": "p2"}


# ── Metrics ──────────────────────────────────────────────────────────────────

@dataclass
class Report:
    truth_rallies: int = 0
    agent_rallies: int = 0
    matched_rallies: int = 0
    missed_rallies: list[int] = field(default_factory=list)
    spurious_rallies: list[int] = field(default_factory=list)

    winner_correct: int = 0
    winner_total: int = 0

    impact_count_abs_error: list[int] = field(default_factory=list)
    impact_distance: list[float] = field(default_factory=list)
    player_correct: int = 0
    player_total: int = 0
    touch_type_correct: int = 0
    touch_type_total: int = 0
    rally_time_error: list[float] = field(default_factory=list)

    mirrored: bool = False

    # ── derived ──

    @property
    def rally_recall(self) -> float:
        return _ratio(self.matched_rallies, self.truth_rallies)

    @property
    def rally_precision(self) -> float:
        return _ratio(self.matched_rallies, self.agent_rallies)

    @property
    def winner_accuracy(self) -> float:
        return _ratio(self.winner_correct, self.winner_total)

    @property
    def player_accuracy(self) -> float:
        return _ratio(self.player_correct, self.player_total)

    @property
    def touch_type_accuracy(self) -> float:
        return _ratio(self.touch_type_correct, self.touch_type_total)

    @property
    def impact_count_mae(self) -> float:
        return _mean(self.impact_count_abs_error)

    @property
    def mean_impact_distance(self) -> float:
        return _mean(self.impact_distance)

    @property
    def mean_rally_time_error(self) -> float:
        return _mean(self.rally_time_error)

    def to_json(self) -> dict[str, Any]:
        return {
            "rallies": {
                "truth": self.truth_rallies,
                "agent": self.agent_rallies,
                "matched": self.matched_rallies,
                "recall": round(self.rally_recall, 3),
                "precision": round(self.rally_precision, 3),
                "missed_truth_indices": self.missed_rallies,
                "spurious_agent_indices": self.spurious_rallies,
            },
            "winner_accuracy": round(self.winner_accuracy, 3),
            "impacts": {
                "count_mae": round(self.impact_count_mae, 2),
                "mean_distance": round(self.mean_impact_distance, 4)
                if self.impact_distance
                else None,
                "player_accuracy": round(self.player_accuracy, 3)
                if self.player_total
                else None,
                "touch_type_accuracy": round(self.touch_type_accuracy, 3)
                if self.touch_type_total
                else None,
            },
            "rally_time_mae_sec": round(self.mean_rally_time_error, 2)
            if self.rally_time_error
            else None,
            "mirrored": self.mirrored,
        }


def _ratio(num: int, den: int) -> float:
    return num / den if den else 0.0


def _mean(values: Iterable[float]) -> float:
    values = list(values)
    return sum(values) / len(values) if values else 0.0


def _real_impacts(rally: _Rally) -> list[dict[str, Any]]:
    """Ball contacts only — server-position markers are not touches."""
    return [i for i in rally.get("impacts", []) if not i.get("isServerPosition")]


def _rally_start_sec(rally: _Rally) -> float | None:
    for impact in rally.get("impacts", []):
        if impact.get("isServerPosition") and impact.get("videoTimeSec") is not None:
            return impact["videoTimeSec"]
    return None


def _score_rally_pair(truth: _Rally, agent: _Rally, report: Report) -> None:
    report.winner_total += 1
    if truth["winner"] == agent["winner"]:
        report.winner_correct += 1

    t_impacts, a_impacts = _real_impacts(truth), _real_impacts(agent)
    report.impact_count_abs_error.append(abs(len(t_impacts) - len(a_impacts)))

    # Impacts are compared in order: within a rally the touch sequence is the
    # signal, and a positional walk keeps a missed touch from being silently
    # paired with a distant one.
    for t_imp, a_imp in zip(t_impacts, a_impacts):
        distance = math.dist((t_imp["x"], t_imp["y"]), (a_imp["x"], a_imp["y"]))
        report.impact_distance.append(distance)

        # Attribution is only meaningful when the impacts refer to the same
        # moment of the rally; a far-away pair says nothing about the player.
        if distance > IMPACT_MATCH_RADIUS:
            continue
        if t_imp.get("playerId"):
            report.player_total += 1
            if t_imp["playerId"] == a_imp.get("playerId"):
                report.player_correct += 1
        if t_imp.get("touchType"):
            report.touch_type_total += 1
            if t_imp["touchType"] == a_imp.get("touchType"):
                report.touch_type_correct += 1

    t_start, a_start = _rally_start_sec(truth), _rally_start_sec(agent)
    if t_start is not None and a_start is not None:
        report.rally_time_error.append(abs(t_start - a_start))


def _evaluate_oriented(truth: list[_Rally], agent: list[_Rally]) -> Report:
    report = Report(truth_rallies=len(truth), agent_rallies=len(agent))
    for pairing in align(truth, agent):
        if pairing.matched:
            report.matched_rallies += 1
            _score_rally_pair(
                truth[pairing.truth_index], agent[pairing.agent_index], report
            )
        elif pairing.truth_index is not None:
            report.missed_rallies.append(pairing.truth_index)
        elif pairing.agent_index is not None:
            report.spurious_rallies.append(pairing.agent_index)
    return report


def evaluate(truth_state: dict[str, Any], agent_state: dict[str, Any]) -> Report:
    """Score [agent_state] against [truth_state], trying both side mappings."""
    direct = _evaluate_oriented(rallies_of(truth_state), rallies_of(agent_state))
    flipped = _evaluate_oriented(rallies_of(truth_state), rallies_of(_mirror(agent_state)))

    # More aligned rallies means the sides line up; ties go to the direct reading.
    if (flipped.matched_rallies, flipped.winner_correct) > (
        direct.matched_rallies,
        direct.winner_correct,
    ):
        flipped.mirrored = True
        return flipped
    return direct


# ── CLI ──────────────────────────────────────────────────────────────────────

def format_report(report: Report, *, truth_name: str, agent_name: str) -> str:
    r = report
    lines = [
        f"── {agent_name}  vs  {truth_name} ──",
        "",
        f"  Rallyes        {r.matched_rallies}/{r.truth_rallies} appariés"
        f"   (rappel {r.rally_recall:.0%}, précision {r.rally_precision:.0%})",
    ]
    if r.missed_rallies:
        lines.append(f"    manqués      {len(r.missed_rallies)} → {r.missed_rallies[:12]}")
    if r.spurious_rallies:
        lines.append(f"    inventés     {len(r.spurious_rallies)} → {r.spurious_rallies[:12]}")
    lines += [
        f"  Vainqueur      {r.winner_accuracy:.1%}  ({r.winner_correct}/{r.winner_total})",
        f"  Touches/rallye MAE {r.impact_count_mae:.2f}",
    ]
    if r.impact_distance:
        lines.append(f"  Position       distance moy. {r.mean_impact_distance:.3f}")
    if r.player_total:
        lines.append(
            f"  Joueur         {r.player_accuracy:.1%}  ({r.player_correct}/{r.player_total})"
        )
    if r.touch_type_total:
        lines.append(
            f"  Type de touche {r.touch_type_accuracy:.1%}"
            f"  ({r.touch_type_correct}/{r.touch_type_total})"
        )
    if r.rally_time_error:
        lines.append(f"  Début rallye   MAE {r.mean_rally_time_error:.1f}s")
    else:
        lines.append("  Début rallye   — (aucun videoTimeSec des deux côtés)")
    if r.mirrored:
        lines.append("  ⚠ côtés inversés — évalué après miroir e1↔e2")
    return "\n".join(lines)


def main() -> None:
    ap = argparse.ArgumentParser(
        description="Score an annotated run against the human-scored corpus.",
    )
    ap.add_argument("run", help="match_state JSON produced by the agent")
    ap.add_argument(
        "--truth",
        help="Reference: a corpus match id, or a path to a match JSON. "
             "Defaults to the whole human-annotated corpus.",
    )
    ap.add_argument("--json", action="store_true", help="Machine-readable output")
    args = ap.parse_args()

    run_state = load_state(Path(args.run))
    run_name = Path(args.run).name

    # An explicit path bypasses the corpus — useful for a one-off comparison,
    # at the cost of the provenance guard.
    if args.truth and Path(args.truth).exists():
        references = [(Path(args.truth).name, load_state(Path(args.truth)))]
    else:
        try:
            entries = corpus.ground_truth(args.truth)
        except corpus.CorpusError as exc:
            ap.error(str(exc))
        references = [(e.id, e.load()) for e in entries]

    reports = [
        (name, evaluate(truth_state, run_state)) for name, truth_state in references
    ]

    if args.json:
        print(json.dumps(
            {name: report.to_json() for name, report in reports}, indent=2
        ))
        return

    for name, report in reports:
        print(format_report(report, truth_name=name, agent_name=run_name))
        print()


if __name__ == "__main__":
    main()
