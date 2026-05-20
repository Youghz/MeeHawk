"""
Import a match_state.json produced by agent.py into the Flutter web app.

Writes app/web/matches/archives.json  → survives flutter build web rebuilds.
Writes app/build/web/matches/archives.json → immediately visible on the running server.

Usage:
    uv run python mcp/import_to_app.py mcp/match_state.json
    uv run python mcp/import_to_app.py mcp/match_state.json --id my_custom_id
"""
from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent
WEB_MATCHES = REPO_ROOT / "app" / "web" / "matches"
BUILD_MATCHES = REPO_ROOT / "app" / "build" / "web" / "matches"
WEB_VIDEOS = REPO_ROOT / "app" / "web" / "videos"
BUILD_VIDEOS = REPO_ROOT / "app" / "build" / "web" / "videos"
ARCHIVES_FILE = "archives.json"


def load_archives(path: Path) -> list[dict]:
    if path.exists():
        try:
            return json.loads(path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            pass
    return []


def upsert(archives: list[dict], new_entry: dict) -> list[dict]:
    idx = next((i for i, a in enumerate(archives) if a["id"] == new_entry["id"]), -1)
    if idx >= 0:
        archives[idx] = new_entry
    else:
        archives.insert(0, new_entry)
    return archives


def write_archives(path: Path, archives: list[dict]) -> None:
    path.mkdir(parents=True, exist_ok=True)
    (path / ARCHIVES_FILE).write_text(
        json.dumps(archives, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )


def import_match(
    state_path: Path,
    match_id: str | None = None,
    video_path: Path | None = None,
) -> str:
    state = json.loads(state_path.read_text(encoding="utf-8"))
    started_at = state.get("startedAt", "")
    if not match_id:
        ts = started_at.replace(":", "").replace("-", "").replace(".", "").replace("Z", "")
        match_id = f"match_{ts}"

    video_url = None
    if video_path is not None and video_path.exists():
        dest_name = f"{match_id}{video_path.suffix}"
        for dest_dir in (WEB_VIDEOS, BUILD_VIDEOS):
            dest_dir.mkdir(parents=True, exist_ok=True)
            shutil.copy2(video_path, dest_dir / dest_name)
        video_url = f"/videos/{dest_name}"
        print(f"  → video: {video_url}", file=sys.stderr)

    entry: dict = {"id": match_id, "startedAt": started_at, "state": state}
    if video_url:
        entry["videoUrl"] = video_url

    for dest in (WEB_MATCHES, BUILD_MATCHES):
        archives = load_archives(dest / ARCHIVES_FILE)
        archives = upsert(archives, entry)
        write_archives(dest, archives)
        print(f"  → {dest / ARCHIVES_FILE} ({len(archives)} match(es))", file=sys.stderr)

    return match_id


def main() -> None:
    parser = argparse.ArgumentParser(description="Import a match_state.json into the Flutter web app")
    parser.add_argument("state_file", help="Path to match_state.json")
    parser.add_argument("--id", default=None, help="Custom match ID (auto-generated from startedAt if omitted)")
    parser.add_argument("--video", default=None, help="Local video file to copy into app/web/videos/")
    args = parser.parse_args()

    match_id = import_match(Path(args.state_file), args.id, Path(args.video) if args.video else None)
    print(f"Imported match {match_id}", file=sys.stderr)


if __name__ == "__main__":
    main()
