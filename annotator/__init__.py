"""MeeHawk annotation pipeline.

Two entry points share the same scoring engine:

- ``annotator.agent``       — annotate a video with Gemini, rally by rally
- ``annotator.mcp_server``  — expose the same scoring actions as MCP tools

Both drive :class:`MatchAnnotator`, a line-for-line port of the Flutter
``MatchNotifier``. See ``annotator/README.md`` for the parity contract.
"""
from annotator.core import MatchAnnotator
from annotator.state import MatchCodec, MatchState, initial_match_state

__all__ = ["MatchAnnotator", "MatchCodec", "MatchState", "initial_match_state"]
