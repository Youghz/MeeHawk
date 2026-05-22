"""Gemini function declarations for the beach volleyball annotation agent.

Each FunctionDeclaration corresponds to a method of :class:`annotator.core.MatchAnnotator`.
The ``description`` strings are sent verbatim to Gemini and must be self-contained — the model
has no other documentation to refer to.
"""
from __future__ import annotations

from google.genai import types


def build_tools() -> types.Tool:
    """Return the Tool object containing all annotation function declarations."""
    return types.Tool(function_declarations=[
        _start_match(),
        _add_ball_impact(),
        _add_point(),
        _add_ambiguous_point(),
        _undo_last_impact(),
        _undo_point(),
        _get_match_state(),
        _clear_rally(),
    ])


def _start_match() -> types.FunctionDeclaration:
    """Gemini tool: initialize the match before any annotation."""
    return types.FunctionDeclaration(
        name="start_match",
        description=(
            "Initialize the match. Call exactly once before any other tool. "
            "Identifies both teams and all four players from the video. "
            "e1 = left team on screen, e2 = right team. "
            "p1/p2 belong to e1, p3/p4 to e2. "
            "initial_server_id is the player who serves the very first rally: "
            "must be 'p1' or 'p2' (e1 serves) or 'p3' or 'p4' (e2 serves). "
            "Returns an error if called a second time — in that case continue annotating."
        ),
        parameters=types.Schema(
            type=types.Type.OBJECT,
            properties={
                "team_e1_name": types.Schema(type=types.Type.STRING, description="Full name of the left team"),
                "team_e2_name": types.Schema(type=types.Type.STRING, description="Full name of the right team"),
                "p1": types.Schema(type=types.Type.STRING, description="Name of player 1 (e1, front/right position)"),
                "p2": types.Schema(type=types.Type.STRING, description="Name of player 2 (e1, back/left position)"),
                "p3": types.Schema(type=types.Type.STRING, description="Name of player 1 (e2, front/left position)"),
                "p4": types.Schema(type=types.Type.STRING, description="Name of player 2 (e2, back/right position)"),
                "initial_server_id": types.Schema(
                    type=types.Type.STRING,
                    enum=["p1", "p2", "p3", "p4"],
                    description="Player ID of the first server",
                ),
            },
            required=["team_e1_name", "team_e2_name", "p1", "p2", "p3", "p4", "initial_server_id"],
        ),
    )


def _add_ball_impact() -> types.FunctionDeclaration:
    """Gemini tool: record a single ball touch during the current rally."""
    return types.FunctionDeclaration(
        name="add_ball_impact",
        description=(
            "Record one ball touch during the current rally. "
            "Call once per contact in chronological order. "
            "First call of every rally must have is_server_position=True (server's starting position before the serve). "
            "Coordinates are normalized: (0,0) = top-left corner of the full court image, "
            "(1,1) = bottom-right corner. The net runs vertically at x≈0.5. "
            "e1 occupies x < 0.5, e2 occupies x > 0.5. "
            "Estimate coordinates from the actual video frame — do not always use round numbers. "
            "If serve consistency is violated (observed server ≠ expected server), "
            "the tool returns a 'serve_inconsistency' warning with exact correction instructions — follow them before retrying."
        ),
        parameters=types.Schema(
            type=types.Type.OBJECT,
            properties={
                "x": types.Schema(
                    type=types.Type.NUMBER,
                    description="Normalized horizontal position [0.0, 1.0]. 0=left edge, 1=right edge, net at ~0.5.",
                ),
                "y": types.Schema(
                    type=types.Type.NUMBER,
                    description="Normalized vertical position [0.0, 1.0]. 0=top sideline, 1=bottom sideline.",
                ),
                "team_side": types.Schema(
                    type=types.Type.STRING,
                    enum=["e1", "e2"],
                    description="Team on whose side of the court this touch occurred.",
                ),
                "is_outside": types.Schema(
                    type=types.Type.BOOLEAN,
                    description="True if the ball landed out of bounds.",
                ),
                "is_block": types.Schema(
                    type=types.Type.BOOLEAN,
                    description="True if this touch is a block at the net.",
                ),
                "is_server_position": types.Schema(
                    type=types.Type.BOOLEAN,
                    description="True for the server's standing position before the serve (not a ball contact). Must be the first impact of every rally.",
                ),
                "player_id": types.Schema(
                    type=types.Type.STRING,
                    enum=["p1", "p2", "p3", "p4"],
                    description="Player closest to the ball at this touch.",
                ),
                "touch_type": types.Schema(
                    type=types.Type.STRING,
                    enum=["serve", "reception", "set", "attack", "block", "dig", "fault"],
                    description="Classification of this ball contact.",
                ),
            },
            required=["x", "y", "team_side", "is_outside"],
        ),
    )


