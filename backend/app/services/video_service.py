import json
import uuid
from pathlib import Path

import cv2

from app.core.config import settings
from app.models.schemas import PipelineStatus, VideoInfo

# In-memory store: video_id -> VideoInfo
_videos: dict[str, VideoInfo] = {}

# Cancellation flags: video_id -> True means cancel requested
_cancel_flags: dict[str, bool] = {}

# Background jobs: job_id -> {video_id, type, progress, status}
_jobs: dict[str, dict] = {}


def request_cancel(video_id: str):
    _cancel_flags[video_id] = True


def is_cancelled(video_id: str) -> bool:
    return _cancel_flags.get(video_id, False)


def clear_cancel(video_id: str):
    _cancel_flags.pop(video_id, None)


# --- Job tracking ---


def create_job(video_id: str, job_type: str) -> str:
    job_id = f"{video_id}_{job_type}"
    _jobs[job_id] = {
        "job_id": job_id,
        "video_id": video_id,
        "type": job_type,
        "status": "running",
        "progress": None,
    }
    return job_id


def update_job(job_id: str, progress: dict):
    if job_id in _jobs:
        _jobs[job_id]["progress"] = progress


def finish_job(job_id: str, status: str = "done"):
    if job_id in _jobs:
        _jobs[job_id]["status"] = status
        _jobs[job_id]["progress"] = None


def get_job(job_id: str) -> dict | None:
    return _jobs.get(job_id)


def get_jobs_for_video(video_id: str) -> list[dict]:
    return [j for j in _jobs.values() if j["video_id"] == video_id and j["status"] == "running"]


def list_jobs() -> list[dict]:
    return [j for j in _jobs.values() if j["status"] == "running"]


def generate_video_id() -> str:
    return str(uuid.uuid4())[:8]


def get_upload_path(video_id: str) -> Path:
    return settings.UPLOAD_DIR / f"{video_id}.mp4"


def _meta_path(video_id: str) -> Path:
    return settings.UPLOAD_DIR / f"{video_id}.meta"


def _save_meta(video_id: str, original_name: str, parent_id: str | None = None):
    data = {"name": original_name}
    if parent_id:
        data["parent_id"] = parent_id
    _meta_path(video_id).write_text(json.dumps(data))


def _load_meta(video_id: str) -> dict:
    """Returns {"name": str, "parent_id": str|None}."""
    p = _meta_path(video_id)
    if p.exists():
        text = p.read_text().strip()
        # Support both old plain-text format and new JSON format
        if text.startswith("{"):
            data = json.loads(text)
            return {"name": data.get("name", f"{video_id}.mp4"), "parent_id": data.get("parent_id")}
        return {"name": text, "parent_id": None}
    return {"name": f"{video_id}.mp4", "parent_id": None}


def get_result_video_path(video_id: str) -> Path:
    return settings.RESULTS_DIR / f"{video_id}_annotated.mp4"


def get_result_data_path(video_id: str) -> Path:
    return settings.RESULTS_DIR / f"{video_id}_tracking.json"


def scan_existing():
    """Scan uploads and results on startup to restore all known videos."""
    # 1. Annotated videos (have tracking JSON)
    for tracking_file in settings.RESULTS_DIR.glob("*_tracking.json"):
        video_id = tracking_file.stem.replace("_tracking", "")
        if video_id in _videos:
            continue
        source_path = get_upload_path(video_id)
        if not source_path.exists():
            continue
        try:
            data = json.loads(tracking_file.read_text())
            original_name = data.get("original_name", f"{video_id}.mp4")
        except Exception:
            original_name = f"{video_id}.mp4"
        _videos[video_id] = VideoInfo(
            video_id=video_id,
            original_name=original_name,
            status=PipelineStatus.COMPLETED,
        )

    # 2. Uploaded but not yet annotated (mp4 in uploads with no tracking JSON)
    for upload_file in settings.UPLOAD_DIR.glob("*.mp4"):
        video_id = upload_file.stem
        if video_id in _videos:
            continue
        meta = _load_meta(video_id)
        _videos[video_id] = VideoInfo(
            video_id=video_id,
            original_name=meta["name"],
            status=PipelineStatus.PENDING,
            parent_id=meta["parent_id"],
        )


