"""Rally detection and video splitting for volleyball matches.

Can work in two modes:
1. From existing tracking JSON (fast, if video was already analyzed)
2. From raw video using RF-DETR detection (no prior tracking needed)
"""

import json
import math
import shutil
import subprocess
from copy import deepcopy
from pathlib import Path

import cv2
import numpy as np

from app.core.config import settings
from app.models.schemas import Rally, RallyDetectionConfig, RallyDetectionResult
from app.services.correction_service import apply_corrections_to_tracking
from app.services.video_service import is_cancelled


def detect_rallies(
    video_id: str,
    config: RallyDetectionConfig | None = None,
    on_progress: callable = None,
) -> RallyDetectionResult:
    """Detect rallies — uses tracking JSON if available, otherwise runs RF-DETR."""
    if config is None:
        config = RallyDetectionConfig()

    tracking_path = settings.RESULTS_DIR / f"{video_id}_tracking.json"

    if tracking_path.exists():
        tracking = _load_tracking(video_id)
    else:
        tracking = _detect_from_video(video_id, config, on_progress)

    fps = tracking["fps"]
    frames = tracking["frames"]
    total_frames = len(frames)

    if total_frames == 0:
        result = RallyDetectionResult(video_id=video_id, config=config, rallies=[])
        _save_result(video_id, result)
        return result

    # Step 1: Motion signal
    motion = _compute_motion(frames, config.min_confidence)

    # Step 2: Smooth
    window = max(3, round(fps * config.smoothing_window_seconds))
    if window % 2 == 0:
        window += 1
    smoothed = np.convolve(motion, np.ones(window) / window, mode="same")

    # Step 3: Adaptive threshold
    threshold = _compute_threshold(smoothed, config.threshold_factor)
    if threshold <= 0:
        result = RallyDetectionResult(video_id=video_id, config=config, rallies=[])
        _save_result(video_id, result)
        return result

    is_active = smoothed > threshold

    # Step 4-7: Extract, merge, filter, pad
    segments = _extract_segments(is_active)
    merge_gap = round(fps * config.merge_gap_seconds)
    segments = _merge_segments(segments, merge_gap)
    min_frames = round(fps * config.min_rally_duration_seconds)
    segments = [(s, e) for s, e in segments if (e - s) >= min_frames]
    pad_frames = round(fps * config.padding_seconds)
    padded = _add_padding(segments, pad_frames, total_frames)

    rallies = []
    for i, ((s, e), (ps, pe)) in enumerate(zip(segments, padded, strict=True)):
        rallies.append(
            Rally(
                rally_id=i + 1,
                start_frame=s,
                end_frame=e,
                start_time=round(s / fps, 2),
                end_time=round(e / fps, 2),
                duration=round((e - s) / fps, 2),
                padded_start_time=round(ps / fps, 2),
                padded_end_time=round(pe / fps, 2),
            )
        )

    result = RallyDetectionResult(video_id=video_id, config=config, rallies=rallies)
    _save_result(video_id, result)
    return result


def split_video(
    video_id: str,
    on_progress: callable = None,
    on_clip_ready: callable = None,
) -> list[Path]:
    """Split source video into rally clips using ffmpeg."""
    if not shutil.which("ffmpeg"):
        raise RuntimeError("ffmpeg not found on system")

    result = load_result(video_id)
    if not result:
        raise ValueError(f"No rally detection result for {video_id}")

    source = settings.UPLOAD_DIR / f"{video_id}.mp4"
    if not source.exists():
        raise FileNotFoundError(f"Source video not found: {source}")

    total = len(result.rallies)
    clips = []
    for i, rally in enumerate(result.rallies):
        if is_cancelled(video_id):
            raise InterruptedError("Cancelled")

        if on_progress:
            on_progress("splitting", i, total)

        out = get_clip_path(video_id, rally.rally_id)
        cmd = [
            "ffmpeg",
            "-y",
            "-ss",
            str(rally.padded_start_time),
            "-to",
            str(rally.padded_end_time),
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
        ]
        subprocess.run(cmd, capture_output=True, check=True)
        clips.append(out)

        if on_clip_ready:
            on_clip_ready(out, rally)

    if on_progress:
        on_progress("splitting", total, total)

    return clips


# --- Helpers ---


def load_result(video_id: str) -> RallyDetectionResult | None:
    path = _result_path(video_id)
    if not path.exists():
        return None
    return RallyDetectionResult(**json.loads(path.read_text()))


def get_clip_path(video_id: str, rally_id: int) -> Path:
    return settings.RESULTS_DIR / f"{video_id}_rally_{rally_id}.mp4"


def _result_path(video_id: str) -> Path:
    return settings.RESULTS_DIR / f"{video_id}_rallies.json"


def _save_result(video_id: str, result: RallyDetectionResult):
    path = _result_path(video_id)
    path.write_text(json.dumps(result.model_dump(), indent=2))


