"""Pydantic schemas for Gemini structured output.

These types define the JSON contract between Gemini and :mod:`annotator.core`.
Field names and value ranges are mirrored in the prompts under
``annotator/prompts/`` — changing one without the other will silently degrade
annotation quality.
"""
from __future__ import annotations

from typing import Literal

from pydantic import BaseModel

PlayerId = Literal["p1", "p2", "p3", "p4"]
Side = Literal["e1", "e2"]
TouchType = Literal[
    "serve", "reception", "set", "attack", "block", "dig", "fault"
]


class Impact(BaseModel):
    """One ball contact. Coordinates are normalized: (0,0) top-left, (1,1) bottom-right."""

    x: float
    y: float
    team_side: Side
    is_outside: bool
    is_server_position: bool = False
    is_block: bool = False
    player_id: PlayerId | None = None
    touch_type: TouchType | None = None

    #: Seconds from the start of the *clip*, not the match. The pipeline adds
    #: the rally's start offset to get an absolute video time. Optional — the
    #: model is far more reliable on ordering than on timing.
    time_offset_sec: float | None = None


class RallyAnnotation(BaseModel):
    """Full annotation of a single rally clip."""

    winner: Side
    impacts: list[Impact]
    needs_review: bool = False
    review_note: str | None = None


class RallyTimestamp(BaseModel):
    """Time boundaries of one rally, in seconds from the start of the video.

    Both bounds carry a few seconds of margin so the clip captures the
    server's approach and the players' reaction to the point.
    """

    rally_num: int
    start_seconds: float
    end_seconds: float


class MatchTimestamps(BaseModel):
    """Pass 1 output: match metadata plus the boundaries of every rally."""

    team_e1_name: str
    team_e2_name: str
    p1: str
    p2: str
    p3: str
    p4: str
    initial_server_id: PlayerId
    rallies: list[RallyTimestamp]
