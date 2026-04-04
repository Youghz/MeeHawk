"""Detect points played in a volleyball video using Gemini VLM.

Splits the video into 2-minute chunks, asks Gemini to classify 5-second
windows as playing/not-playing across multiple runs, takes consensus,
then extracts segments and splits with ffmpeg.
"""

import json
import os
import shutil
import subprocess
from pathlib import Path

import numpy as np
from dotenv import load_dotenv
from google import genai
from google.genai import types

from app.core.config import settings
from app.models.schemas import PointDetectionResult, PointSegment
from app.services.video_service import is_cancelled

load_dotenv(settings.PROJECT_ROOT / ".env")

WINDOW_SEC = 5
CHUNK_SEC = 120
N_RUNS = 5
CONSENSUS_THRESHOLD = 3  # out of N_RUNS
MIN_POINT_DURATION = 3.0
MERGE_GAP = 5.0
PADDING = 3.0

PROMPT_TEMPLATE = """Watch this beach volleyball video clip ({duration}s).

For each {window}s window, is a point being actively played? (ball in the air, players hitting it)
Or is it a break? (players walking, standing, preparing, chatting)

{windows}

Answer with ONLY one letter per line: P (playing) or B (break). Nothing else."""


def detect_points(
    video_id: str,
    on_progress: callable = None,
) -> PointDetectionResult:
    source = settings.UPLOAD_DIR / f"{video_id}.mp4"
    if not source.exists():
        raise FileNotFoundError(f"Source video not found: {source}")

    import cv2

    cap = cv2.VideoCapture(str(source))
    fps = cap.get(cv2.CAP_PROP_FPS)
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    duration = total_frames / fps
    cap.release()

    api_key = os.environ.get("GEMINI_API_KEY", "")
    if not api_key:
        raise RuntimeError("GEMINI_API_KEY not set")
    client = genai.Client(api_key=api_key)

    # Process in 2-minute chunks
    all_votes = np.zeros(int(duration) + 1)
    chunk_starts = list(range(0, int(duration), CHUNK_SEC))

    for ci, chunk_start in enumerate(chunk_starts):
        if is_cancelled(video_id):
            raise InterruptedError("Cancelled")

        chunk_end = min(chunk_start + CHUNK_SEC, int(duration))
        chunk_dur = chunk_end - chunk_start

        if on_progress:
            on_progress(ci, len(chunk_starts))

        # Extract chunk
        chunk_path = f"/tmp/meehawk_chunk_{video_id}_{ci}.mp4"
        subprocess.run(
            [
                "ffmpeg",
                "-y",
                "-ss",
                str(chunk_start),
                "-to",
                str(chunk_end),
                "-i",
                str(source),
                "-c:v",
                "libx264",
                "-preset",
                "fast",
                "-crf",
                "23",
                "-an",
                chunk_path,
            ],
            capture_output=True,
            check=True,
        )

        # Upload to Gemini
        video_file = client.files.upload(file=chunk_path)
        import time

        while video_file.state.name == "PROCESSING":
            time.sleep(2)
            video_file = client.files.get(name=video_file.name)

        # Build prompt
        n_windows = chunk_dur // WINDOW_SEC
        windows_str = "\n".join(
            f"{i * WINDOW_SEC}-{(i + 1) * WINDOW_SEC}s: ?" for i in range(n_windows)
        )
        prompt = PROMPT_TEMPLATE.format(duration=chunk_dur, window=WINDOW_SEC, windows=windows_str)

        # Run N times
        for _run in range(N_RUNS):
            if is_cancelled(video_id):
                client.files.delete(name=video_file.name)
                Path(chunk_path).unlink(missing_ok=True)
                raise InterruptedError("Cancelled")

            resp = client.models.generate_content(
                model="gemini-2.0-flash",
                contents=[
                    types.Content(
                        role="user",
                        parts=[
                            types.Part.from_uri(file_uri=video_file.uri, mime_type="video/mp4"),
                            types.Part.from_text(text=prompt),
                        ],
                    )
                ],
            )
            letters = [c for c in resp.text.upper() if c in ("P", "B")]
            for i, letter in enumerate(letters[:n_windows]):
                if letter == "P":
                    t_start = chunk_start + i * WINDOW_SEC
                    t_end = min(t_start + WINDOW_SEC, int(duration))
                    all_votes[t_start:t_end] += 1

        client.files.delete(name=video_file.name)
        Path(chunk_path).unlink(missing_ok=True)

    # Consensus: playing if >= CONSENSUS_THRESHOLD votes
    is_playing = all_votes >= CONSENSUS_THRESHOLD

    # Extract segments
    segments = _extract_segments(is_playing)
    segments = _merge_segments(segments, int(MERGE_GAP))
    segments = [(s, e) for s, e in segments if (e - s) >= MIN_POINT_DURATION]

    # Build result
    points = []
    for i, (s, e) in enumerate(segments):
        ps = max(0, s - PADDING)
        pe = min(duration, e + PADDING)
        # Resolve overlap with previous
        if points and ps < points[-1].padded_end_time:
            mid = (points[-1].end_time + s) / 2
            points[-1] = points[-1].model_copy(update={"padded_end_time": round(mid, 2)})
            ps = round(mid, 2)
        points.append(
            PointSegment(
                point_id=i + 1,
                start_time=round(float(s), 2),
                end_time=round(float(e), 2),
                duration=round(float(e - s), 2),
                padded_start_time=round(ps, 2),
                padded_end_time=round(pe, 2),
            )
        )

    result = PointDetectionResult(video_id=video_id, points=points)
    _save_result(video_id, result)

    if on_progress:
        on_progress(len(chunk_starts), len(chunk_starts))

    return result


