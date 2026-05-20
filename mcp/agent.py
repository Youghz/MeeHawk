# Agent that annotates a beach volleyball video via the meehawk-annotation MCP server.
# Uses Google ADK (LlmAgent + McpToolset) with ADC authentication (no API key needed).
#
# Usage:
#   export GOOGLE_CLOUD_PROJECT=sandbox-hugo
#   uv run python mcp/agent.py "https://www.youtube.com/watch?v=..." [--output match_state.json]
#   uv run python mcp/agent.py "gs://bucket/clip.mp4" [--trace run_trace.jsonl]
from __future__ import annotations

import argparse
import asyncio
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

from dotenv import load_dotenv

from google.adk.agents import LlmAgent
from google.adk.runners import Runner
from google.adk.sessions import InMemorySessionService
from google.adk.tools.mcp_tool import McpToolset
from google.adk.tools.mcp_tool.mcp_session_manager import StdioConnectionParams
from google.genai import types
from mcp import StdioServerParameters

MCP_DIR = Path(__file__).parent
MODEL = "gemini-2.5-flash"

# ─── Prompts ──────────────────────────────────────────────────────────────────

# Pass 1: watch the video, produce a rally-by-rally textual breakdown.
# No tool calls — pure analysis to ground pass 2.
ANALYSIS_PROMPT = """\
Watch this beach volleyball match video carefully.

Produce a structured breakdown of every rally WITHOUT calling any annotation tools yet.
For each rally, output:

Rally N  [MM:SS–MM:SS]
  Server: <team side> / <player position: front-left|back-left|front-right|back-right>
  Server position on court: x≈<estimate>, y≈<estimate>
  Touches:
    1. <team> <touch-type> at approx x=<estimate>, y=<estimate>
    2. …
  Winner: <team side>
  Notes: <anything unusual — out ball, block, fault, ace>

Coordinate system (normalised 0–1):
  x: 0.0 = left baseline · 0.5 = net · 1.0 = right baseline
  y: 0.0 = top sideline · 1.0 = bottom sideline

Be precise. Estimate real x, y values from what you see. Do NOT write x=0.25 or x=0.75 for every touch.
A serve from the left back zone starts at x≈0.10–0.20. An attack landing deep on the right lands at x≈0.80–0.95.
"""

# Pass 2: turn the analysis into tool calls.
ANNOTATION_INSTRUCTIONS = """\
You are a beach volleyball match annotator with access to a set of tools.

═══ COORDINATE SYSTEM ═══════════════════════════════════════════════════
x axis: 0.0 = left baseline  ·  0.5 = net  ·  1.0 = right baseline
y axis: 0.0 = top sideline   ·  1.0 = bottom sideline

Team e1 (LEFT side, x < 0.5):   p1 = front (near net), p2 = back
Team e2 (RIGHT side, x > 0.5):  p3 = front (near net), p4 = back

Typical zones — e1 side (mirror for e2: use 1.0 − x):
  Back zone (serve / dig):   x ≈ 0.05–0.22
  Mid zone:                  x ≈ 0.22–0.38
  Attack zone (near net):    x ≈ 0.38–0.48
  y varies: near top sideline ≈ 0.15, centre ≈ 0.50, near bottom ≈ 0.85

═══ SETUP ═══════════════════════════════════════════════════════════════
Call start_match once.
  initial_server_id: p1=left-front, p2=left-back, p3=right-front, p4=right-back.

═══ PER-RALLY ANNOTATION ════════════════════════════════════════════════
Use the rally breakdown above as your reference for EACH rally:

1. add_ball_impact (is_server_position=True): server's actual position in their back zone.
   Use the x, y you estimated in the breakdown — NOT a generic 0.25 or 0.75.

2. add_ball_impact for each ball touch in order:
   • x, y: use the coordinates from your breakdown. Vary them per touch.
   • team_side: 'e1' if ball/player is left of net, 'e2' if right.
   • player_id: p1–p4 based on where the player is standing.
   • is_block: True only when a player jumps at the net to deflect.
   • is_outside: True when ball lands out of bounds.
   • video_time_sec: timestamp in seconds for this touch.

3. add_point once the rally ends.

Use undo_last_impact if you need to correct the previous touch.

═══ QUALITY RULES ═══════════════════════════════════════════════════════
• NEVER use x=0.25 or x=0.75 for every touch — those are not real positions.
• NEVER default y=0.5 for all touches.
• Serving position is always in the back zone (x ≤ 0.20 for e1, x ≥ 0.80 for e2).
• Annotate EVERY rally. Do not skip any.
"""


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _trace_writer(trace_path: Path | None):
    """Returns a callable that appends a JSON line to trace_path, or a no-op."""
    if trace_path is None:
        return lambda entry: None
    trace_path.parent.mkdir(parents=True, exist_ok=True)
    f = trace_path.open("w", encoding="utf-8")

    def write(entry: dict) -> None:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")
        f.flush()

    return write, f


