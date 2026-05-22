# Port of:
#   app/lib/features/match/providers/match_provider.dart → MatchNotifier
# Keep in sync with that file.
from __future__ import annotations

from match_state import (
    Annotation,
    BallImpact,
    MatchFormat,
    MatchState,
    PointRecord,
    SetRecord,
    TeamSide,
    initial_match_state,
    other_side,
    BEACH_FIVB,
)
from rules import (
    AttackInference,
    ServiceRotation,
    SetRules,
    consecutive_same_side_touches,
)


class MatchAnnotator:
    def __init__(self) -> None:
        self._state: MatchState | None = None

    # ──────────────────────── public API ─────────────────────────────────────

    def start_match(
        self,
        team_e1_name: str,
        team_e2_name: str,
        p1: str,
        p2: str,
        p3: str,
        p4: str,
        initial_server_id: str,
        fmt: MatchFormat = BEACH_FIVB,
    ) -> dict:
        if self._state is not None and self._state.started:
            return {
                "error": "already_started",
                "message": (
                    "Match already started — do NOT call start_match again. "
                    "Continue with add_ball_impact and add_point."
                ),
                **self._match_summary(),
            }
        if initial_server_id not in ("p1", "p2", "p3", "p4"):
            raise ValueError(f"invalid initial_server_id: {initial_server_id!r}")
        self._state = initial_match_state(
            team_e1_name=team_e1_name,
            team_e2_name=team_e2_name,
            p1=p1, p2=p2, p3=p3, p4=p4,
            initial_server_id=initial_server_id,
            fmt=fmt,
        )
        return self._match_summary()

    def add_ball_impact(
        self,
        x: float,
        y: float,
        team_side: TeamSide,
        is_outside: bool,
        is_block: bool = False,
        is_server_position: bool = False,
        player_id: str | None = None,
        video_time_sec: float | None = None,
        touch_type: str | None = None,
    ) -> dict:
        self._require_state()
        s = self._state
        if s.match_over:
            raise ValueError("match is over")
        if team_side not in ("e1", "e2"):
            raise ValueError(f"invalid team_side: {team_side!r}")
        if not (0.0 <= x <= 1.0 and 0.0 <= y <= 1.0):
            raise ValueError(f"x,y must be in [0,1]: ({x},{y})")

        impact = BallImpact(
            x=x, y=y, is_outside=is_outside, team_side=team_side,
            player_id=player_id, is_server_position=is_server_position,
            is_block=is_block, video_time_sec=video_time_sec,
            touch_type=touch_type,
        )

        if is_server_position and s.history:
            warning = self._check_serve_consistency(team_side, s)
            if warning:
                return warning  # impact NOT recorded — agent must fix history first

        if not is_server_position:
            touches = consecutive_same_side_touches(s.rally_impacts, team_side)
            if touches >= 3:
                # 4th touch: append impact first, then auto-fault
                s.rally_impacts = [*s.rally_impacts, impact]
                self._state = s
                player_name = self._player_name(player_id)
                self._add_point(
                    winner=other_side(team_side),
                    extra_annotations=[
                        Annotation(
                            type="fault",
                            text=f"Faute 4e touche · {player_name}",
                            team=team_side,
                        )
                    ],
                )
                return self._rally_state()

        prev = s.rally_impacts[-1] if s.rally_impacts else None
        annotations = list(s.rally_annotations)

        if prev is not None and prev.team_side != team_side and not prev.is_block:
            attack_type = AttackInference.classify(prev.x, prev.y, x, y)
            attacker = self._player_name(prev.player_id)
            is_service = len(s.rally_impacts) == 1  # checked BEFORE appending
            label = "Service" if is_service else "Attaque"
            atype = "service" if is_service else "attack"
            annotations.append(Annotation(
                type=atype,
                text=f"{label} {attack_type} · {attacker}",
                team=prev.team_side,
            ))

        s.rally_impacts = [*s.rally_impacts, impact]
        s.rally_annotations = annotations

        if is_block:
            s.rally_annotations = [
                *s.rally_annotations,
                Annotation(
                    type="block",
                    text=f"Bloc · {self._player_name(player_id)}",
                    team=team_side,
                ),
            ]

        self._state = s
        return self._rally_state()

    def add_point(self, winner: TeamSide) -> dict:
        self._require_state()
        if winner not in ("e1", "e2"):
            raise ValueError(f"invalid winner: {winner!r}")
        self._add_point(winner)
        return self._match_summary()

    def undo_last_impact(self) -> dict:
        self._require_state()
        s = self._state
        if not s.rally_impacts:
            return self._rally_state()

        impacts = s.rally_impacts
        last = impacts[-1]
        prev = impacts[-2] if len(impacts) >= 2 else None
        new_impacts = impacts[:-1]
        annotations = list(s.rally_annotations)

        # Block annotation is appended after crossing annotation — remove first.
        if last.is_block and annotations:
            annotations = annotations[:-1]

        # Crossing annotation (attack/service) added by add_ball_impact.
        # Not generated when prev was a block.
        if (
            prev is not None
            and not last.is_server_position
            and not prev.is_block
            and prev.team_side != last.team_side
            and annotations
        ):
            annotations = annotations[:-1]

        s.rally_impacts = new_impacts
        s.rally_annotations = [] if not new_impacts else annotations
        self._state = s
        return self._rally_state()

    def undo_point(self) -> dict:
        self._require_state()
        s = self._state
        if not s.history:
            return self._match_summary()

        if s.match_over:
            s.match_over = False

        new_history = s.history[:-1]
        replay = self._replay(new_history)

        s.history = new_history
        s.serving_player_id = replay["server_id"]
        s.next_server_index = replay["next_index"]
        s.score_e1 = replay["score_e1"]
        s.score_e2 = replay["score_e2"]
        s.sets = replay["sets"]
        s.set_number = replay["set_number"]
        s.match_over = False
        s.rally_impacts = []
        s.rally_annotations = []
        self._state = s
        return self._match_summary()

    def get_match_state(self) -> dict:
        self._require_state()
        from match_state import MatchCodec
        return MatchCodec.to_json(self._state)

    def clear_rally(self) -> dict:
        self._require_state()
        s = self._state
        s.rally_impacts = []
        s.rally_annotations = []
        self._state = s
        return self._rally_state()

    # ──────────────────────── private ────────────────────────────────────────

    def _check_serve_consistency(self, observed_server_team: TeamSide, s: MatchState) -> dict | None:
        """Return a warning dict if the observed server team contradicts the expected next server.

        In beach volleyball the winner of a point always serves next.
        After add_point(), s.serving_player_id is already updated to the next server.
        So: expected_server_team = team of s.serving_player_id.
        If that differs from observed_server_team, the previous point's winner was wrong.
        """
        expected_team = self._team_of_player(s.serving_player_id)
        if expected_team == observed_server_team:
            return None

        prev = s.history[-1]
        point_num = len(s.history)
        e1_name = s.teams["e1"].name
        e2_name = s.teams["e2"].name
        observed_name = e1_name if observed_server_team == "e1" else e2_name
        expected_name = e1_name if expected_team == "e1" else e2_name
        prev_winner_name = e1_name if prev.winner == "e1" else e2_name
        correct_winner = observed_server_team  # server wins the previous point

        return {
            "warning": "serve_inconsistency",
            "message": (
                f"⚠️ SERVE INCONSISTENCY detected before rally {point_num + 1}: "
                f"the video shows {observed_name} serving, "
                f"but point {point_num} was recorded as won by {prev_winner_name} "
                f"(expected server: {expected_name}). "
                f"In beach volleyball the winner always serves next — "
                f"point {point_num} winner should be {observed_name} (team {correct_winner}). "
                f"ACTION REQUIRED: call undo_point() to cancel point {point_num}, "
                f"then call add_point(winner='{correct_winner}') with the correct winner, "
                f"then retry this add_ball_impact call."
            ),
            "point_index": point_num - 1,
            "recorded_winner": prev.winner,
            "correct_winner": correct_winner,
            "expected_server_team": expected_team,
            "observed_server_team": observed_server_team,
        }

    def _require_state(self) -> None:
        if self._state is None:
            raise ValueError("match not started — call start_match first")

    def _player_name(self, player_id: str | None) -> str:
        if player_id is None:
            return "—"
        for team in self._state.teams.values():
            for p in team.players:
                if p.id == player_id:
                    return p.name
        return "—"

    def _team_of_player(self, player_id: str) -> TeamSide | None:
        for side, team in self._state.teams.items():
            if any(p.id == player_id for p in team.players):
                return side
        return None

    def _add_point(
        self,
        winner: TeamSide,
        extra_annotations: list[Annotation] | None = None,
    ) -> None:
        s = self._state
        if s.match_over:
            return

        serving_team = self._team_of_player(s.serving_player_id)
        gains_serve = winner != serving_team

        # Auto-assign first server (replaces Dart's pick-server popup).
        if gains_serve and s.first_server_index[winner] is None:
            s.first_server_index = {**s.first_server_index, winner: s.next_server_index[winner]}

        players_by_team = {
            side: [p.id for p in team.players]
            for side, team in s.teams.items()
        }
        server_id, new_next = ServiceRotation.next(
            current_server_id=s.serving_player_id,
            serving_team=serving_team,
            winner=winner,
            players_by_team=players_by_team,
            next_server_index=s.next_server_index,
        )

        new_score_e1 = s.score_e1 + (1 if winner == "e1" else 0)
        new_score_e2 = s.score_e2 + (1 if winner == "e2" else 0)

        merged = [*s.rally_annotations, *(extra_annotations or [])]
        point = PointRecord(
            winner=winner,
            annotations=merged,
            score_e1=new_score_e1,
            score_e2=new_score_e2,
            set_number=s.set_number,
            server_id=server_id,
            impacts=list(s.rally_impacts),
        )

        set_won = SetRules.is_set_won(new_score_e1, new_score_e2, s.set_number, s.format)

        if set_won:
            set_record = SetRecord(
                set_number=s.set_number,
                score_e1=new_score_e1,
                score_e2=new_score_e2,
                winner=winner,
            )
            new_sets = [*s.sets, set_record]
            sets_e1 = sum(1 for r in new_sets if r.winner == "e1")
            sets_e2 = sum(1 for r in new_sets if r.winner == "e2")
            match_over = SetRules.is_match_won(sets_e1, sets_e2, s.format)

            s.history = [*s.history, point]
            s.sets = new_sets
            s.score_e1 = new_score_e1
            s.score_e2 = new_score_e2
            s.rally_impacts = []
            s.rally_annotations = []
            s.match_over = match_over
            self._state = s

            if not match_over:
                self._start_next_set_internal()
        else:
            s.history = [*s.history, point]
            s.serving_player_id = server_id
            s.next_server_index = new_next
            s.score_e1 = new_score_e1
            s.score_e2 = new_score_e2
            s.rally_impacts = []
            s.rally_annotations = []
            self._state = s

    def _start_next_set_internal(self) -> None:
        s = self._state
        prev_start = self._team_of_player(s.initial_server_id)
        # Dart: setNumber.isOdd → other team starts next set; even → same team
        new_start: TeamSide = other_side(prev_start) if s.set_number % 2 == 1 else prev_start
        new_other: TeamSide = other_side(new_start)
        new_server_id = s.teams[new_start].players[0].id

        s.set_number += 1
        s.score_e1 = 0
        s.score_e2 = 0
        s.rally_impacts = []
        s.rally_annotations = []
        s.serving_player_id = new_server_id
        s.initial_server_id = new_server_id
        s.next_server_index = {new_start: 1, new_other: 0}
        s.first_server_index = {new_start: 0, new_other: None}
        s.sides_swapped = not s.sides_swapped
        s.change_side_prompt_dismissed = False
        self._state = s

    def _replay(self, history: list[PointRecord]) -> dict:
        s = self._state
        server_id = s.initial_server_id
        starting_team = self._team_of_player(server_id)
        starting_first: int = s.first_server_index[starting_team]  # type: ignore[assignment]
        other_first = s.first_server_index[other_side(starting_team)]
        team_size = len(s.teams[starting_team].players)

        next_index: dict[TeamSide, int] = {
            starting_team: (starting_first + 1) % team_size,
            other_side(starting_team): other_first if other_first is not None else 0,
        }
        players_by_team = {
            side: [p.id for p in team.players]
            for side, team in s.teams.items()
        }

        score_e1 = 0
        score_e2 = 0
        set_number = 1
        sets: list[SetRecord] = []

        for p in history:
            while p.set_number > set_number:
                sets.append(SetRecord(
                    set_number=set_number,
                    score_e1=score_e1,
                    score_e2=score_e2,
                    winner="e1" if score_e1 > score_e2 else "e2",
                ))
                score_e1 = 0
                score_e2 = 0
                set_number += 1

            serving_team = self._team_of_player(server_id)
            server_id, next_index = ServiceRotation.next(
                current_server_id=server_id,
                serving_team=serving_team,
                winner=p.winner,
                players_by_team=players_by_team,
                next_server_index=next_index,
            )

            if p.winner == "e1":
                score_e1 += 1
            else:
                score_e2 += 1

        return {
            "server_id": server_id,
            "next_index": next_index,
            "score_e1": score_e1,
            "score_e2": score_e2,
            "set_number": set_number,
            "sets": sets,
        }

    def _match_summary(self) -> dict:
        s = self._state
        sets_e1 = sum(1 for r in s.sets if r.winner == "e1")
        sets_e2 = sum(1 for r in s.sets if r.winner == "e2")
        return {
            "score_e1": s.score_e1,
            "score_e2": s.score_e2,
            "set_number": s.set_number,
            "sets_e1": sets_e1,
            "sets_e2": sets_e2,
            "serving_player_id": s.serving_player_id,
            "match_over": s.match_over,
            "points_played": len(s.history),
        }

    def _rally_state(self) -> dict:
        s = self._state
        return {
            "impacts_count": len(s.rally_impacts),
            "annotations": [
                {"type": a.type, "text": a.text, "team": a.team}
                for a in s.rally_annotations
            ],
            "score_e1": s.score_e1,
            "score_e2": s.score_e2,
            "serving_player_id": s.serving_player_id,
        }