def _load_tracking(video_id: str) -> dict:
    path = settings.RESULTS_DIR / f"{video_id}_tracking.json"
    raw = json.loads(path.read_text())
    return apply_corrections_to_tracking(deepcopy(raw), video_id)


def _detect_from_video(
    video_id: str,
    config: RallyDetectionConfig,
    on_progress: callable = None,
) -> dict:
    """Run RF-DETR on sampled frames to build a lightweight motion dataset.

    We don't need full SAM 2 tracking — just bounding boxes every N frames
    to compute the motion signal. Much faster than the full pipeline.
    """
    from app.vision.detector import PlayerDetector

    source = settings.UPLOAD_DIR / f"{video_id}.mp4"
    if not source.exists():
        raise FileNotFoundError(f"Source video not found: {source}")

    cap = cv2.VideoCapture(str(source))
    fps = cap.get(cv2.CAP_PROP_FPS)
    total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

    # Sample every 0.5s for speed — enough for motion analysis
    sample_interval = max(1, round(fps * 0.5))

    detector = PlayerDetector()
    frames_data = []
    frame_idx = 0

    while cap.isOpened():
        if is_cancelled(video_id):
            cap.release()
            raise InterruptedError("Cancelled")

        ret, frame = cap.read()
        if not ret:
            break

        if frame_idx % sample_interval == 0:
            detections = detector.detect(frame)
            dets = []
            for i in range(len(detections)):
                dets.append(
                    {
                        "tracker_id": i + 1,
                        "bbox": detections.xyxy[i].tolist(),
                        "confidence": float(detections.confidence[i]),
                    }
                )
            frames_data.append(
                {
                    "frame_number": frame_idx,
                    "timestamp": frame_idx / fps,
                    "detections": dets,
                }
            )

            if on_progress:
                on_progress(frame_idx, total)

        frame_idx += 1

    cap.release()
    return {"fps": fps, "total_frames": total, "frames": frames_data}


def _compute_motion(frames: list[dict], min_confidence: float) -> np.ndarray:
    n = len(frames)
    motion = np.zeros(n)
    prev_feet: dict[int, tuple[float, float]] = {}

    for i, frame in enumerate(frames):
        curr_feet: dict[int, tuple[float, float]] = {}
        for det in frame.get("detections", []):
            if det["confidence"] < min_confidence:
                continue
            x1, y1, x2, y2 = det["bbox"]
            curr_feet[det["tracker_id"]] = ((x1 + x2) / 2, y2)

        if prev_feet and curr_feet:
            # Match by closest distance (no persistent IDs in raw detection mode)
            displacements = _match_feet(prev_feet, curr_feet)
            if displacements:
                motion[i] = sum(displacements) / len(displacements)

        prev_feet = curr_feet

    return motion


def _match_feet(
    prev: dict[int, tuple[float, float]],
    curr: dict[int, tuple[float, float]],
) -> list[float]:
    """Match detections between frames by nearest distance.

    Works for both tracked data (same IDs) and raw detections (arbitrary IDs).
    """
    # First try direct ID match (works when IDs are persistent from tracking)
    direct = []
    for tid, pos in curr.items():
        if tid in prev:
            dx = pos[0] - prev[tid][0]
            dy = pos[1] - prev[tid][1]
            direct.append(math.sqrt(dx * dx + dy * dy))
    if direct:
        return direct

    # Fallback: nearest-neighbor matching (for raw detections without persistent IDs)
    prev_pts = list(prev.values())
    curr_pts = list(curr.values())
    displacements = []
    used = set()
    for cp in curr_pts:
        best_dist = float("inf")
        best_idx = -1
        for j, pp in enumerate(prev_pts):
            if j in used:
                continue
            d = math.sqrt((cp[0] - pp[0]) ** 2 + (cp[1] - pp[1]) ** 2)
            if d < best_dist:
                best_dist = d
                best_idx = j
        if best_idx >= 0:
            used.add(best_idx)
            displacements.append(best_dist)
    return displacements


def _compute_threshold(smoothed: np.ndarray, factor: float) -> float:
    nonzero = smoothed[smoothed > 0]
    if len(nonzero) == 0:
        return 0.0
    return float(np.median(nonzero) * factor)


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
        prev_s, prev_e = merged[-1]
        if s - prev_e < gap:
            merged[-1] = (prev_s, e)
        else:
            merged.append((s, e))
    return merged


def _add_padding(segments: list[tuple[int, int]], pad: int, total: int) -> list[tuple[int, int]]:
    padded = []
    for s, e in segments:
        padded.append((max(0, s - pad), min(total, e + pad)))

    for i in range(len(padded) - 1):
        if padded[i][1] > padded[i + 1][0]:
            mid = (segments[i][1] + segments[i + 1][0]) // 2
            padded[i] = (padded[i][0], mid)
            padded[i + 1] = (mid, padded[i + 1][1])

    return padded