def split_video(
    video_id: str,
    on_progress: callable = None,
    on_clip_ready: callable = None,
) -> list[Path]:
    if not shutil.which("ffmpeg"):
        raise RuntimeError("ffmpeg not found")

    result = load_result(video_id)
    if not result:
        raise ValueError(f"No point detection result for {video_id}")

    source = settings.UPLOAD_DIR / f"{video_id}.mp4"
    if not source.exists():
        raise FileNotFoundError(f"Source video not found: {source}")

    total = len(result.points)
    clips = []
    for i, point in enumerate(result.points):
        if is_cancelled(video_id):
            raise InterruptedError("Cancelled")
        if on_progress:
            on_progress("splitting", i, total)

        out = get_clip_path(video_id, point.point_id)
        subprocess.run(
            [
                "ffmpeg",
                "-y",
                "-ss",
                str(point.padded_start_time),
                "-to",
                str(point.padded_end_time),
                "-i",
                str(source),
                "-c:v",
                "libx264",
                "-preset",
                "fast",
                "-crf",
                "23",
                "-an",
                "-avoid_negative_ts",
                "make_zero",
                str(out),
            ],
            capture_output=True,
            check=True,
        )
        clips.append(out)
        if on_clip_ready:
            on_clip_ready(out, point)

    if on_progress:
        on_progress("splitting", total, total)
    return clips


# --- Helpers ---


def load_result(video_id: str) -> PointDetectionResult | None:
    path = _result_path(video_id)
    if not path.exists():
        return None
    return PointDetectionResult(**json.loads(path.read_text()))


def get_clip_path(video_id: str, point_id: int) -> Path:
    return settings.RESULTS_DIR / f"{video_id}_point_{point_id}.mp4"


def _result_path(video_id: str) -> Path:
    return settings.RESULTS_DIR / f"{video_id}_points.json"


def _save_result(video_id: str, result: PointDetectionResult):
    _result_path(video_id).write_text(json.dumps(result.model_dump(), indent=2))


def _extract_segments(is_active: np.ndarray) -> list[tuple[int, int]]:
    segments = []
    start = None
    for i, active in enumerate(is_active):
        if active and start is None:
            start = i
        elif not active and start is not None:
            segments.append((start, i))
            start = None
    if start is not None:
        segments.append((start, len(is_active)))
    return segments


def _merge_segments(segments: list[tuple[int, int]], gap: int) -> list[tuple[int, int]]:
    if not segments:
        return []
    merged = [segments[0]]
    for s, e in segments[1:]:
        if s - merged[-1][1] < gap:
            merged[-1] = (merged[-1][0], e)
        else:
            merged.append((s, e))
    return merged
