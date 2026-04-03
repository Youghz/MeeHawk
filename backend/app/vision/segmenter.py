"""SAM 2 video segmentation with frame skipping and bbox interpolation."""

import numpy as np
import torch
from transformers import Sam2VideoModel, Sam2VideoProcessor


def _best_device() -> tuple[torch.device, torch.dtype]:
    """Pick the fastest available device and matching dtype."""
    if torch.cuda.is_available():
        return torch.device("cuda"), torch.bfloat16
    if torch.backends.mps.is_available():
        return torch.device("mps"), torch.bfloat16
    return torch.device("cpu"), torch.float32


class VideoSegmenter:
    def __init__(self, model_id: str = "facebook/sam2.1-hiera-tiny"):
        self.device, self.dtype = _best_device()
        self.model = Sam2VideoModel.from_pretrained(model_id).to(self.device, dtype=self.dtype)
        self.processor = Sam2VideoProcessor.from_pretrained(model_id)

    def propagate(
        self,
        frames: list[np.ndarray],
        initial_bboxes: list[list[float]],
        initial_obj_ids: list[int],
        ref_frame_idx: int = 0,
        frame_skip: int = 3,
        on_progress: callable = None,
    ) -> dict[int, list[dict]]:
        """Run SAM 2 on sampled frames, then interpolate bboxes for skipped frames.

        Args:
            frames: all RGB frames (H, W, 3)
            initial_bboxes: [[x1,y1,x2,y2], ...] on ref frame
            initial_obj_ids: [1, 2, ...] matching each bbox
            ref_frame_idx: which original frame has the detections
            frame_skip: process 1 every N frames (1 = no skip)
            on_progress: callback(current, total) on original frame count
        """
        total = len(frames)
        h, w = frames[0].shape[:2]

        # Sample frames
        sampled_indices = list(range(0, total, frame_skip))
        sampled_frames = [frames[i] for i in sampled_indices]

        # Map ref frame to sampled index
        ref_sampled = self._closest_sampled(ref_frame_idx, sampled_indices)

        # Run SAM 2 on sampled frames
        session = self.processor.init_video_session(
            video=sampled_frames,
            inference_device=self.device,
            dtype=self.dtype,
        )

        self.processor.add_inputs_to_inference_session(
            inference_session=session,
            frame_idx=ref_sampled,
            obj_ids=initial_obj_ids,
            input_boxes=[initial_bboxes],
        )
        self.model(inference_session=session, frame_idx=ref_sampled)

        # Collect SAM results keyed by ORIGINAL frame index
        sam_results: dict[int, list[dict]] = {}

        for output in self.model.propagate_in_video_iterator(session, show_progress_bar=False):
            masks = self.processor.post_process_masks(
                [output.pred_masks],
                original_sizes=[[h, w]],
                binarize=False,
            )[0]

            frame_objects = []
            for obj_idx, obj_id in enumerate(output.object_ids):
                mask = masks[obj_idx].cpu().float().numpy()
                score = float(torch.sigmoid(output.object_score_logits[obj_idx]).item())
                bbox = self._mask_to_bbox(mask)
                if bbox is None:
                    continue
                frame_objects.append({"obj_id": obj_id, "bbox": bbox, "confidence": score})

            # Map sampled index back to original frame index
            orig_idx = sampled_indices[output.frame_idx]
            sam_results[orig_idx] = frame_objects

            if on_progress:
                on_progress(orig_idx + 1, total)

        # Interpolate bboxes for all frames
        if frame_skip > 1:
            return self._interpolate(sam_results, total)
        return sam_results

    @staticmethod
    def _interpolate(
        sam_results: dict[int, list[dict]],
        total_frames: int,
    ) -> dict[int, list[dict]]:
        """Linearly interpolate bboxes between SAM-processed keyframes."""
        sorted_keys = sorted(sam_results.keys())
        if not sorted_keys:
            return {}

        # Discover all obj_ids actually returned by SAM 2
        all_obj_ids: set[int] = set()
        for objs in sam_results.values():
            for obj in objs:
                all_obj_ids.add(obj["obj_id"])

        # Build per-object timelines: obj_id -> [(frame, bbox, conf), ...]
        timelines: dict[int, list[tuple[int, list[float], float]]] = {
            oid: [] for oid in all_obj_ids
        }
        for fn in sorted_keys:
            for obj in sam_results[fn]:
                timelines[obj["obj_id"]].append((fn, obj["bbox"], obj["confidence"]))

        full: dict[int, list[dict]] = {}
        for fn in range(total_frames):
            frame_objs = []
            for oid in sorted(all_obj_ids):
                tl = timelines[oid]
                if not tl:
                    continue
                bbox, conf = _interp_at(tl, fn)
                if bbox is not None:
                    frame_objs.append({"obj_id": oid, "bbox": bbox, "confidence": conf})
            full[fn] = frame_objs
        return full

    @staticmethod
    def _closest_sampled(target: int, sampled: list[int]) -> int:
        return min(range(len(sampled)), key=lambda i: abs(sampled[i] - target))

    @staticmethod
    def _mask_to_bbox(mask: np.ndarray, threshold: float = 0.5) -> list[float] | None:
        while mask.ndim > 2:
            mask = mask[0]
        binary = (mask > threshold).astype(np.uint8)
        coords = np.argwhere(binary)
        if coords.size == 0:
            return None
        y1, x1 = coords.min(axis=0)
        y2, x2 = coords.max(axis=0)
        return [float(x1), float(y1), float(x2), float(y2)]


def _interp_at(
    timeline: list[tuple[int, list[float], float]], frame: int
) -> tuple[list[float] | None, float]:
    """Interpolate bbox at a given frame from a sorted timeline of keyframes."""
    if not timeline:
        return None, 0.0

    # Before first keyframe or after last: use nearest
    if frame <= timeline[0][0]:
        return timeline[0][1], timeline[0][2]
    if frame >= timeline[-1][0]:
        return timeline[-1][1], timeline[-1][2]

    # Find surrounding keyframes
    for i in range(len(timeline) - 1):
        fn_a, bbox_a, conf_a = timeline[i]
        fn_b, bbox_b, conf_b = timeline[i + 1]
        if fn_a <= frame <= fn_b:
            if fn_a == fn_b:
                return bbox_a, conf_a
            t = (frame - fn_a) / (fn_b - fn_a)
            bbox = [a + t * (b - a) for a, b in zip(bbox_a, bbox_b, strict=True)]
            conf = conf_a + t * (conf_b - conf_a)
            return bbox, conf

    return timeline[-1][1], timeline[-1][2]
