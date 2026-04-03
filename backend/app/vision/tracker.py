"""Simple distance-based tracker optimised for volleyball.

With only 4-6 players visible and none of them leaving the frame,
a straightforward nearest-centre assignment works better than
ByteTrack's IoU-based matching, which fails on fast movements
(jumps, dives) where bboxes shift too much between frames.
"""

import numpy as np
import supervision as sv
from scipy.optimize import linear_sum_assignment


class PlayerTracker:
    def __init__(self, fps: int = 30, max_distance: float = 250.0):
        self.fps = fps
        self.max_distance = max_distance
        self._next_id = 1
        # Active tracks: track_id -> {"center": (cx, cy), "bbox": array, "lost_frames": int}
        self._tracks: dict[int, dict] = {}
        # How many frames a track can be lost before removal
        self._max_lost = fps * 15  # 15 seconds — players never leave

    def update(self, detections: sv.Detections) -> sv.Detections:
        if len(detections) == 0:
            self._increment_lost()
            return detections

        det_centers = np.array(
            [((x1 + x2) / 2, (y1 + y2) / 2) for x1, y1, x2, y2 in detections.xyxy]
        )

        if not self._tracks:
            # First frame: assign fresh IDs
            tracker_ids = self._init_tracks(detections.xyxy, det_centers)
        else:
            tracker_ids = self._match(detections.xyxy, det_centers)

        detections.tracker_id = np.array(tracker_ids, dtype=int)
        self._increment_lost(exclude=set(tracker_ids))
        self._prune_lost()
        return detections

    def _init_tracks(self, bboxes: np.ndarray, centers: np.ndarray) -> list[int]:
        ids = []
        for i in range(len(bboxes)):
            tid = self._next_id
            self._next_id += 1
            self._tracks[tid] = {
                "center": tuple(centers[i]),
                "bbox": bboxes[i],
                "lost_frames": 0,
            }
            ids.append(tid)
        return ids

    def _match(self, bboxes: np.ndarray, det_centers: np.ndarray) -> list[int]:
        track_ids = list(self._tracks.keys())
        track_centers = np.array([self._tracks[tid]["center"] for tid in track_ids])

        # Cost matrix: euclidean distance between each detection and each track
        cost = np.linalg.norm(det_centers[:, None, :] - track_centers[None, :, :], axis=2)

        # Hungarian assignment
        row_idx, col_idx = linear_sum_assignment(cost)

        assigned_ids = [0] * len(det_centers)
        matched_tracks = set()

        for r, c in zip(row_idx, col_idx, strict=True):
            if cost[r, c] <= self.max_distance:
                tid = track_ids[c]
                assigned_ids[r] = tid
                matched_tracks.add(tid)
                self._tracks[tid]["center"] = tuple(det_centers[r])
                self._tracks[tid]["bbox"] = bboxes[r]
                self._tracks[tid]["lost_frames"] = 0

        # Unmatched detections get new IDs
        for i in range(len(det_centers)):
            if assigned_ids[i] == 0:
                tid = self._next_id
                self._next_id += 1
                self._tracks[tid] = {
                    "center": tuple(det_centers[i]),
                    "bbox": bboxes[i],
                    "lost_frames": 0,
                }
                assigned_ids[i] = tid

        return assigned_ids

    def _increment_lost(self, exclude: set[int] | None = None):
        exclude = exclude or set()
        for tid in list(self._tracks):
            if tid not in exclude:
                self._tracks[tid]["lost_frames"] += 1

    def _prune_lost(self):
        to_remove = [tid for tid, t in self._tracks.items() if t["lost_frames"] > self._max_lost]
        for tid in to_remove:
            del self._tracks[tid]

    def reset(self):
        self._next_id = 1
        self._tracks.clear()
