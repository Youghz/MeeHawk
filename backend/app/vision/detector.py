import cv2
import numpy as np
import supervision as sv
from rfdetr import RFDETRBase

# Minimum bbox height as fraction of frame height.
# Filters out distant spectators/coaches — on a volleyball broadcast,
# players of interest fill at least ~8% of the frame height.
MIN_HEIGHT_RATIO = 0.15

# Minimum bbox area as fraction of frame area.
MIN_AREA_RATIO = 0.005


class PlayerDetector:
    def __init__(self, confidence: float = 0.35):
        self.model = RFDETRBase()
        self.model.optimize_for_inference()
        self.confidence = confidence

    def detect(self, frame: np.ndarray) -> sv.Detections:
        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        detections = self.model.predict(frame_rgb, threshold=self.confidence)

        if len(detections) == 0:
            return detections

        # Drop non-indexable data fields that break supervision filtering
        detections.data.pop("source_image", None)
        detections.data.pop("source_shape", None)

        # Keep person class only (COCO class_id 1 in rfdetr)
        mask = detections.class_id == 1
        detections = detections[mask]

        if len(detections) == 0:
            return detections

        # Filter out small detections (distant people, spectators)
        frame_h, frame_w = frame.shape[:2]
        frame_area = frame_h * frame_w

        heights = detections.xyxy[:, 3] - detections.xyxy[:, 1]
        widths = detections.xyxy[:, 2] - detections.xyxy[:, 0]
        areas = heights * widths

        size_mask = (heights >= frame_h * MIN_HEIGHT_RATIO) & (areas >= frame_area * MIN_AREA_RATIO)
        return detections[size_mask]
