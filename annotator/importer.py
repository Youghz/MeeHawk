"""Import an annotated match into the Flutter app.

The app and this agent share ``match_history/`` at the repo root: one JSON file
per match, written by whichever side produced it, read by both. There is no API
between them — the schema (``annotator/state.py::MatchCodec``, mirrored by
``app/lib/data/match_codec.dart``) is the entire contract.

Usage:
    uv run --project annotator python -m annotator.importer match_state_run1.json
    uv run --project annotator python -m annotator.importer state.json --video clip.mp4
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).parent.parent
MATCH_HISTORY_DIR = REPO_ROOT / "match_history"
WEB_VIDEOS_DIR = REPO_ROOT / "app" / "web" / "videos"


def match_id_for(started_at: str) -> str:
    """Derive a match ID from an ISO-8601 timestamp.

    Mirrors ``MatchArchive.idFor`` in ``app/lib/domain/match_archive.dart`` —
    both sides must produce the same ID for the same match, or importing would
    create a duplicate instead of updating the existing archive.
    """
    return f"match_{re.sub(r'[-:.]|Z', '', started_at)}"


def import_match(
    state: dict[str, Any],
    match_id: str | None = None,
    video_path: Path | None = None,
) -> str:
    """Write [state] into ``match_history/<id>.json``. Returns the match ID.

    When [video_path] is given, the file is copied into the app's web assets
    and referenced from the archive so replay can play it back.
    """
    match_id = match_id or match_id_for(state.get("startedAt", ""))

    archive: dict[str, Any] = {
        "id": match_id,
        "startedAt": state.get("startedAt", ""),
        "state": state,
    }

    if video_path is not None:
        if not video_path.exists():
            raise FileNotFoundError(f"Video not found: {video_path}")
        dest_name = f"{match_id}{video_path.suffix}"
        WEB_VIDEOS_DIR.mkdir(parents=True, exist_ok=True)
        shutil.copy2(video_path, WEB_VIDEOS_DIR / dest_name)
        archive["videoUrl"] = f"/videos/{dest_name}"
        print(f"  → video: {archive['videoUrl']}", file=sys.stderr)

    MATCH_HISTORY_DIR.mkdir(parents=True, exist_ok=True)
    out = MATCH_HISTORY_DIR / f"{match_id}.json"
    out.write_text(json.dumps(archive, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"  → {out.relative_to(REPO_ROOT)}", file=sys.stderr)

    return match_id


def main() -> None:
    ap = argparse.ArgumentParser(
        description="Import an annotated match into match_history/"
    )
    ap.add_argument("state_file", help="Path to a match_state JSON produced by agent.py")
    ap.add_argument("--id", help="Custom match ID (derived from startedAt if omitted)")
    ap.add_argument("--video", help="Video file to copy into app/web/videos/")
    args = ap.parse_args()

    state = json.loads(Path(args.state_file).read_text(encoding="utf-8"))
    match_id = import_match(
        state,
        match_id=args.id,
        video_path=Path(args.video) if args.video else None,
    )
    print(f"Imported match {match_id}", file=sys.stderr)


if __name__ == "__main__":
    main()
