"""The validation corpus: human-scored matches used to evaluate the agent.

Lives in ``validation/`` at the repo root, versioned in git — unlike
``match_history/``, which is runtime data the app rewrites on every scoring
action and which git ignores.

The distinction that matters
----------------------------
Only matches annotated by a **human** are ground truth. Scoring the agent
against an earlier agent run measures reproducibility, not accuracy, and quietly
optimises the prompts toward the previous model's mistakes. Provenance is
therefore mandatory in the manifest, and :func:`ground_truth` refuses anything
that is not human-annotated.

An annotation carrying ``videoTimeSec`` came from the agent: the Flutter app
reads that field but never writes it. :func:`infer_provenance` uses this.
"""
from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Literal

REPO_ROOT = Path(__file__).parent.parent
VALIDATION_DIR = REPO_ROOT / "validation"
MATCHES_DIR = VALIDATION_DIR / "matches"
MANIFEST = VALIDATION_DIR / "manifest.json"
MATCH_HISTORY_DIR = REPO_ROOT / "match_history"

Provenance = Literal["human", "agent"]


class CorpusError(RuntimeError):
    """The corpus is missing, malformed, or asked for something it cannot give."""


@dataclass(frozen=True)
class CorpusEntry:
    """One match in the corpus, plus where its video came from."""

    id: str
    provenance: Provenance
    rallies: int
    video_source: str | None = None
    video_sha1: str | None = None
    notes: str = ""

    @property
    def path(self) -> Path:
        return MATCHES_DIR / f"{self.id}.json"

    @property
    def is_ground_truth(self) -> bool:
        return self.provenance == "human"

    def load(self) -> dict[str, Any]:
        """Return the match state (unwrapping the app archive envelope)."""
        if not self.path.exists():
            raise CorpusError(f"{self.id}: {self.path} is missing")
        data = json.loads(self.path.read_text(encoding="utf-8"))
        return data.get("state", data)


def infer_provenance(state: dict[str, Any]) -> Provenance:
    """Guess who produced [state].

    The agent stamps ``videoTimeSec`` on the server-position impact of every
    rally; the app has no code path that writes it. So a single timestamped
    impact is enough to tell the two apart.
    """
    for rally in state.get("history", []):
        for impact in rally.get("impacts", []):
            if impact.get("videoTimeSec") is not None:
                return "agent"
    return "human"


def _read_manifest() -> list[dict[str, Any]]:
    if not MANIFEST.exists():
        raise CorpusError(
            f"No corpus manifest at {MANIFEST}. See validation/README.md."
        )
    return json.loads(MANIFEST.read_text(encoding="utf-8"))["matches"]


def entries(*, human_only: bool = False) -> list[CorpusEntry]:
    """All corpus entries, newest id last."""
    out = [
        CorpusEntry(
            id=m["id"],
            provenance=m["provenance"],
            rallies=m.get("rallies", 0),
            video_source=m.get("video", {}).get("source"),
            video_sha1=m.get("video", {}).get("sha1"),
            notes=m.get("notes", ""),
        )
        for m in _read_manifest()
    ]
    if human_only:
        out = [e for e in out if e.is_ground_truth]
    return sorted(out, key=lambda e: e.id)


def ground_truth(match_id: str | None = None) -> list[CorpusEntry]:
    """Human-annotated matches, the only valid references.

    With [match_id], returns just that one — and refuses it if it turns out to
    be an agent run, rather than silently producing a meaningless score.
    """
    human = entries(human_only=True)
    if match_id is None:
        if not human:
            raise CorpusError(
                "No human-annotated match in the corpus. Scoring the agent "
                "against another agent run measures reproducibility, not "
                "accuracy — annotate a match by hand first."
            )
        return human

    matching = [e for e in entries() if e.id == match_id]
    if not matching:
        known = ", ".join(e.id for e in entries()) or "none"
        raise CorpusError(f"Unknown match {match_id!r}. Known: {known}")
    entry = matching[0]
    if not entry.is_ground_truth:
        raise CorpusError(
            f"{match_id} is an agent run, not ground truth. Comparing the agent "
            f"to itself would measure reproducibility, not accuracy."
        )
    return [entry]


def sha1(path: Path) -> str:
    digest = hashlib.sha1()  # noqa: S324 — content fingerprint, not a credential
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()
