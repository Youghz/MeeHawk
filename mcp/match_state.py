# Port of:
#   app/lib/features/match/domain/match_state.dart  → MatchState, initial_match_state
#   app/lib/features/match/persistence/match_codec.dart → MatchCodec
#   app/lib/core/rules/match_format.dart             → MatchFormat
# Keep in sync with those files.
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Literal, Optional

TeamSide = Literal["e1", "e2"]


def other_side(side: TeamSide) -> TeamSide:
    return "e2" if side == "e1" else "e1"


@dataclass
class MatchFormat:
    sets_to_win: int = 2
    regular_set_points: int = 21
    deciding_set_points: int = 15
    win_by: int = 2
    regular_change_side_every: int = 7
    deciding_change_side_every: int = 5

    def target_for(self, set_number: int) -> int:
        return self.deciding_set_points if self._is_deciding(set_number) else self.regular_set_points

    def change_side_every_for(self, set_number: int) -> int:
        return self.deciding_change_side_every if self._is_deciding(set_number) else self.regular_change_side_every

    def _is_deciding(self, set_number: int) -> bool:
        return set_number == self.sets_to_win * 2 - 1


BEACH_FIVB = MatchFormat()


@dataclass
class Player:
    id: str
    name: str


@dataclass
class Team:
    name: str
    players: list[Player]


@dataclass
class BallImpact:
    x: float
    y: float
    is_outside: bool
    team_side: TeamSide
    player_id: Optional[str] = None
    is_server_position: bool = False
    is_block: bool = False
    video_time_sec: Optional[float] = None
    touch_type: Optional[str] = None


@dataclass
class Annotation:
    type: str
    text: str
    team: Optional[TeamSide] = None


@dataclass
class PointRecord:
    winner: TeamSide
    annotations: list[Annotation]
    score_e1: int
    score_e2: int
    set_number: int
    server_id: str
    impacts: list[BallImpact]
    needs_review: bool = False
    review_note: str | None = None


@dataclass
class SetRecord:
    set_number: int
    score_e1: int
    score_e2: int
    winner: TeamSide


@dataclass
class MatchState:
    format: MatchFormat
    teams: dict[TeamSide, Team]
    positions: dict[str, list[float]]
    serving_player_id: str
    initial_server_id: str
    next_server_index: dict[TeamSide, int]
    first_server_index: dict[TeamSide, Optional[int]]
    rally_annotations: list[Annotation]
    rally_impacts: list[BallImpact]
    history: list[PointRecord]
    sets: list[SetRecord]
    set_number: int
    score_e1: int
    score_e2: int
    sides_swapped: bool
    notes: str
    change_side_prompt_dismissed: bool
    match_over: bool
    started: bool
    tracked_teams: set[TeamSide]
    started_at: datetime


_DEFAULT_POSITIONS = {
    "p1": [0.25, 0.35],
    "p2": [0.25, 0.70],
    "p3": [0.75, 0.35],
    "p4": [0.75, 0.70],
}


def initial_match_state(
    team_e1_name: str = "Équipe 1",
    team_e2_name: str = "Équipe 2",
    p1: str = "Joueur 1",
    p2: str = "Joueur 2",
    p3: str = "Joueur 3",
    p4: str = "Joueur 4",
    initial_server_id: str = "p3",
    fmt: MatchFormat = BEACH_FIVB,
) -> MatchState:
    starting_team: TeamSide = "e1" if initial_server_id in ("p1", "p2") else "e2"
    other: TeamSide = other_side(starting_team)
    starting_idx = 0 if initial_server_id in ("p1", "p3") else 1
    return MatchState(
        format=fmt,
        teams={
            "e1": Team(name=team_e1_name, players=[Player("p1", p1), Player("p2", p2)]),
            "e2": Team(name=team_e2_name, players=[Player("p3", p3), Player("p4", p4)]),
        },
        positions=dict(_DEFAULT_POSITIONS),
        serving_player_id=initial_server_id,
        initial_server_id=initial_server_id,
        next_server_index={starting_team: (starting_idx + 1) % 2, other: 0},
        first_server_index={starting_team: starting_idx, other: None},
        rally_annotations=[],
        rally_impacts=[],
        history=[],
        sets=[],
        set_number=1,
        score_e1=0,
        score_e2=0,
        sides_swapped=False,
        notes="",
        change_side_prompt_dismissed=False,
        match_over=False,
        started=True,
        tracked_teams={"e1", "e2"},
        started_at=datetime.now(timezone.utc),
    )


# ──────────────────────── JSON helpers ────────────────────────────────────────


def _impact_to_json(i: BallImpact) -> dict:
    d: dict = {
        "x": i.x,
        "y": i.y,
        "isOutside": i.is_outside,
        "teamSide": i.team_side,
        "playerId": i.player_id,
    }
    if i.is_server_position:
        d["isServerPosition"] = True
    if i.is_block:
        d["isBlock"] = True
    if i.video_time_sec is not None:
        d["videoTimeSec"] = round(i.video_time_sec, 2)
    if i.touch_type is not None:
        d["touchType"] = i.touch_type
    return d


def _impact_from_json(j: dict) -> BallImpact:
    return BallImpact(
        x=float(j["x"]),
        y=float(j["y"]),
        is_outside=bool(j["isOutside"]),
        team_side=j["teamSide"],
        player_id=j.get("playerId"),
        is_server_position=bool(j.get("isServerPosition", False)),
        is_block=bool(j.get("isBlock", False)),
        video_time_sec=float(j["videoTimeSec"]) if j.get("videoTimeSec") is not None else None,
        touch_type=j.get("touchType"),
    )


def _annotation_to_json(a: Annotation) -> dict:
    return {"type": a.type, "text": a.text, "team": a.team}


