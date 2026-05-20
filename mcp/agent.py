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

SYSTEM_PROMPT = """
You are annotating a beach volleyball match video.
Watch the entire video carefully and annotate every rally using the available tools.

SETUP (do this first):
- Call start_match once. Identify team names and player names from jersey text or scoreboards.
  If names aren't visible, use generic names (Left Team / Right Team, Player 1..4).
- Convention: left side of screen = team e1 (players p1=left-front, p2=left-back),
  right side = team e2 (players p3=right-front, p4=right-back).
- Determine which side serves first and which specific player serves.
  initial_server_id: left-front→"p1", left-back→"p2", right-front→"p3", right-back→"p4".

EACH RALLY:
1. add_ball_impact with is_server_position=True for the server's court position before the serve.
2. add_ball_impact for every ball touch you observe:
   - team_side: "e1" if touch on left half, "e2" if on right half.
   - x: use 0.25 for left side, 0.75 for right side (approximate is fine).
   - y: use 0.5 unless lateral position is clearly visible.
   - is_block: True only when a player blocks at the net.
   - is_outside: True when the ball lands out of bounds.
3. add_point once per rally with the winning team.

CORRECTIONS: If you misjudged the last touch, call undo_last_impact before continuing.

Annotate the full match from the first serve to the final point. Do not skip rallies.
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


async def run_agent(video_uri: str, output: str, trace_path: Path | None = None) -> None:
    load_dotenv(MCP_DIR / ".env")

    state_path = Path(output).resolve()
    os.environ["MEEHAWK_STATE_FILE"] = str(state_path)

    trace_write = None
    trace_file = None
    if trace_path is not None:
        trace_write, trace_file = _trace_writer(trace_path)
        trace_write({"type": "run_start", "ts": _now(), "video": video_uri, "model": MODEL, "output": str(state_path)})

    toolset = McpToolset(
        connection_params=StdioConnectionParams(
            server_params=StdioServerParameters(
                command="uv",
                args=["--project", str(MCP_DIR), "run", "python", str(MCP_DIR / "server.py")],
            )
        )
    )

    agent = LlmAgent(
        model=MODEL,
        name="beach_volleyball_annotator",
        instruction=SYSTEM_PROMPT,
        tools=[toolset],
    )

    session_service = InMemorySessionService()
    runner = Runner(agent=agent, app_name="meehawk", session_service=session_service)
    session = await session_service.create_session(app_name="meehawk", user_id="user")

    print(f"Annotating: {video_uri}", file=sys.stderr)
    print(f"Output: {state_path}", file=sys.stderr)
    if trace_path:
        print(f"Trace: {trace_path}", file=sys.stderr)

    message = types.Content(
        role="user",
        parts=[
            types.Part.from_uri(file_uri=video_uri, mime_type="video/mp4"),
            types.Part.from_text(text="Annotate this beach volleyball match using the available tools."),
        ],
    )

    async for event in runner.run_async(
        user_id="user",
        session_id=session.id,
        new_message=message,
    ):
        if trace_write is None:
            if event.is_final_response() and event.content and event.content.parts:
                print(event.content.parts[0].text)
            continue

        # --- trace all events ---
        if not event.content:
            continue

        for part in event.content.parts:
            # Tool call emitted by the model
            if hasattr(part, "function_call") and part.function_call:
                fc = part.function_call
                trace_write({
                    "type": "tool_call",
                    "ts": _now(),
                    "tool": fc.name,
                    "args": dict(fc.args) if fc.args else {},
                })
                print(f"  → {fc.name}({', '.join(f'{k}={v!r}' for k, v in (fc.args or {}).items())})", file=sys.stderr)

            # Tool response from MCP
            elif hasattr(part, "function_response") and part.function_response:
                fr = part.function_response
                result = fr.response if hasattr(fr, "response") else str(fr)
                trace_write({
                    "type": "tool_result",
                    "ts": _now(),
                    "tool": fr.name,
                    "result": result,
                })

            # Model text (final summary or intermediate reasoning)
            elif hasattr(part, "text") and part.text:
                trace_write({"type": "model_text", "ts": _now(), "text": part.text})
                if event.is_final_response():
                    print(part.text)

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
