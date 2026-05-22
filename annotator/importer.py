"""
Import a match_state.json produced by agent.py into Firestore + local web assets.

Writes to Firestore collection users/{uid}/matches (project meehawk-87417).
Copies video file to app/web/videos/ and app/build/web/videos/ for local serving.

Usage:
    uv run --project annotator python -m annotator.importer annotator/match_state.json --uid <firebase-uid>
    uv run --project annotator python -m annotator.importer annotator/match_state.json --uid <uid> --id my_custom_id
    uv run --project annotator python -m annotator.importer annotator/match_state.json --uid <uid> --video /path/to/video.mp4
"""
from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

import firebase_admin
from firebase_admin import credentials, firestore as admin_firestore

REPO_ROOT = Path(__file__).parent.parent
WEB_VIDEOS = REPO_ROOT / "app" / "web" / "videos"
BUILD_VIDEOS = REPO_ROOT / "app" / "build" / "web" / "videos"

SERVICE_ACCOUNT = Path(__file__).parent / "service-account.json"
COLLECTION = "matches"


def _firestore_client() -> admin_firestore.Client:
    if not firebase_admin._apps:
        cred = credentials.Certificate(str(SERVICE_ACCOUNT))
        firebase_admin.initialize_app(cred)
    return admin_firestore.client()


def import_match(
    state_path: Path,
    uid: str,
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

    doc: dict = {"id": match_id, "startedAt": started_at, "state": state}
    if video_url:
        doc["videoUrl"] = video_url

    db = _firestore_client()
    db.collection("users").document(uid).collection(COLLECTION).document(match_id).set(doc)
    print(f"  → Firestore: users/{uid}/{COLLECTION}/{match_id}", file=sys.stderr)

    return match_id


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Import a match_state.json into Firestore"
    )
    parser.add_argument("state_file", help="Path to match_state.json")
    parser.add_argument("--uid", required=True, help="Firebase user UID to write under")
    parser.add_argument(
        "--id", default=None, help="Custom match ID (auto-generated from startedAt if omitted)"
    )
    parser.add_argument(
        "--video", default=None, help="Local video file to copy into app/web/videos/"
    )
    args = parser.parse_args()

    match_id = import_match(
        Path(args.state_file),
        uid=args.uid,
        match_id=args.id,
        video_path=Path(args.video) if args.video else None,
    )
    print(f"Imported match {match_id}", file=sys.stderr)


if __name__ == "__main__":
    main()
