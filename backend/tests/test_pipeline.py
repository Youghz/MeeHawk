import json

import pytest

from app.core.config import settings
from app.vision.pipeline import VideoPipeline


@pytest.fixture(scope="module")
def pipeline():
    return VideoPipeline()


@pytest.fixture(scope="module")
def pipeline_result(pipeline):
    video_path = str(settings.VIDEOS_DIR / "video_1.mp4")
    return pipeline.process(
        input_path=video_path,
        video_id="test-pipeline",
        max_frames=30,
    )


def test_pipeline_produces_tracking_result(pipeline_result):
    assert pipeline_result.video_id == "test-pipeline"
    assert pipeline_result.fps > 0
    assert pipeline_result.total_frames == 30
    assert len(pipeline_result.frames) == 30


def test_pipeline_creates_annotated_video(pipeline_result):
    path = settings.RESULTS_DIR / "test-pipeline_annotated.mp4"
    assert path.exists(), "Annotated video should be created"
    assert path.stat().st_size > 0, "Annotated video should not be empty"


def test_pipeline_creates_tracking_json(pipeline_result):
    path = settings.RESULTS_DIR / "test-pipeline_tracking.json"
    assert path.exists(), "Tracking JSON should be created"
    data = json.loads(path.read_text())
    assert data["video_id"] == "test-pipeline"
    assert len(data["frames"]) == 30


def test_pipeline_detections_have_tracker_ids(pipeline_result):
    has_detections = False
    for frame in pipeline_result.frames:
        if frame.detections:
            has_detections = True
            for det in frame.detections:
                assert det.tracker_id > 0
                assert len(det.bbox) == 4
                assert 0 < det.confidence <= 1.0
    assert has_detections, "Expected detections in at least some frames"


def test_pipeline_tracker_ids_consistent(pipeline_result):
    id_frames = {}
    for frame in pipeline_result.frames:
        for det in frame.detections:
            if det.tracker_id not in id_frames:
                id_frames[det.tracker_id] = []
            id_frames[det.tracker_id].append(frame.frame_number)
    persistent = {tid: frames for tid, frames in id_frames.items() if len(frames) > 5}
    assert len(persistent) > 0, "Expected persistent tracker IDs across frames"
