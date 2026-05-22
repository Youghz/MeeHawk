"""MeeHawk annotation pipeline.

Public API:
    MatchAnnotator  — orchestrates rally-by-rally annotation
    MatchState      — immutable match state snapshot
    MatchCodec      — JSON serialization / deserialization
"""
from annotator.core import MatchAnnotator
from annotator.state import MatchCodec, MatchState, initial_match_state

__all__ = ["MatchAnnotator", "MatchCodec", "MatchState", "initial_match_state"]
