from app.models.schemas import Detection, PipelineStatus, TrackingFrame, TrackingResult


def test_detection_model():
    d = Detection(tracker_id=1, bbox=[10.0, 20.0, 100.0, 200.0], confidence=0.95)
    assert d.tracker_id == 1
    assert d.class_name == "player"


def test_tracking_frame_model():
    frame = TrackingFrame(
        frame_number=0,
        timestamp=0.0,
        detections=[
            Detection(tracker_id=1, bbox=[10, 20, 100, 200], confidence=0.9),
            Detection(tracker_id=2, bbox=[150, 30, 250, 210], confidence=0.85),
        ],
    )
    assert len(frame.detections) == 2


def test_tracking_result_model():
    result = TrackingResult(
        video_id="test123",
        fps=30.0,
        total_frames=1,
        frames=[TrackingFrame(frame_number=0, timestamp=0.0, detections=[])],
    )
    data = result.model_dump()
    assert data["video_id"] == "test123"
    assert data["fps"] == 30.0


def test_pipeline_status_values():
    assert PipelineStatus.PENDING == "pending"
    assert PipelineStatus.PROCESSING == "processing"
    assert PipelineStatus.COMPLETED == "completed"
    assert PipelineStatus.FAILED == "failed"
