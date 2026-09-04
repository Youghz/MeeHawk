"""Promote a match you just annotated into the validation corpus.

Copies the archive out of ``match_history/`` — runtime data the app keeps
rewriting — into ``validation/matches/``, which is versioned and never written
by the app. Registers it in the manifest with its provenance and the fingerprint
of its video.

Usage:
    uv run meehawk-promote match_20260601T104500000 \\
        --video-source "https://youtube.com/watch?v=..." \\
        --by "Hugo" \\
        --notes "Tournoi de Marseille, contre-jour en fin de set"
"""
from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path
from typing import Any

from .corpus import (
    MANIFEST,
    MATCH_HISTORY_DIR,
    MATCHES_DIR,
    VALIDATION_DIR,
    infer_provenance,
    sha1,
)

WEB_VIDEOS_DIR = Path(__file__).parent.parent / "app" / "web" / "videos"


def _load_manifest() -> dict[str, Any]:
    if MANIFEST.exists():
        return json.loads(MANIFEST.read_text(encoding="utf-8"))
    return {
        "description": "Corpus de validation de l'agent d'annotation. "
                       "Seules les entrées provenance=human sont des vérités terrain.",
        "matches": [],
    }


def promote(
    match_id: str,
    *,
    video_source: str | None = None,
    annotated_by: str = "",
    notes: str = "",
    force: bool = False,
) -> dict[str, Any]:
    """Copy [match_id] into the corpus and return its manifest entry."""
    source = MATCH_HISTORY_DIR / f"{match_id}.json"
    if not source.exists():
        raise FileNotFoundError(
            f"{source} not found. Matches only land in match_history/ when you "
            f"annotate on desktop or mobile — on web they stay in the browser's "
            f"local storage."
        )

    archive = json.loads(source.read_text(encoding="utf-8"))
    state = archive.get("state", archive)
    provenance = infer_provenance(state)

    MATCHES_DIR.mkdir(parents=True, exist_ok=True)
    destination = MATCHES_DIR / f"{match_id}.json"
    if destination.exists() and not force:
        raise FileExistsError(
            f"{destination} already exists. Pass --force to overwrite — but a "
            f"reference that changes invalidates every score measured against it."
        )
    shutil.copy2(source, destination)

    video = WEB_VIDEOS_DIR / f"{match_id}.mp4"
    entry: dict[str, Any] = {
        "id": match_id,
        "provenance": provenance,
        "annotated_by": annotated_by or ("agent" if provenance == "agent" else ""),
        "rallies": len(state.get("history", [])),
        "impacts": sum(len(r.get("impacts", [])) for r in state.get("history", [])),
        "teams": [t["name"] for t in state.get("teams", {}).values()],
        "video": {
            "source": video_source,
            "local": f"app/web/videos/{match_id}.mp4",
            # Fingerprint rather than commit: the video is hundreds of megabytes,
            # but without it you cannot tell whether you have the right footage.
            "sha1": sha1(video) if video.exists() else None,
            "bytes": video.stat().st_size if video.exists() else None,
        },
        "notes": notes,
    }

    manifest = _load_manifest()
    manifest["matches"] = [
        m for m in manifest["matches"] if m["id"] != match_id
    ] + [entry]
    manifest["matches"].sort(key=lambda m: m["id"])
    VALIDATION_DIR.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    return entry


def main() -> None:
    ap = argparse.ArgumentParser(
        description="Promote a match from match_history/ into the validation corpus."
    )
    ap.add_argument("match_id", help="e.g. match_20260601T104500000")
    ap.add_argument("--video-source", help="URL or description of the footage")
    ap.add_argument("--by", default="", help="Who annotated it")
    ap.add_argument("--notes", default="", help="Shooting conditions, caveats…")
    ap.add_argument("--force", action="store_true", help="Overwrite an existing entry")
    args = ap.parse_args()

    try:
        entry = promote(
            args.match_id,
            video_source=args.video_source,
            annotated_by=args.by,
            notes=args.notes,
            force=args.force,
        )
    except (FileNotFoundError, FileExistsError) as exc:
        print(f"✗ {exc}", file=sys.stderr)
        raise SystemExit(1) from exc

    print(
        f"✓ {entry['id']} → validation/matches/  "
        f"[{entry['provenance']}] {entry['rallies']} rallyes, "
        f"{entry['impacts']} impacts",
        file=sys.stderr,
    )
    if entry["provenance"] == "agent":
        print(
            "  ⚠ détecté comme sortie d'agent (videoTimeSec présents) — ne servira "
            "PAS de vérité terrain. Corrige provenance dans le manifeste si c'est "
            "une erreur.",
            file=sys.stderr,
        )
    if entry["video"]["sha1"] is None:
        print(
            f"  ⚠ aucune vidéo dans app/web/videos/{entry['id']}.mp4 — le corpus ne "
            "pourra pas être rejoué sans elle.",
            file=sys.stderr,
        )


if __name__ == "__main__":
    main()
