"""Local video handling: fetch a source video, cut rally clips out of it.

Requires ``yt-dlp`` and ``ffmpeg`` on PATH (``brew install yt-dlp ffmpeg``).
"""
from __future__ import annotations

import subprocess
from pathlib import Path

from rich.console import Console

PKG_DIR = Path(__file__).parent
DOWNLOADS_DIR = PKG_DIR / "downloads"
CLIPS_DIR = DOWNLOADS_DIR / "clips"

_console = Console(stderr=True)

#: Cap resolution at 720p — Gemini gains nothing from a larger frame here, and
#: the download and the per-clip upload both get proportionally cheaper.
_YT_FORMAT = (
    "bestvideo[ext=mp4][height<=720]+bestaudio[ext=m4a]/"
    "best[ext=mp4][height<=720]/best[ext=mp4]/best"
)


def is_remote(video_uri: str) -> bool:
    """True when [video_uri] must be downloaded before clips can be cut."""
    return "youtube.com" in video_uri or "youtu.be" in video_uri


def resolve(video_uri: str) -> Path:
    """Return a local mp4 for [video_uri], downloading it if it is a YouTube URL.

    Raises FileNotFoundError when a local path is given but does not exist.
    """
    if not is_remote(video_uri):
        path = Path(video_uri)
        if not path.exists():
            raise FileNotFoundError(f"Local video not found: {path}")
        return path
    return download(video_uri)


def download(video_url: str) -> Path:
    """Download a YouTube video, caching by video ID. Returns the local mp4 path."""
    probe = subprocess.run(
        ["yt-dlp", "--print", "id", video_url],
        capture_output=True, text=True, check=True,
    )
    video_id = probe.stdout.strip()

    DOWNLOADS_DIR.mkdir(exist_ok=True)
    out = DOWNLOADS_DIR / f"{video_id}.mp4"
    if out.exists():
        _console.print(f"  Cached → {out.name}", style="dim")
        return out

    _console.print(f"  Downloading {video_id}…", style="dim")
    subprocess.run(
        [
            "yt-dlp",
            "-o", str(out),
            "--format", _YT_FORMAT,
            "--merge-output-format", "mp4",
            video_url,
        ],
        check=True,
    )
    return out


def cut_clip(video_path: Path, start_s: float, end_s: float, clip_path: Path) -> None:
    """Extract [start_s, end_s] from [video_path] into [clip_path].

    Uses stream copy (no re-encode), so this is near-instant regardless of
    clip length — at the cost of snapping to the nearest keyframe.
    """
    clip_path.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            "ffmpeg", "-y",
            "-ss", str(start_s),
            "-i", str(video_path),
            "-t", str(end_s - start_s),
            "-c", "copy",
            "-avoid_negative_ts", "make_zero",
            str(clip_path),
        ],
        check=True,
        capture_output=True,
    )