def _log_event(event, trace_write) -> None:
    """Log a runner event to trace and stderr."""
    if not event.content:
        return
    for part in event.content.parts:
        if hasattr(part, "function_call") and part.function_call:
            fc = part.function_call
            if trace_write:
                trace_write({
                    "type": "tool_call",
                    "ts": _now(),
                    "tool": fc.name,
                    "args": dict(fc.args) if fc.args else {},
                })
            print(f"  → {fc.name}({', '.join(f'{k}={v!r}' for k, v in (fc.args or {}).items())})", file=sys.stderr)
        elif hasattr(part, "function_response") and part.function_response:
            fr = part.function_response
            if trace_write:
                trace_write({
                    "type": "tool_result",
                    "ts": _now(),
                    "tool": fr.name,
                    "result": fr.response if hasattr(fr, "response") else str(fr),
                })
        elif hasattr(part, "text") and part.text:
            if trace_write:
                trace_write({"type": "model_text", "ts": _now(), "text": part.text})
            if event.is_final_response():
                print(part.text)


async def run_agent(video_uri: str, output: str, trace_path: Path | None = None) -> None:
    load_dotenv(MCP_DIR / ".env")

    state_path = Path(output).resolve()

    trace_write = None
    trace_file = None
    if trace_path is not None:
        trace_write, trace_file = _trace_writer(trace_path)
        trace_write({"type": "run_start", "ts": _now(), "video": video_uri, "model": MODEL, "output": str(state_path)})

    toolset = McpToolset(
        connection_params=StdioConnectionParams(
            server_params=StdioServerParameters(
                command="uv",
                args=[
                    "--project", str(MCP_DIR),
                    "run", "python", str(MCP_DIR / "server.py"),
                    "--state-file", str(state_path),
                ],
            )
        )
    )

    # Analysis agent (no tools) — pass 1: produce structured rally breakdown.
    analysis_agent = LlmAgent(
        model=MODEL,
        name="rally_analyst",
        instruction="You are a precise sports video analyst. Analyze the video and output a structured breakdown as requested.",
    )

    # Annotation agent (with tools) — pass 2: turn breakdown into tool calls.
    annotation_agent = LlmAgent(
        model=MODEL,
        name="beach_volleyball_annotator",
        instruction=ANNOTATION_INSTRUCTIONS,
        tools=[toolset],
    )

    session_service = InMemorySessionService()

    # ── Pass 1: rally analysis ─────────────────────────────────────────────────
    print(f"Pass 1 — analysing video: {video_uri}", file=sys.stderr)
    if trace_path:
        print(f"Trace: {trace_path}", file=sys.stderr)

    analysis_runner = Runner(agent=analysis_agent, app_name="meehawk_analysis", session_service=session_service)
    analysis_session = await session_service.create_session(app_name="meehawk_analysis", user_id="user")

    analysis_message = types.Content(
        role="user",
        parts=[
            types.Part.from_uri(file_uri=video_uri, mime_type="video/mp4"),
            types.Part.from_text(text=ANALYSIS_PROMPT),
        ],
    )

    rally_breakdown = ""
    async for event in analysis_runner.run_async(
        user_id="user",
        session_id=analysis_session.id,
        new_message=analysis_message,
    ):
        if event.is_final_response() and event.content:
            for part in event.content.parts:
                if hasattr(part, "text") and part.text:
                    rally_breakdown = part.text
                    if trace_write:
                        trace_write({"type": "rally_breakdown", "ts": _now(), "text": rally_breakdown})
                    print("\n── Rally breakdown ──────────────────────", file=sys.stderr)
                    print(rally_breakdown, file=sys.stderr)
                    print("─────────────────────────────────────────\n", file=sys.stderr)

    # ── Pass 2: annotation using tools ────────────────────────────────────────
    print("Pass 2 — annotating with tools …", file=sys.stderr)
    print(f"Output: {state_path}", file=sys.stderr)

    annotation_runner = Runner(agent=annotation_agent, app_name="meehawk", session_service=session_service)
    annotation_session = await session_service.create_session(app_name="meehawk", user_id="user")

    annotation_message = types.Content(
        role="user",
        parts=[
            types.Part.from_text(
                text=(
                    f"Here is a detailed breakdown of every rally in the video:\n\n"
                    f"{rally_breakdown}\n\n"
                    "Now annotate the match by calling the tools in the correct order for each rally."
                )
            ),
        ],
    )

    async for event in annotation_runner.run_async(
        user_id="user",
        session_id=annotation_session.id,
        new_message=annotation_message,
    ):
        _log_event(event, trace_write)

    await toolset.close()

    if trace_write:
        trace_write({"type": "run_end", "ts": _now()})
    if trace_file:
        trace_file.close()

    print(f"\nSaved to {state_path}", file=sys.stderr)

    # Auto-import into the Flutter web app's matches folder.
    from import_to_app import import_match  # noqa: PLC0415
    match_id = import_match(state_path)
    print(f"Imported as {match_id} — open http://localhost:8080 to view", file=sys.stderr)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Annotate a beach volleyball match with Gemini + ADK"
    )
    parser.add_argument("url", help="YouTube URL or GCS URI (gs://bucket/file.mp4)")
    parser.add_argument(
        "--output",
        default=str(MCP_DIR / "match_state.json"),
        help="Output path for Flutter-compatible match_state.json",
    )
    parser.add_argument(
        "--trace",
        default=None,
        help="Path for JSONL trace file (tool calls + responses). Omit to disable.",
    )
    args = parser.parse_args()
    trace_path = Path(args.trace) if args.trace else None
    asyncio.run(run_agent(args.url, args.output, trace_path))


if __name__ == "__main__":
    main()
