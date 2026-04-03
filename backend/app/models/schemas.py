from enum import StrEnum

from pydantic import BaseModel


class PipelineStatus(StrEnum):
    PENDING = "pending"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"


class Detection(BaseModel):
    tracker_id: int
    bbox: list[float]
    confidence: float
    class_name: str = "player"


class TrackingFrame(BaseModel):
    frame_number: int
    timestamp: float
    detections: list[Detection]


class TrackingResult(BaseModel):
    video_id: str
    fps: float
    total_frames: int
    frames: list[TrackingFrame]


class VideoInfo(BaseModel):
    video_id: str
    original_name: str
    status: PipelineStatus = PipelineStatus.PENDING
    progress: dict | None = None
    parent_id: str | None = None  # set for rally clips


class VideoUploadResponse(BaseModel):
    video_id: str
    filename: str
    status: PipelineStatus


class VideoListResponse(BaseModel):
    videos: list[VideoInfo]


# --- Manual corrections (keyframe editing) ---


class CorrectionEntry(BaseModel):
    """A single correction on one frame."""

    frame_number: int
    # Remap tracker IDs: old_id -> new_id
    id_swaps: dict[int, int] = {}
    # Tracker IDs to remove (false positives)
    removed_ids: list[int] = []


class CorrectionSet(BaseModel):
    """All manual corrections for a video. Only corrected frames are stored."""

    video_id: str
    corrections: list[CorrectionEntry] = []


# --- Rally detection ---


class RallyDetectionConfig(BaseModel):
    smoothing_window_seconds: float = 0.75
    threshold_factor: float = 0.5
    merge_gap_seconds: float = 2.0
    min_rally_duration_seconds: float = 3.0
    padding_seconds: float = 2.0
    min_confidence: float = 0.3


class Rally(BaseModel):
    rally_id: int
    start_frame: int
    end_frame: int
    start_time: float
    end_time: float
    duration: float
    padded_start_time: float
    padded_end_time: float


class RallyDetectionResult(BaseModel):
    video_id: str
    config: RallyDetectionConfig
    rallies: list[Rally]
