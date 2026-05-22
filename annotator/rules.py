"""Pure beach volleyball rules — zero Flutter dependency.

Ports from:
  app/lib/core/rules/set_rules.dart → SetRules
  app/lib/core/rules/service_rotation.dart → ServiceRotation
  app/lib/core/rules/attack_inference.dart → AttackInference
  app/lib/core/rules/rally_analyzer.dart → RallyAnalyzer
  app/lib/core/rules/analytics_rules.dart → AnalyticsRules
  app/lib/core/rules/touch_attribution.dart → TouchAttribution

Keep in sync with those Dart files.
"""
from __future__ import annotations

from .state import BallImpact, MatchFormat, TeamSide, other_side


class SetRules:
    MAX_TEAM_TOUCHES = 3  # §9.1 FIVB Rules 2021-2024

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


class AnalyticsRules:
    """Pure analytics helpers — port of app/lib/core/rules/analytics_rules.dart."""

    @staticmethod
    def exchanges(net_crossings: int) -> int:
        """Exchanges = net crossings minus the service crossing (capped at 4)."""
        if net_crossings <= 1:
            return 0
        return min(net_crossings - 1, 4)

    @staticmethod
    def max_streak(points: list, team: TeamSide) -> int:
        best = 0
        cur = 0
        for p in points:
            if p.winner == team:
                cur += 1
                if cur > best:
                    best = cur
            else:
                cur = 0
        return best

    @staticmethod
    def subtype(text: str) -> str | None:
        parts = text.split('·')
        if not parts:
            return None
        words = parts[0].strip().split(' ')
        if len(words) <= 1:
            return None
        return ' '.join(words[1:]).strip()

    @staticmethod
    def cap(s: str) -> str:
        return s if not s else s[0].upper() + s[1:]

    @staticmethod
    def half_x(x: float) -> float:
        """Maps raw court x ∈ [0, 1] to half-court x ∈ [0=net, 1=baseline]."""
        if x >= 0.5:
            return min(max((x - 0.5) * 2, 0.0), 1.0)
        return min(max((0.5 - x) * 2, 0.0), 1.0)


class TouchAttribution:
    @staticmethod
    def last_player_on_side(impacts: list[BallImpact], side: TeamSide) -> str | None:
        for i in range(len(impacts) - 1, -1, -1):
            imp = impacts[i]
            if not imp.is_server_position and imp.team_side == side:
                return imp.player_id
        return None

    @staticmethod
    def last_player_who_touched(impacts: list[BallImpact]) -> str | None:
        for i in range(len(impacts) - 1, -1, -1):
            imp = impacts[i]
            if not imp.is_server_position:
                return imp.player_id
        return None

    @staticmethod
    def infer_next_player(
        impacts: list[BallImpact],
        side: TeamSide,
        player_ids: list[str],
    ) -> str | None:
        last_on_side: BallImpact | None = None
        for i in range(len(impacts) - 1, -1, -1):
            imp = impacts[i]
            if imp.is_server_position:
                continue
            if imp.team_side != side:
                break
            last_on_side = imp
            break
        if last_on_side is None:
            return None
        if last_on_side.is_block:
            return last_on_side.player_id
        last_id = last_on_side.player_id
        if last_id is None:
            return None
        others = [pid for pid in player_ids if pid != last_id]
        return others[0] if others else last_id


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
