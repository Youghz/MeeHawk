from __future__ import annotations

import json
import os
import sys
from pathlib import Path

from mcp.server.fastmcp import FastMCP

from annotation import MatchAnnotator
from match_state import MatchCodec

STATE_FILE = Path(os.environ.get("MEEHAWK_STATE_FILE", "match_state.json"))
mcp = FastMCP("meehawk-annotation")
annotator = MatchAnnotator()

if STATE_FILE.exists():
    try:
        annotator._state = MatchCodec.from_json(json.loads(STATE_FILE.read_text()))
        print(f"Loaded state from {STATE_FILE}", file=sys.stderr)
    except Exception as exc:
        print(f"Warning: could not load {STATE_FILE}: {exc}", file=sys.stderr)


def _save() -> None:
    if annotator._state is not None:
        STATE_FILE.write_text(
            json.dumps(MatchCodec.to_json(annotator._state), indent=2, ensure_ascii=False)
        )


@mcp.tool()
def start_match(
    team_e1_name: str,
    team_e2_name: str,
    p1: str,
    p2: str,
    p3: str,
    p4: str,
    initial_server_id: str,
) -> dict:
    """Start a new beach volleyball match.

    initial_server_id must be one of: 'p1', 'p2' (team e1) or 'p3', 'p4' (team e2).
    """
    result = annotator.start_match(team_e1_name, team_e2_name, p1, p2, p3, p4, initial_server_id)
    _save()
    return result


@mcp.tool()
def add_ball_impact(
    x: float,
    y: float,
    team_side: str,
    is_outside: bool,
    is_block: bool = False,
    is_server_position: bool = False,
    player_id: str | None = None,
) -> dict:
    """Record a ball impact during the current rally.

    x, y: normalised court coordinates in [0.0, 1.0]. Net at x=0.5.
    team_side: 'e1' or 'e2' — the team on whose side the ball landed.
    is_outside: True when the ball was out of bounds.
    is_block: True when this touch was a block at the net.
    is_server_position: True for the server's starting position marker (not a ball contact).
    player_id: optional player id ('p1'..'p4').
    """
    result = annotator.add_ball_impact(x, y, team_side, is_outside, is_block, is_server_position, player_id)
    _save()
    return result


@mcp.tool()
def add_point(winner: str) -> dict:
    """Award a point to the winning team.

    winner: 'e1' or 'e2'.
    """
    result = annotator.add_point(winner)
    _save()
    return result


@mcp.tool()
def undo_last_impact() -> dict:
    """Remove the last recorded ball impact from the current rally."""
    result = annotator.undo_last_impact()
    _save()
    return result


@mcp.tool()
def undo_point() -> dict:
    """Cancel the last awarded point and restore the previous match state."""
    result = annotator.undo_point()
    _save()
    return result


@mcp.tool()
def get_match_state() -> dict:
    """Return the full match state as Flutter-compatible JSON (MatchCodec format)."""
    return annotator.get_match_state()


@mcp.tool()
def clear_rally() -> dict:
    """Discard all in-progress rally impacts and annotations without awarding a point."""
    result = annotator.clear_rally()
    _save()
    return result


def main() -> None:
    mcp.run(transport="stdio")


if __name__ == "__main__":
    main()
