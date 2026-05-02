# Port of:
#   app/lib/core/rules/set_rules.dart        → SetRules
#   app/lib/core/rules/service_rotation.dart → ServiceRotation
#   app/lib/core/rules/attack_inference.dart → AttackInference
#   app/lib/core/rules/rally_analyzer.dart   → RallyAnalyzer
# Keep in sync with those files.
from __future__ import annotations

from match_state import BallImpact, MatchFormat, TeamSide, other_side


class SetRules:
    @staticmethod
    def is_set_won(points_a: int, points_b: int, set_number: int, fmt: MatchFormat) -> bool:
        target = fmt.target_for(set_number)
        leader = max(points_a, points_b)
        gap = abs(points_a - points_b)
        return leader >= target and gap >= fmt.win_by

    @staticmethod
    def is_match_won(sets_won_a: int, sets_won_b: int, fmt: MatchFormat) -> bool:
        return sets_won_a >= fmt.sets_to_win or sets_won_b >= fmt.sets_to_win

    @staticmethod
    def should_prompt_side_change(total_points: int, set_number: int, fmt: MatchFormat) -> bool:
        if total_points <= 0:
            return False
        every = fmt.change_side_every_for(set_number)
        return total_points % every == 0


class ServiceRotation:
    @staticmethod
    def next(
        current_server_id: str,
        serving_team: TeamSide,
        winner: TeamSide,
        players_by_team: dict[TeamSide, list[str]],
        next_server_index: dict[TeamSide, int],
    ) -> tuple[str, dict[TeamSide, int]]:
        if winner == serving_team:
            return current_server_id, dict(next_server_index)
        players = players_by_team[winner]
        idx = next_server_index[winner]
        new_next = {**next_server_index, winner: (idx + 1) % len(players)}
        return players[idx % len(players)], new_next


class AttackInference:
    SHORT_DEPTH_THRESHOLD = 0.22

    @staticmethod
    def classify(from_x: float, from_y: float, to_x: float, to_y: float) -> str:
        depth = abs(to_x - 0.5)
        is_short = depth < AttackInference.SHORT_DEPTH_THRESHOLD
        lateral_same = (from_y - 0.5) * (to_y - 0.5) > 0
        if is_short and lateral_same:
            return "Amorti"
        if is_short and not lateral_same:
            return "Diagonale"
        if not is_short and lateral_same:
            return "Ligne"
        return "Diagonale"


class RallyAnalyzer:
    @staticmethod
    def net_crossings(impacts: list[BallImpact]) -> int:
        if len(impacts) < 2:
            return 0
        crossings = 0
        prev = impacts[0].team_side
        for i in range(1, len(impacts)):
            side = impacts[i].team_side
            if side != prev:
                crossings += 1
            prev = side
        return crossings


def consecutive_same_side_touches(impacts: list[BallImpact], side: TeamSide) -> int:
    """Count consecutive same-team touches at the tail of impacts, skipping server-position markers."""
    count = 0
    for i in range(len(impacts) - 1, -1, -1):
        if impacts[i].is_server_position:
            continue
        if impacts[i].team_side != side:
            break
        count += 1
    return count
