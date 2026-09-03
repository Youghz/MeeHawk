"""Dart ↔ Python parity.

Replays ``parity/scenario.json`` through :class:`MatchAnnotator` and asserts the
result against ``parity/expected_state.json`` — the golden produced by the Dart
side (``app/test/parity_test.dart``).

A failure here means ``annotator/core.py`` and ``app/lib/state/match_provider.dart``
have drifted. Read parity/README.md before regenerating the golden.
"""
from __future__ import annotations

import json
from pathlib import Path

import pytest

from annotator import MatchAnnotator

PARITY_DIR = Path(__file__).resolve().parents[2] / "parity"
SCENARIO = PARITY_DIR / "scenario.json"
GOLDEN = PARITY_DIR / "expected_state.json"


def _apply(annotator: MatchAnnotator, action: dict) -> None:
    """Execute one scenario action. Comment entries carry no ``op``."""
    op = action.get("op")
    if op is None:
        return

    if op == "start_match":
        annotator.start_match(
            team_e1_name=action["teamE1Name"],
            team_e2_name=action["teamE2Name"],
            p1=action["p1"], p2=action["p2"],
            p3=action["p3"], p4=action["p4"],
            initial_server_id=action["initialServerId"],
        )
    elif op == "impact":
        annotator.add_ball_impact(
            x=action["x"],
            y=action["y"],
            team_side=action["teamSide"],
            is_outside=action.get("isOutside", False),
            is_server_position=action.get("isServerPosition", False),
            is_block=action.get("isBlock", False),
            player_id=action.get("playerId"),
        )
    elif op == "point":
        annotator.add_point(winner=action["winner"])
    elif op == "repeat_points":
        for _ in range(action["count"]):
            annotator.add_point(winner=action["winner"])
    elif op == "undo_impact":
        annotator.undo_last_impact()
    elif op == "undo_point":
        annotator.undo_point()
    elif op == "clear_rally":
        annotator.clear_rally()
    else:
        raise AssertionError(f"Unknown scenario op: {op}")


def _replay() -> dict:
    scenario = json.loads(SCENARIO.read_text(encoding="utf-8"))
    annotator = MatchAnnotator()
    for action in scenario["actions"]:
        _apply(annotator, action)
    state = annotator.to_json()
    # startedAt is "now" on both sides and can never match.
    state.pop("startedAt", None)
    return state


@pytest.mark.skipif(not GOLDEN.exists(), reason="golden not generated yet")
def test_matches_dart_golden() -> None:
    expected = json.loads(GOLDEN.read_text(encoding="utf-8"))
    produced = _replay()

    # Compare the coarse fields first: a mismatch there points straight at the
    # rule that drifted, instead of dumping the whole state dict.
    for key in ("scoreE1", "scoreE2", "setNumber", "matchOver",
                "servingPlayerId", "sets", "nextServerIndex",
                "firstServerIndex"):
        assert produced[key] == expected[key], f"{key} drifted"

    assert len(produced["history"]) == len(expected["history"]), (
        "different number of points recorded"
    )
    for i, (got, want) in enumerate(zip(produced["history"], expected["history"])):
        assert got == want, f"point {i} drifted"

    assert produced == expected
