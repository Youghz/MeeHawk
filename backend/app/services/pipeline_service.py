import time

from fastapi import BackgroundTasks

from app.models.schemas import PipelineStatus
from app.services import video_service
from app.vision.pipeline import VideoPipeline


class CancelledError(Exception):
    pass


class PipelineService:
    _pipeline: VideoPipeline | None = None

    @classmethod
    def _get_pipeline(cls) -> VideoPipeline:
        if cls._pipeline is None:
            cls._pipeline = VideoPipeline()
        return cls._pipeline

    @classmethod
    def start_analysis(cls, video_id: str, input_path: str, background_tasks: BackgroundTasks):
        video_service.clear_cancel(video_id)
        video_service.update_status(video_id, PipelineStatus.PROCESSING)
        background_tasks.add_task(cls._run_pipeline, video_id, input_path)

    @classmethod
    def _run_pipeline(cls, video_id: str, input_path: str):
        try:
            pipeline = cls._get_pipeline()
            started_at = time.time()
            info = video_service.get_video(video_id)
            original_name = info.original_name if info else ""

            def on_progress(current: int, total: int):
                if video_service.is_cancelled(video_id):
                    raise CancelledError()
                elapsed = time.time() - started_at
                if current > 0:
                    avg_per_frame = elapsed / current
                    remaining = avg_per_frame * (total - current)
                else:
                    remaining = 0
                video_service.update_status(
                    video_id,
                    PipelineStatus.PROCESSING,
                    progress={
                        "current_frame": current,
                        "total_frames": total,
                        "elapsed_seconds": round(elapsed, 1),
                        "estimated_remaining_seconds": round(remaining, 1),
                        "percent": round((current / total) * 100, 1) if total > 0 else 0,
                    },
                )

            pipeline.process(
                input_path=input_path,
                video_id=video_id,
                original_name=original_name,
                on_progress=on_progress,
            )
            video_service.update_status(video_id, PipelineStatus.COMPLETED)
        except CancelledError:
            video_service.update_status(video_id, PipelineStatus.PENDING)
            video_service.clear_cancel(video_id)
            print(f"Pipeline cancelled for {video_id}")
        except Exception as e:
            video_service.update_status(video_id, PipelineStatus.FAILED)
            print(f"Pipeline failed for {video_id}: {e}")
            raise