def _annotation_from_json(j: dict) -> Annotation:
    return Annotation(type=j["type"], text=j["text"], team=j.get("team"))


def _point_to_json(p: PointRecord) -> dict:
    d = {
        "winner": p.winner,
        "annotations": [_annotation_to_json(a) for a in p.annotations],
        "scoreE1": p.score_e1,
        "scoreE2": p.score_e2,
        "setNumber": p.set_number,
        "serverId": p.server_id,
        "impacts": [_impact_to_json(i) for i in p.impacts],
    }
    if p.needs_review:
        d["needsReview"] = True
    if p.review_note:
        d["reviewNote"] = p.review_note
    return d


def _point_from_json(j: dict) -> PointRecord:
    return PointRecord(
        winner=j["winner"],
        annotations=[_annotation_from_json(a) for a in j.get("annotations", [])],
        score_e1=int(j["scoreE1"]),
        score_e2=int(j["scoreE2"]),
        set_number=int(j.get("setNumber", 1)),
        server_id=j["serverId"],
        impacts=[_impact_from_json(i) for i in j.get("impacts", [])],
        needs_review=bool(j.get("needsReview", False)),
        review_note=j.get("reviewNote"),
    )


def _set_to_json(r: SetRecord) -> dict:
    return {
        "setNumber": r.set_number,
        "scoreE1": r.score_e1,
        "scoreE2": r.score_e2,
        "winner": r.winner,
    }


def _set_from_json(j: dict) -> SetRecord:
    return SetRecord(
        set_number=int(j["setNumber"]),
        score_e1=int(j["scoreE1"]),
        score_e2=int(j["scoreE2"]),
        winner=j["winner"],
    )


class MatchCodec:
    SCHEMA_VERSION = 1

    @staticmethod
    def to_json(s: MatchState) -> dict:
        return {
            "v": MatchCodec.SCHEMA_VERSION,
            "format": {
                "setsToWin": s.format.sets_to_win,
                "regularSetPoints": s.format.regular_set_points,
                "decidingSetPoints": s.format.deciding_set_points,
                "winBy": s.format.win_by,
                "regularChangeSideEvery": s.format.regular_change_side_every,
                "decidingChangeSideEvery": s.format.deciding_change_side_every,
            },
            "teams": {
                side: {
                    "name": team.name,
                    "players": [{"id": p.id, "name": p.name} for p in team.players],
                }
                for side, team in s.teams.items()
            },
            "positions": s.positions,
            "servingPlayerId": s.serving_player_id,
            "initialServerId": s.initial_server_id,
            "nextServerIndex": dict(s.next_server_index),
            "firstServerIndex": dict(s.first_server_index),
            "history": [_point_to_json(p) for p in s.history],
            "sets": [_set_to_json(r) for r in s.sets],
            "setNumber": s.set_number,
            "scoreE1": s.score_e1,
            "scoreE2": s.score_e2,
            "sidesSwapped": s.sides_swapped,
            "notes": s.notes,
            "changeSidePromptDismissed": s.change_side_prompt_dismissed,
            "matchOver": s.match_over,
            "started": s.started,
            "trackedTeams": list(s.tracked_teams),
            "startedAt": s.started_at.strftime("%Y-%m-%dT%H:%M:%S.000Z"),
        }

    @staticmethod
    def from_json(j: dict) -> MatchState:
        fmt_j = j.get("format")
        fmt = (
            MatchFormat(
                sets_to_win=fmt_j["setsToWin"],
                regular_set_points=fmt_j["regularSetPoints"],
                deciding_set_points=fmt_j["decidingSetPoints"],
                win_by=fmt_j["winBy"],
                regular_change_side_every=fmt_j["regularChangeSideEvery"],
                deciding_change_side_every=fmt_j["decidingChangeSideEvery"],
            )
            if fmt_j
            else BEACH_FIVB
        )
        teams_j: dict = j["teams"]
        history_j: list = j.get("history", [])
        pos_j: dict = j.get("positions", {})
        positions = {k: list(v) for k, v in pos_j.items()} if pos_j else dict(_DEFAULT_POSITIONS)
        started_at_str: str | None = j.get("startedAt")
        started_at = (
            datetime.fromisoformat(started_at_str.replace("Z", "+00:00"))
            if started_at_str
            else datetime.now(timezone.utc)
        )
        tracked_raw = j.get("trackedTeams")
        tracked_teams: set[TeamSide] = set(tracked_raw) if tracked_raw is not None else {"e1", "e2"}
        return MatchState(
            format=fmt,
            teams={
                side: Team(
                    name=td["name"],
                    players=[Player(id=p["id"], name=p["name"]) for p in td["players"]],
                )
                for side, td in teams_j.items()
            },
            positions=positions,
            serving_player_id=j["servingPlayerId"],
            initial_server_id=j["initialServerId"],
            next_server_index={k: int(v) for k, v in j["nextServerIndex"].items()},
            first_server_index={k: (int(v) if v is not None else None) for k, v in j["firstServerIndex"].items()},
            rally_annotations=[],
            rally_impacts=[],
            history=[_point_from_json(p) for p in history_j],
            sets=[_set_from_json(r) for r in j.get("sets", [])],
            set_number=int(j["setNumber"]),
            score_e1=int(j["scoreE1"]),
            score_e2=int(j["scoreE2"]),
            sides_swapped=bool(j["sidesSwapped"]),
            notes=str(j.get("notes", "")),
            change_side_prompt_dismissed=bool(j.get("changeSidePromptDismissed", False)),
            match_over=bool(j.get("matchOver", False)),
            started=bool(j.get("started", bool(history_j))),
            tracked_teams=tracked_teams,
            started_at=started_at,
        )
