# Agent that annotates a beach volleyball YouTube video via the meehawk-annotation MCP server.
# Uses Google ADK (LlmAgent + McpToolset) with ADC authentication (no API key needed).
#
# Usage:
#   export GOOGLE_CLOUD_PROJECT=sandbox-hugo
#   uv run python mcp/agent.py "https://www.youtube.com/watch?v=..." [--output match_state.json]
from __future__ import annotations

import argparse
import asyncio
import os
import sys
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


async def run_agent(youtube_url: str, output: str) -> None:
    load_dotenv(MCP_DIR / ".env")

    # MCP server subprocess inherits the full environment (including ADC + state file path)
    state_path = Path(output).resolve()
    os.environ["MEEHAWK_STATE_FILE"] = str(state_path)

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
    runner = Runner(
        agent=agent,
        app_name="meehawk",
        session_service=session_service,
    )
    session = await session_service.create_session(app_name="meehawk", user_id="user")

    print(f"Annotating: {youtube_url}", file=sys.stderr)
    print(f"Output: {state_path}", file=sys.stderr)

    message = types.Content(
        role="user",
        parts=[
            types.Part.from_uri(file_uri=youtube_url, mime_type="video/mp4"),
            types.Part.from_text(text="Annotate this beach volleyball match using the available tools."),
        ],
    )

    async for event in runner.run_async(
        user_id="user",
        session_id=session.id,
        new_message=message,
    ):
        if event.is_final_response() and event.content and event.content.parts:
            print(event.content.parts[0].text)

    await toolset.close()
    print(f"\nSaved to {state_path}", file=sys.stderr)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Annotate a beach volleyball YouTube match with Gemini + ADK"
    )
    parser.add_argument("url", help="Public YouTube URL of the match")
    parser.add_argument(
        "--output",
        default=str(MCP_DIR / "match_state.json"),
        help="Output path for Flutter-compatible match_state.json",
    )
    args = parser.parse_args()
    asyncio.run(run_agent(args.url, args.output))


if __name__ == "__main__":
    main()
