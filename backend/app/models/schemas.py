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
    parent_id: str | None = None


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
    id_swaps: dict[int, int] = {}
    removed_ids: list[int] = []


class CorrectionSet(BaseModel):
    """All manual corrections for a video. Only corrected frames are stored."""

    video_id: str
    corrections: list[CorrectionEntry] = []


# --- Point detection ---


class PointSegment(BaseModel):
    point_id: int
    start_time: float
    end_time: float
    duration: float
    padded_start_time: float
    padded_end_time: float


class PointDetectionResult(BaseModel):
    video_id: str
    points: list[PointSegment]
