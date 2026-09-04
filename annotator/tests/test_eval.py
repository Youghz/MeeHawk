"""Tests for the annotation evaluator.

The alignment is the part worth testing hard: it is what stops a single missed
rally from invalidating every metric that follows.
"""
from __future__ import annotations

import json
from pathlib import Path

import pytest

from annotator import eval as ev

MATCH_HISTORY = Path(__file__).resolve().parents[2] / "match_history"


def rally(
    winner: str,
    e1: int,
    e2: int,
    impacts: list[dict] | None = None,
    set_number: int = 1,
) -> dict:
    return {
        "winner": winner,
        "scoreE1": e1,
        "scoreE2": e2,
        "setNumber": set_number,
        "serverId": "p3",
        "annotations": [],
        "impacts": impacts or [],
    }


def impact(
    x: float,
    y: float,
    side: str,
    player: str | None = None,
    touch: str | None = None,
    server_pos: bool = False,
    t: float | None = None,
) -> dict:
    out = {"x": x, "y": y, "teamSide": side, "isOutside": False}
    if player:
        out["playerId"] = player
    if touch:
        out["touchType"] = touch
    if server_pos:
        out["isServerPosition"] = True
    if t is not None:
        out["videoTimeSec"] = t
    return out


def sequence(winners: str) -> list[dict]:
    """Build rallies from a compact winner string, e.g. '112' → e1, e1, e2."""
    e1 = e2 = 0
    out = []
    for ch in winners:
        if ch == "1":
            e1 += 1
        else:
            e2 += 1
        out.append(rally(f"e{ch}", e1, e2))
    return out


class TestAlign:
    def test_identical_sequences_align_one_to_one(self) -> None:
        seq = sequence("1122112")
        pairings = ev.align(seq, seq)
        assert all(p.matched for p in pairings)
        assert len(pairings) == len(seq)

    def test_a_missed_rally_costs_exactly_one(self) -> None:
        """The regression that motivates this module.

        Dropping rally 2 of 7 must cost one rally, not desynchronise the rest.
        """
        truth = sequence("1122112")
        agent = truth[:2] + truth[3:]  # rallye d'index 2 manquant

        report = ev._evaluate_oriented(truth, agent)
        assert report.matched_rallies == 6
        assert report.missed_rallies == [2]
        assert report.spurious_rallies == []
        # Les 6 rallyes appariés sont tous corrects — pas de décalage.
        assert report.winner_accuracy == 1.0

    def test_an_invented_rally_is_reported_as_spurious(self) -> None:
        truth = sequence("1122")
        agent = ev.rallies_of({"history": list(truth)})
        agent = agent[:2] + [rally("e1", 3, 0)] + agent[2:]

        report = ev._evaluate_oriented(truth, agent)
        assert report.spurious_rallies, "l'ajout doit être signalé"
        assert report.matched_rallies >= 3

    def test_empty_agent_output(self) -> None:
        report = ev._evaluate_oriented(sequence("112"), [])
        assert report.matched_rallies == 0
        assert report.rally_recall == 0.0
        assert report.missed_rallies == [0, 1, 2]

    def test_naive_positional_comparison_would_have_failed(self) -> None:
        """Guards the premise: without alignment this case scores ~0."""
        truth = sequence("1212121212")
        agent = truth[1:]  # premier rallye manqué

        naive = sum(
            1 for t, a in zip(truth, agent) if t["winner"] == a["winner"]
        ) / len(agent)
        aligned = ev._evaluate_oriented(truth, agent)

        assert naive == 0.0, "la comparaison positionnelle s'effondre"
        assert aligned.winner_accuracy == 1.0
        assert aligned.missed_rallies == [0]


class TestMirror:
    def test_flipped_sides_are_detected_and_corrected(self) -> None:
        truth = [
            rally("e1", 1, 0, [impact(0.2, 0.4, "e1", "p1", "attack")]),
            rally("e2", 1, 1, [impact(0.8, 0.5, "e2", "p3", "serve")]),
        ]
        flipped = ev._mirror({"history": truth})

        report = ev.evaluate({"history": truth}, flipped)
        assert report.mirrored is True
        assert report.winner_accuracy == 1.0
        assert report.mean_impact_distance == pytest.approx(0.0)

    def test_same_orientation_is_not_mirrored(self) -> None:
        truth = [rally("e1", 1, 0, [impact(0.2, 0.4, "e1", "p1")])]
        report = ev.evaluate({"history": truth}, {"history": truth})
        assert report.mirrored is False

    def test_mirror_swaps_player_ids_with_sides(self) -> None:
        state = {"history": [rally("e1", 1, 0, [impact(0.25, 0.4, "e1", "p1")])]}
        imp = ev._mirror(state)["history"][0]["impacts"][0]
        assert imp["teamSide"] == "e2"
        assert imp["playerId"] == "p3"
        assert imp["x"] == pytest.approx(0.75)


