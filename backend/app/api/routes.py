import json
from copy import deepcopy
from pathlib import Path

from fastapi import APIRouter, BackgroundTasks, HTTPException, UploadFile
from fastapi.responses import FileResponse
from pydantic import BaseModel

from app.core.config import settings
from app.models.schemas import (
    CorrectionEntry,
    CorrectionSet,
    PipelineStatus,
    RallyDetectionConfig,
    VideoListResponse,
    VideoUploadResponse,
)
from app.services import rally_service, video_service
from app.services.correction_service import (
    apply_corrections_to_tracking,
    load_corrections,
    save_corrections,
)

router = APIRouter(prefix="/api/videos", tags=["videos"])


@router.post("/upload", response_model=VideoUploadResponse)
async def upload_video(file: UploadFile):
    ext = Path(file.filename).suffix.lower()
    if ext not in settings.ALLOWED_EXTENSIONS:
        raise HTTPException(
            400, f"Extension '{ext}' not allowed. Use: {settings.ALLOWED_EXTENSIONS}"
        )

    info = await video_service.save_upload(file, file.filename)
    return VideoUploadResponse(
        video_id=info.video_id,
        filename=info.original_name,
        status=info.status,
    )


class YoutubeRequest(BaseModel):
    url: str


@router.post("/upload/youtube", response_model=VideoUploadResponse)
async def upload_from_youtube(body: YoutubeRequest):
    try:
        info = video_service.download_youtube(body.url)
    except Exception as e:
        raise HTTPException(400, f"YouTube download failed: {e}") from e
    return VideoUploadResponse(
        video_id=info.video_id,
        filename=info.original_name,
        status=info.status,
    )


@router.get("", response_model=VideoListResponse)
async def list_videos():
    return VideoListResponse(videos=video_service.list_videos())


@router.get("/jobs/active")
async def list_active_jobs():
    return {"jobs": video_service.list_jobs()}


@router.get("/{video_id}")
async def get_video(video_id: str):
    info = video_service.get_video(video_id)
    if not info:
        raise HTTPException(404, "Video not found")
    metadata = video_service.get_video_metadata(video_id)
    return {**info.model_dump(), "metadata": metadata}


@router.delete("/{video_id}")
async def delete_video(video_id: str):
    if not video_service.delete_video(video_id):
        raise HTTPException(404, "Video not found")
    return {"deleted": True}


@router.delete("/{video_id}/annotations")
async def delete_annotations(video_id: str):
    info = video_service.get_video(video_id)
    if not info:
        raise HTTPException(404, "Video not found")
    video_service.clear_annotations(video_id)
    return {"cleared": True}


@router.post("/{video_id}/cancel")
async def cancel_processing(video_id: str):
    info = video_service.get_video(video_id)
    if not info:
        raise HTTPException(404, "Video not found")
    video_service.request_cancel(video_id)
    return {"video_id": video_id, "cancelled": True}


@router.post("/{video_id}/analyze")
async def analyze_video(video_id: str, background_tasks: BackgroundTasks):
    info = video_service.get_video(video_id)
    if not info:
        raise HTTPException(404, "Video not found")
    if info.status == PipelineStatus.PROCESSING:
        raise HTTPException(409, "Analysis already in progress")

    from app.services.pipeline_service import PipelineService

    input_path = video_service.get_upload_path(video_id)
    PipelineService.start_analysis(video_id, str(input_path), background_tasks)
    return {"video_id": video_id, "status": "processing"}


@router.get("/{video_id}/source")
async def get_source_video(video_id: str):
    path = video_service.get_upload_path(video_id)
    if not path.exists():
        raise HTTPException(404, "Source video not found")
    return FileResponse(str(path), media_type="video/mp4", filename=f"{video_id}.mp4")


@router.get("/{video_id}/result/video")
async def get_result_video(video_id: str):
    path = video_service.get_result_video_path(video_id)
    if not path.exists():
        raise HTTPException(404, "Annotated video not ready")
    return FileResponse(str(path), media_type="video/mp4", filename=f"{video_id}_annotated.mp4")


@router.get("/{video_id}/result/data")
async def get_result_data(video_id: str):
    path = video_service.get_result_data_path(video_id)
    if not path.exists():
        raise HTTPException(404, "Tracking data not ready")
    raw = json.loads(path.read_text())
    # Apply manual corrections on top of auto tracking
    return apply_corrections_to_tracking(deepcopy(raw), video_id)


