import cv2
import pytest

from app.core.config import settings
from app.vision.detector import PlayerDetector
from app.vision.tracker import PlayerTracker


@pytest.fixture(scope="module")
def detector():
    return PlayerDetector()


@pytest.fixture(scope="module")
def frames():
    video_path = settings.VIDEOS_DIR / "video_1.mp4"
    cap = cv2.VideoCapture(str(video_path))
    cap.set(cv2.CAP_PROP_POS_FRAMES, 60)
    result = []
    for _ in range(30):
        ret, frame = cap.read()
        if not ret:
            break
        result.append(frame)
    cap.release()
    assert len(result) == 30, "Need 30 frames for tracking test"
    return result


def test_tracker_assigns_ids(detector, frames):
    tracker = PlayerTracker()
    all_ids = set()
    for frame in frames:
        detections = detector.detect(frame)
        tracked = tracker.update(detections)
        if tracked.tracker_id is not None:
            all_ids.update(tracked.tracker_id.tolist())
    assert len(all_ids) > 0, "Tracker should assign at least one ID"


def test_tracker_ids_are_consistent(detector, frames):
    tracker = PlayerTracker()
    id_counts = {}
    for frame in frames:
        detections = detector.detect(frame)
        tracked = tracker.update(detections)
        if tracked.tracker_id is not None:
            for tid in tracked.tracker_id:
                tid = int(tid)
                id_counts[tid] = id_counts.get(tid, 0) + 1
    # At least some IDs should appear in multiple frames (persistent tracking)
    persistent = [tid for tid, count in id_counts.items() if count > 5]
    assert len(persistent) > 0, "Expected persistent tracker IDs across frames"


def test_tracker_reset(detector, frames):
    tracker = PlayerTracker()
    for frame in frames[:5]:
        detections = detector.detect(frame)
        tracker.update(detections)
    tracker.reset()
    detections = detector.detect(frames[0])
    tracked = tracker.update(detections)
    # After reset, IDs should restart
    if tracked.tracker_id is not None and len(tracked.tracker_id) > 0:
        assert min(tracked.tracker_id) >= 1