class TestMetrics:
    def test_impact_count_error_and_distance(self) -> None:
        truth = [rally("e1", 1, 0, [
            impact(0.2, 0.4, "e1", "p1"),
            impact(0.3, 0.5, "e1", "p2"),
            impact(0.7, 0.5, "e2", "p3"),
        ])]
        agent = [rally("e1", 1, 0, [
            impact(0.22, 0.42, "e1", "p1"),
            impact(0.31, 0.49, "e1", "p2"),
        ])]

        report = ev._evaluate_oriented(truth, agent)
        assert report.impact_count_mae == 1.0
        assert report.mean_impact_distance < 0.05
        assert report.player_accuracy == 1.0

    def test_player_is_scored_only_on_co_located_impacts(self) -> None:
        """A touch annotated on the far side of the court says nothing about
        who played it — counting it would inflate or deflate attribution."""
        truth = [rally("e1", 1, 0, [impact(0.2, 0.4, "e1", "p1")])]
        agent = [rally("e1", 1, 0, [impact(0.9, 0.9, "e2", "p1")])]

        report = ev._evaluate_oriented(truth, agent)
        assert report.player_total == 0
        assert report.mean_impact_distance > ev.IMPACT_MATCH_RADIUS

    def test_rally_start_time_error(self) -> None:
        truth = [rally("e1", 1, 0, [impact(0.9, 0.5, "e2", server_pos=True, t=100.0)])]
        agent = [rally("e1", 1, 0, [impact(0.9, 0.5, "e2", server_pos=True, t=103.5)])]
        report = ev._evaluate_oriented(truth, agent)
        assert report.mean_rally_time_error == pytest.approx(3.5)

    def test_no_timestamps_reports_nothing_rather_than_zero(self) -> None:
        seq = sequence("11")
        report = ev._evaluate_oriented(seq, seq)
        assert report.rally_time_error == []
        assert report.to_json()["rally_time_mae_sec"] is None

    def test_touch_type_accuracy(self) -> None:
        truth = [rally("e1", 1, 0, [
            impact(0.2, 0.4, "e1", "p1", touch="reception"),
            impact(0.3, 0.5, "e1", "p2", touch="attack"),
        ])]
        agent = [rally("e1", 1, 0, [
            impact(0.2, 0.4, "e1", "p1", touch="reception"),
            impact(0.3, 0.5, "e1", "p2", touch="set"),
        ])]
        report = ev._evaluate_oriented(truth, agent)
        assert report.touch_type_accuracy == pytest.approx(0.5)


class TestLoadState:
    def test_accepts_a_raw_agent_state(self, tmp_path: Path) -> None:
        p = tmp_path / "run.json"
        p.write_text(json.dumps({"history": sequence("11")}))
        assert len(ev.load_state(p)["history"]) == 2

    def test_accepts_an_app_archive(self, tmp_path: Path) -> None:
        p = tmp_path / "archive.json"
        p.write_text(json.dumps({"id": "m1", "state": {"history": sequence("1")}}))
        assert len(ev.load_state(p)["history"]) == 1


class TestAgainstRealArchive:
    """The human-scored matches are the actual validation corpus."""

    @pytest.mark.skipif(
        not list(MATCH_HISTORY.glob("*.json")), reason="no archive available"
    )
    def test_an_archive_scores_perfectly_against_itself(self) -> None:
        path = sorted(MATCH_HISTORY.glob("*.json"))[0]
        state = ev.load_state(path)
        report = ev.evaluate(state, state)

        assert report.truth_rallies > 0
        assert report.matched_rallies == report.truth_rallies
        assert report.rally_recall == 1.0
        assert report.winner_accuracy == 1.0
        assert report.mean_impact_distance == pytest.approx(0.0)
        assert report.mirrored is False
