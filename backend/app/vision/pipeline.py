import json

import cv2

from app.core.config import settings
from app.models.schemas import Detection, TrackingFrame, TrackingResult
from app.vision.detector import PlayerDetector
from app.vision.segmenter import VideoSegmenter

TARGET_PLAYERS = 4
DEFAULT_FRAME_SKIP = 3


class VideoPipeline:
    def __init__(self):
        self.detector = PlayerDetector()
        self.segmenter = VideoSegmenter()

    def process(
        self,
        input_path: str,
        video_id: str,
        original_name: str = "",
        frame_skip: int = DEFAULT_FRAME_SKIP,
        max_frames: int | None = None,
        on_progress: callable = None,
    ) -> TrackingResult:
        tracking_path = settings.RESULTS_DIR / f"{video_id}_tracking.json"

        # --- Step 1: Load video frames ---
        cap = cv2.VideoCapture(input_path)
        fps = cap.get(cv2.CAP_PROP_FPS)
        frames_rgb = []

        while cap.isOpened():
            ret, frame = cap.read()
            if not ret:
                break
            if max_frames and len(frames_rgb) >= max_frames:
                break
            frames_rgb.append(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
        cap.release()

        total_frames = len(frames_rgb)
        if total_frames == 0:
            result = TrackingResult(video_id=video_id, fps=fps, total_frames=0, frames=[])
            self._save_json(tracking_path, result, original_name)
            return result

        # --- Step 2: Find a frame with exactly TARGET_PLAYERS detections ---
        ref_frame_idx, detections = self._find_reference_frame(frames_rgb)

        if len(detections) == 0:
            result = TrackingResult(
                video_id=video_id, fps=fps, total_frames=total_frames, frames=[]
            )
            self._save_json(tracking_path, result, original_name)
            return result

        initial_bboxes = detections.xyxy.tolist()
        initial_obj_ids = list(range(1, len(detections) + 1))
        print(f"Reference frame {ref_frame_idx}: {len(detections)} players detected")

        if on_progress:
            on_progress(1, total_frames)

        # --- Step 3: Propagate with SAM 2 from the reference frame ---
        sam_results = self.segmenter.propagate(
            frames=frames_rgb,
            initial_bboxes=initial_bboxes,
            initial_obj_ids=initial_obj_ids,
            ref_frame_idx=ref_frame_idx,
            frame_skip=frame_skip,
            on_progress=on_progress,
        )

        # --- Step 4: Build tracking result ---
        frames_data: list[TrackingFrame] = []
        for fn in range(total_frames):
            frame_objects = sam_results.get(fn, [])
            frame_dets = [
                Detection(
                    tracker_id=obj["obj_id"],
                    bbox=obj["bbox"],
                    confidence=obj["confidence"],
                    class_name="player",
                )
                for obj in frame_objects
            ]
            frames_data.append(
                TrackingFrame(
                    frame_number=fn,
                    timestamp=fn / fps,
                    detections=frame_dets,
                )
            )

        result = TrackingResult(
            video_id=video_id,
            fps=fps,
            total_frames=total_frames,
            frames=frames_data,
        )

        self._save_json(tracking_path, result, original_name)
        return result

    def _find_reference_frame(self, frames_rgb: list):
        """Scan frames with RF-DETR until we find one with TARGET_PLAYERS.

        Falls back to the frame with the most detections if none has exactly
        the target count.
        """
        best_frame_idx = 0
        best_detections = None
        best_count = 0

        for idx, frame_rgb in enumerate(frames_rgb):
            frame_bgr = cv2.cvtColor(frame_rgb, cv2.COLOR_RGB2BGR)
            detections = self.detector.detect(frame_bgr)
            count = len(detections)

            if count == TARGET_PLAYERS:
                return idx, detections

            if count > best_count:
                best_count = count
                best_frame_idx = idx
                best_detections = detections

        return best_frame_idx, best_detections

    @staticmethod
    def _save_json(path, result: TrackingResult, original_name: str):
        output_data = result.model_dump()
        output_data["original_name"] = original_name
        path.write_text(json.dumps(output_data, indent=2, default=str))