def _add_point() -> types.FunctionDeclaration:
    """Gemini tool: close the current rally and award a point."""
    return types.FunctionDeclaration(
        name="add_point",
        description=(
            "Close the current rally and award the point to the winning team. "
            "Call after all ball impacts for the rally have been recorded. "
            "Use this when the winning cause is clearly visible on the video. "
            "Use add_ambiguous_point instead when the cause is not visible."
        ),
        parameters=types.Schema(
            type=types.Type.OBJECT,
            properties={
                "winner": types.Schema(
                    type=types.Type.STRING,
                    enum=["e1", "e2"],
                    description="Team that won this rally.",
                ),
            },
            required=["winner"],
        ),
    )


def _add_ambiguous_point() -> types.FunctionDeclaration:
    """Gemini tool: close a rally when the winning cause is not visible on video."""
    return types.FunctionDeclaration(
        name="add_ambiguous_point",
        description=(
            "Close the rally when the winning cause is NOT visible on the video but can be inferred "
            "from context (scoreboard update, server change, referee whistle, crowd reaction). "
            "The score is recorded correctly but the rally is flagged for human review. "
            "Use when: ball goes off-frame before landing; a violation is implied but not captured; "
            "the server rotation changes without a visible fault. "
            "Do NOT use for rallies where you can see what happened — use add_point instead."
        ),
        parameters=types.Schema(
            type=types.Type.OBJECT,
            properties={
                "winner": types.Schema(
                    type=types.Type.STRING,
                    enum=["e1", "e2"],
                    description="Team that won this rally (inferred from context).",
                ),
                "note": types.Schema(
                    type=types.Type.STRING,
                    description=(
                        "Explanation of what was observed and why the cause is ambiguous. "
                        "Example: 'Server rotated to e2 without visible fault from e1 at 04:12.'"
                    ),
                ),
            },
            required=["winner", "note"],
        ),
    )


def _undo_last_impact() -> types.FunctionDeclaration:
    """Gemini tool: remove the last ball impact from the current rally."""
    return types.FunctionDeclaration(
        name="undo_last_impact",
        description="Remove the last recorded ball impact from the current rally. Use to correct a mistaken impact without cancelling the whole rally.",
        parameters=types.Schema(type=types.Type.OBJECT, properties={}),
    )


def _undo_point() -> types.FunctionDeclaration:
    """Gemini tool: cancel the last recorded point."""
    return types.FunctionDeclaration(
        name="undo_point",
        description=(
            "Cancel the last awarded point and restore the previous match state (score reverts by one). "
            "Use when a serve_inconsistency warning indicates the previous point winner was wrong."
        ),
        parameters=types.Schema(type=types.Type.OBJECT, properties={}),
    )


def _get_match_state() -> types.FunctionDeclaration:
    """Gemini tool: return the current match state."""
    return types.FunctionDeclaration(
        name="get_match_state",
        description="Return current score, active server, set number, and full match history. Use to verify state when uncertain.",
        parameters=types.Schema(type=types.Type.OBJECT, properties={}),
    )


def _clear_rally() -> types.FunctionDeclaration:
    """Gemini tool: discard all impacts for the current rally."""
    return types.FunctionDeclaration(
        name="clear_rally",
        description="Discard all ball impacts for the current rally without awarding a point. Use to start a rally over from scratch.",
        parameters=types.Schema(type=types.Type.OBJECT, properties={}),
    )