# --- Manual corrections ---


@router.get("/{video_id}/corrections")
async def get_corrections(video_id: str):
    return load_corrections(video_id).model_dump()


@router.put("/{video_id}/corrections")
async def save_all_corrections(video_id: str, body: CorrectionSet):
    body.video_id = video_id
    save_corrections(body)
    return {"saved": True}


@router.post("/{video_id}/corrections/frame")
async def save_frame_correction(video_id: str, entry: CorrectionEntry):
    """Add or update a correction for a single frame."""
    cs = load_corrections(video_id)
    # Replace existing correction for this frame, or append
    cs.corrections = [c for c in cs.corrections if c.frame_number != entry.frame_number]
    cs.corrections.append(entry)
    save_corrections(cs)
    return {"saved": True, "frame_number": entry.frame_number}


@router.delete("/{video_id}/corrections/{frame_number}")
async def delete_frame_correction(video_id: str, frame_number: int):
    cs = load_corrections(video_id)
    cs.corrections = [c for c in cs.corrections if c.frame_number != frame_number]
    save_corrections(cs)
    return {"deleted": True}


# --- Rally detection ---


@router.post("/{video_id}/detect-rallies")
async def detect_rallies(
    video_id: str,
    config: RallyDetectionConfig | None = None,
    background_tasks: BackgroundTasks = None,
):
    info = video_service.get_video(video_id)
    if not info:
        raise HTTPException(404, "Video not found")

    video_service.clear_cancel(video_id)
    job_id = video_service.create_job(video_id, "rally_split")

    def _on_detect_progress(current_frame, total_frames):
        if video_service.is_cancelled(video_id):
            raise InterruptedError("Cancelled")
        pct = round(current_frame / total_frames * 50) if total_frames > 0 else 0
        video_service.update_job(
            job_id,
            {
                "step": "detecting",
                "current_frame": current_frame,
                "total_frames": total_frames,
                "percent": pct,
            },
        )

    def _on_split_progress(step, current, total):
        pct = 50 + round(current / total * 50) if total > 0 else 50
        video_service.update_job(
            job_id,
            {
                "step": "splitting",
                "current_clip": current,
                "total_clips": total,
                "percent": pct,
            },
        )

    def _run():
        try:
            rally_service.detect_rallies(video_id, config, on_progress=_on_detect_progress)
            if not video_service.is_cancelled(video_id):
                rally_service.split_video(
                    video_id,
                    on_progress=_on_split_progress,
                    on_clip_ready=_register_clip,
                )
            video_service.finish_job(job_id)
        except InterruptedError:
            video_service.finish_job(job_id, "cancelled")
            print(f"Rally detection cancelled for {video_id}")
        except Exception as e:
            video_service.finish_job(job_id, "failed")
            print(f"Rally detection failed for {video_id}: {e}")
        finally:
            video_service.clear_cancel(video_id)

    def _register_clip(clip_path, rally):
        """Register each clip as a new video in the library as it's created."""
        clip_video_id = clip_path.stem
        clip_name = f"Rally {rally.rally_id}"
        upload_link = video_service.get_upload_path(clip_video_id)
        if not upload_link.exists():
            upload_link.symlink_to(clip_path.resolve())
        video_service._save_meta(clip_video_id, clip_name, parent_id=video_id)
        video_service._videos[clip_video_id] = video_service.VideoInfo(
            video_id=clip_video_id,
            original_name=clip_name,
            status=video_service.PipelineStatus.PENDING,
            parent_id=video_id,
        )

    background_tasks.add_task(_run)
    return {"video_id": video_id, "status": "detecting"}


@router.get("/{video_id}/rallies")
async def get_rallies(video_id: str):
    result = rally_service.load_result(video_id)
    if not result:
        raise HTTPException(404, "No rallies detected yet")
    return result.model_dump()


@router.get("/{video_id}/rallies/{rally_id}/video")
async def get_rally_video(video_id: str, rally_id: int):
    path = rally_service.get_clip_path(video_id, rally_id)
    if not path.exists():
        raise HTTPException(404, "Rally clip not found")
    return FileResponse(str(path), media_type="video/mp4", filename=f"rally_{rally_id}.mp4")
