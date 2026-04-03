import json
from pathlib import Path

from app.core.config import settings
from app.models.schemas import CorrectionSet


def _corrections_path(video_id: str) -> Path:
    return settings.RESULTS_DIR / f"{video_id}_corrections.json"


def load_corrections(video_id: str) -> CorrectionSet:
    path = _corrections_path(video_id)
    if not path.exists():
        return CorrectionSet(video_id=video_id)
    data = json.loads(path.read_text())
    return CorrectionSet(**data)


def save_corrections(corrections: CorrectionSet) -> None:
    path = _corrections_path(corrections.video_id)
    path.write_text(json.dumps(corrections.model_dump(), indent=2))


def apply_corrections_to_tracking(tracking_data: dict, video_id: str) -> dict:
    """Apply manual corrections on top of auto tracking data.

    Corrections propagate forward: a correction on frame N applies to all
    subsequent frames until another correction overrides it.
    """
    cs = load_corrections(video_id)
    if not cs.corrections:
        return tracking_data

    # Build sorted correction keyframes
    keyframes = sorted(cs.corrections, key=lambda c: c.frame_number)

    # Active state that carries forward
    active_swaps: dict[int, int] = {}
    active_removed: set[int] = set()
    next_idx = 0

    for frame in tracking_data.get("frames", []):
        fn = frame["frame_number"]

        # Apply any new correction at this frame
        while next_idx < len(keyframes) and keyframes[next_idx].frame_number <= fn:
            corr = keyframes[next_idx]
            active_swaps.update(corr.id_swaps)
            active_removed = active_removed.union(set(corr.removed_ids))
            next_idx += 1

        # Apply active corrections to this frame's detections
        corrected_dets = []
        for det in frame.get("detections", []):
            tid = det["tracker_id"]
            if tid in active_removed:
                continue
            if tid in active_swaps:
                det = {**det, "tracker_id": active_swaps[tid]}
            corrected_dets.append(det)
        frame["detections"] = corrected_dets

    return tracking_data
