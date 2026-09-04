"""Tests for the validation corpus and its provenance guard.

The guard is the point of the module: scoring the agent against an earlier agent
run measures reproducibility, not accuracy, and silently tunes the prompts toward
the previous model's mistakes.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

import pytest

from annotator import corpus


def state_with(*, timestamped: bool) -> dict:
    impact = {"x": 0.5, "y": 0.5, "teamSide": "e2", "isOutside": False,
              "isServerPosition": True}
    if timestamped:
        impact["videoTimeSec"] = 12.0
    return {
        "history": [
            {"winner": "e1", "scoreE1": 1, "scoreE2": 0, "setNumber": 1,
             "serverId": "p3", "annotations": [], "impacts": [impact]}
        ]
    }


class TestInferProvenance:
    def test_timestamped_impacts_mean_agent(self) -> None:
        assert corpus.infer_provenance(state_with(timestamped=True)) == "agent"

    def test_no_timestamp_means_human(self) -> None:
        assert corpus.infer_provenance(state_with(timestamped=False)) == "human"

    def test_empty_match_defaults_to_human(self) -> None:
        assert corpus.infer_provenance({"history": []}) == "human"

    def test_a_single_timestamp_anywhere_is_enough(self) -> None:
        """The agent stamps only the server-position impact of each rally."""
        state = state_with(timestamped=False)
        state["history"].append({
            "winner": "e2", "scoreE1": 1, "scoreE2": 1, "setNumber": 1,
            "serverId": "p1", "annotations": [],
            "impacts": [
                {"x": 0.2, "y": 0.3, "teamSide": "e1", "isOutside": False},
                {"x": 0.8, "y": 0.4, "teamSide": "e2", "isOutside": False,
                 "videoTimeSec": 40.0},
            ],
        })
        assert corpus.infer_provenance(state) == "agent"


class TestGroundTruthGuard:
    def test_refuses_an_agent_run_as_reference(self, monkeypatch) -> None:
        monkeypatch.setattr(corpus, "_read_manifest", lambda: [
            {"id": "run_a", "provenance": "agent", "rallies": 6},
            {"id": "human_a", "provenance": "human", "rallies": 67},
        ])
        with pytest.raises(corpus.CorpusError, match="agent run, not ground truth"):
            corpus.ground_truth("run_a")

    def test_accepts_a_human_reference(self, monkeypatch) -> None:
        monkeypatch.setattr(corpus, "_read_manifest", lambda: [
            {"id": "human_a", "provenance": "human", "rallies": 67},
        ])
        assert [e.id for e in corpus.ground_truth("human_a")] == ["human_a"]

    def test_defaults_to_every_human_match(self, monkeypatch) -> None:
        monkeypatch.setattr(corpus, "_read_manifest", lambda: [
            {"id": "run_a", "provenance": "agent", "rallies": 6},
            {"id": "human_b", "provenance": "human", "rallies": 40},
            {"id": "human_a", "provenance": "human", "rallies": 67},
        ])
        assert [e.id for e in corpus.ground_truth()] == ["human_a", "human_b"]

    def test_explains_itself_when_the_corpus_has_no_human_match(
        self, monkeypatch
    ) -> None:
        monkeypatch.setattr(corpus, "_read_manifest", lambda: [
            {"id": "run_a", "provenance": "agent", "rallies": 6},
        ])
        with pytest.raises(corpus.CorpusError, match="annotate a match by hand"):
            corpus.ground_truth()

    def test_unknown_id_lists_what_is_available(self, monkeypatch) -> None:
        monkeypatch.setattr(corpus, "_read_manifest", lambda: [
            {"id": "human_a", "provenance": "human", "rallies": 67},
        ])
        with pytest.raises(corpus.CorpusError, match="human_a"):
            corpus.ground_truth("nope")


class TestRealCorpus:
    def test_manifest_is_present_and_well_formed(self) -> None:
        for entry in corpus.entries():
            assert entry.provenance in ("human", "agent")
            assert entry.rallies > 0
            assert entry.path.exists(), f"{entry.id}: annotation manquante"

    def test_declared_provenance_matches_the_content(self) -> None:
        """The manifest must not drift from what the files actually contain."""
        for entry in corpus.entries():
            assert corpus.infer_provenance(entry.load()) == entry.provenance, (
                f"{entry.id}: manifeste dit {entry.provenance}"
            )

    def test_at_least_one_human_reference_exists(self) -> None:
        assert corpus.ground_truth(), "aucune vérité terrain dans le corpus"

    def test_the_corpus_is_versioned_unlike_match_history(self) -> None:
        gitignore = (corpus.REPO_ROOT / ".gitignore").read_text(encoding="utf-8")
        assert "/match_history/" in gitignore
        assert "validation" not in gitignore


class TestSha1:
    def test_fingerprints_file_content(self, tmp_path: Path) -> None:
        f = tmp_path / "clip.mp4"
        f.write_bytes(b"beach volley")
        assert corpus.sha1(f) == hashlib.sha1(b"beach volley").hexdigest()

    def test_handles_a_file_larger_than_one_chunk(self, tmp_path: Path) -> None:
        """Videos are read in 1 MiB chunks — the loop must not drop any."""
        f = tmp_path / "big.mp4"
        payload = b"x" * (2 << 20)
        f.write_bytes(payload)
        assert corpus.sha1(f) == hashlib.sha1(payload).hexdigest()