async def save_upload(file, original_name: str) -> VideoInfo:
    video_id = generate_video_id()
    upload_path = get_upload_path(video_id)

    content = await file.read()
    upload_path.write_bytes(content)
    _save_meta(video_id, original_name)

    info = VideoInfo(
        video_id=video_id,
        original_name=original_name,
        status=PipelineStatus.PENDING,
    )
    _videos[video_id] = info
    return info


def download_youtube(url: str) -> VideoInfo:
    """Download a YouTube video via yt-dlp and register it."""
    import yt_dlp

    video_id = generate_video_id()
    upload_path = get_upload_path(video_id)

    ydl_opts = {
        "format": "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best",
        "outtmpl": str(upload_path),
        "merge_output_format": "mp4",
        "quiet": True,
        "no_warnings": True,
        "cookiesfrombrowser": ("safari",),
        "remote_components": {"ejs": "github"},
    }

    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        meta = ydl.extract_info(url, download=True)
        title = meta.get("title", "youtube_video") if meta else "youtube_video"

    original_name = f"{title}.mp4"
    _save_meta(video_id, original_name)
    info = VideoInfo(
        video_id=video_id,
        original_name=original_name,
        status=PipelineStatus.PENDING,
    )
    _videos[video_id] = info
    return info


def list_videos() -> list[VideoInfo]:
    return list(_videos.values())


def get_video(video_id: str) -> VideoInfo | None:
    return _videos.get(video_id)


def update_status(video_id: str, status: PipelineStatus, progress: dict | None = None):
    if video_id in _videos:
        _videos[video_id].status = status
        _videos[video_id].progress = progress


def _cleanup_derived_files(video_id: str) -> None:
    """Remove point detection results and all derived clips."""
    for pattern in [f"{video_id}_points.json", f"{video_id}_rallies.json"]:
        (settings.RESULTS_DIR / pattern).unlink(missing_ok=True)
    for clip in settings.RESULTS_DIR.glob(f"{video_id}_point_*.mp4"):
        clip.unlink(missing_ok=True)
    for clip in settings.RESULTS_DIR.glob(f"{video_id}_rally_*.mp4"):
        clip.unlink(missing_ok=True)


def clear_annotations(video_id: str) -> None:
    """Remove tracking data, corrections, and rallies but keep the source video."""
    result_video = get_result_video_path(video_id)
    result_data = get_result_data_path(video_id)
    corrections = settings.RESULTS_DIR / f"{video_id}_corrections.json"
    for p in [result_video, result_data, corrections]:
        p.unlink(missing_ok=True)
    _cleanup_derived_files(video_id)
    if video_id in _videos:
        _videos[video_id].status = PipelineStatus.PENDING
        _videos[video_id].progress = None


def delete_video(video_id: str) -> bool:
    if video_id not in _videos:
        return False
    _cleanup_derived_files(video_id)
    upload_path = get_upload_path(video_id)
    result_video = get_result_video_path(video_id)
    result_data = get_result_data_path(video_id)
    corrections = settings.RESULTS_DIR / f"{video_id}_corrections.json"
    for p in [upload_path, result_video, result_data, corrections, _meta_path(video_id)]:
        p.unlink(missing_ok=True)
    del _videos[video_id]
    return True


def get_video_metadata(video_id: str) -> dict | None:
    path = get_upload_path(video_id)
    if not path.exists():
        return None
    cap = cv2.VideoCapture(str(path))
    try:
        return {
            "fps": cap.get(cv2.CAP_PROP_FPS),
            "frame_count": int(cap.get(cv2.CAP_PROP_FRAME_COUNT)),
            "width": int(cap.get(cv2.CAP_PROP_FRAME_WIDTH)),
            "height": int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT)),
        }
    finally:
        cap.release()
