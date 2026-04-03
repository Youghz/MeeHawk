import cv2
import pytest

from app.core.config import settings
from app.vision.detector import PlayerDetector


@pytest.fixture(scope="module")
def detector():
    return PlayerDetector()


@pytest.fixture(scope="module")
def sample_frame():
    video_path = settings.VIDEOS_DIR / "video_1.mp4"
    cap = cv2.VideoCapture(str(video_path))
    # Skip to frame 60 (2 seconds in) to get an active frame
    cap.set(cv2.CAP_PROP_POS_FRAMES, 60)
    ret, frame = cap.read()
    cap.release()
    assert ret, "Failed to read frame from test video"
    return frame


def test_detect_returns_detections(detector, sample_frame):
    detections = detector.detect(sample_frame)
    assert detections is not None
    assert len(detections) > 0, "Expected at least one player detected"


def test_detect_has_person_class(detector, sample_frame):
    detections = detector.detect(sample_frame)
    if len(detections) > 0:
        # All detections should be person class (class_id 1 in rfdetr/COCO)
        assert all(cid == 1 for cid in detections.class_id)


def test_detect_has_confidence(detector, sample_frame):
    detections = detector.detect(sample_frame)
    if len(detections) > 0:
        assert all(c > 0.0 for c in detections.confidence)
        assert all(c <= 1.0 for c in detections.confidence)


def test_detect_has_valid_bboxes(detector, sample_frame):
    detections = detector.detect(sample_frame)
    h, w = sample_frame.shape[:2]
    for bbox in detections.xyxy:
        x1, y1, x2, y2 = bbox
        assert x2 > x1, "bbox width must be positive"
        assert y2 > y1, "bbox height must be positive"
