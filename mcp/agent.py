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
import statistics
import sys
import time
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
COST_LOG = MCP_DIR / "cost_log.jsonl"
MODEL = "gemini-2.5-flash"

# Gemini 2.5 Flash pricing on Vertex AI (USD per 1M tokens) — update if rates change.
_PRICE = {
    "input": 0.075,
    "output": 0.30,
    "thinking": 3.50,  # thinking tokens (output side)
}


def _cost_usd(input_tok: int, output_tok: int, thinking_tok: int) -> float:
    return (
        input_tok * _PRICE["input"]
        + output_tok * _PRICE["output"]
        + thinking_tok * _PRICE["thinking"]
    ) / 1_000_000


class _PassUsage:
    """Accumulates usage_metadata across all events of one pass."""

    def __init__(self) -> None:
        self.input_tokens = 0
        self.output_tokens = 0
        self.thinking_tokens = 0
        self.cached_tokens = 0

    def add(self, meta: types.GenerateContentResponseUsageMetadata) -> None:
        self.input_tokens += meta.prompt_token_count or 0
        self.output_tokens += meta.candidates_token_count or 0
        self.thinking_tokens += meta.thoughts_token_count or 0
        self.cached_tokens += meta.cached_content_token_count or 0

    def to_dict(self) -> dict:
        return {
            "input_tokens": self.input_tokens,
            "output_tokens": self.output_tokens,
            "thinking_tokens": self.thinking_tokens,
            "cached_tokens": self.cached_tokens,
        }


def _quality_metrics(state_path: Path) -> dict:
    """Compute annotation quality indicators from the saved match state."""
    try:
        state = json.loads(state_path.read_text())
        history = state.get("history", [])
        if not history:
            return {}

        impacts_per_rally = []
        xs, ys = [], []
        video_time_set = 0
        total_impacts = 0

        for point in history:
            ball_impacts = [i for i in point.get("impacts", []) if i.get("type") == "ball"]
            # Fallback: impacts without explicit type (older codec)
            if not ball_impacts:
                ball_impacts = [i for i in point.get("impacts", []) if "x" in i and "y" in i]
            impacts_per_rally.append(len(ball_impacts))
            for imp in ball_impacts:
                xs.append(imp["x"])
                ys.append(imp["y"])
                if imp.get("videoTimeSec") is not None:
                    video_time_set += 1
                total_impacts += 1

        return {
            "rallies": len(history),
            "impacts_per_rally": impacts_per_rally,
            "x_stddev": round(statistics.stdev(xs), 3) if len(xs) > 1 else 0,
            "y_stddev": round(statistics.stdev(ys), 3) if len(ys) > 1 else 0,
            "video_time_pct": round(100 * video_time_set / total_impacts) if total_impacts else 0,
        }
    except Exception:  # noqa: BLE001
        return {}


def _write_cost_log(
    video: str,
    model: str,
    duration_s: float,
    pass1: _PassUsage,
    pass2: _PassUsage,
    quality: dict,
) -> dict:
    total_input = pass1.input_tokens + pass2.input_tokens
    total_output = pass1.output_tokens + pass2.output_tokens
    total_thinking = pass1.thinking_tokens + pass2.thinking_tokens
    cost = _cost_usd(total_input, total_output, total_thinking)

    record = {
        "ts": datetime.now(timezone.utc).isoformat(),
        "video": video,
        "model": model,
        "duration_s": round(duration_s, 1),
        "pass1": pass1.to_dict(),
        "pass2": pass2.to_dict(),
        "total": {
            "input_tokens": total_input,
            "output_tokens": total_output,
            "thinking_tokens": total_thinking,
            "cost_usd": round(cost, 6),
        },
        "quality": quality,
    }

    with COST_LOG.open("a", encoding="utf-8") as f:
        f.write(json.dumps(record, ensure_ascii=False) + "\n")

    return record


def _print_cost_summary(record: dict) -> None:
    t = record["total"]
    q = record.get("quality", {})
    print("\n── Cost summary ─────────────────────────────", file=sys.stderr)
    print(f"  Model    : {record['model']}", file=sys.stderr)
    print(f"  Duration : {record['duration_s']}s", file=sys.stderr)
    print(f"  Tokens   : {t['input_tokens']:,} in  /  {t['output_tokens']:,} out", file=sys.stderr)
    if t["thinking_tokens"]:
        print(f"  Thinking : {t['thinking_tokens']:,} tokens", file=sys.stderr)
    print(f"  Cost     : ${t['cost_usd']:.4f}", file=sys.stderr)
    if q:
        print(
            f"  Quality  : {q.get('rallies')} rallies · "
            f"x_std={q.get('x_stddev')} · y_std={q.get('y_stddev')} · "
            f"video_time={q.get('video_time_pct')}%",
            file=sys.stderr,
        )
    print(f"  Log      : {COST_LOG}", file=sys.stderr)
    print("─────────────────────────────────────────────\n", file=sys.stderr)

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


async def run_agent(
    video_uri: str,
    output: str,
    trace_path: Path | None = None,
    model: str = MODEL,
    label: str | None = None,
) -> None:
    load_dotenv(MCP_DIR / ".env")

    state_path = Path(output).resolve()
    run_start = time.monotonic()

    trace_write = None
    trace_file = None
    if trace_path is not None:
        trace_write, trace_file = _trace_writer(trace_path)
        trace_write({"type": "run_start", "ts": _now(), "video": video_uri, "model": model, "output": str(state_path)})

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
        model=model,
        name="rally_analyst",
        instruction="You are a precise sports video analyst. Analyze the video and output a structured breakdown as requested.",
    )

    # Annotation agent (with tools) — pass 2: turn breakdown into tool calls.
    annotation_agent = LlmAgent(
        model=model,
        name="beach_volleyball_annotator",
        instruction=ANNOTATION_INSTRUCTIONS,
        tools=[toolset],
    )

    session_service = InMemorySessionService()

    # ── Pass 1: rally analysis ─────────────────────────────────────────────────
    print(f"Pass 1 — analysing video: {video_uri}  [model={model}]", file=sys.stderr)
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

    pass1_usage = _PassUsage()
    rally_breakdown = ""
    async for event in analysis_runner.run_async(
        user_id="user",
        session_id=analysis_session.id,
        new_message=analysis_message,
    ):
        if event.usage_metadata:
            pass1_usage.add(event.usage_metadata)
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

    pass2_usage = _PassUsage()
    async for event in annotation_runner.run_async(
        user_id="user",
        session_id=annotation_session.id,
        new_message=annotation_message,
    ):
        if event.usage_metadata:
            pass2_usage.add(event.usage_metadata)
        _log_event(event, trace_write)

    await toolset.close()

    if trace_write:
        trace_write({"type": "run_end", "ts": _now()})
    if trace_file:
        trace_file.close()

    print(f"\nSaved to {state_path}", file=sys.stderr)

    # Auto-import into the Flutter web app's matches folder.
    from import_to_app import import_match  # noqa: PLC0415
    match_id = import_match(state_path, match_id=label)
    print(f"Imported as {match_id} — open http://localhost:8080 to view", file=sys.stderr)

    # Cost tracking.
    quality = _quality_metrics(state_path)
    record = _write_cost_log(
        video=video_uri,
        model=model,
        duration_s=time.monotonic() - run_start,
        pass1=pass1_usage,
        pass2=pass2_usage,
        quality=quality,
    )
    _print_cost_summary(record)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Annotate a beach volleyball match with Gemini + ADK"
    )
    parser.add_argument("url", help="YouTube URL or GCS URI (gs://bucket/file.mp4)")
    parser.add_argument(
        "--output",
        default=None,
        help="Output path for match_state.json (defaults to mcp/match_state_{label}.json)",
    )
    parser.add_argument(
        "--label",
        default=None,
        help="Human-readable run label used as match ID (e.g. 'gemini-2.5-pro', 'prompt-v2')",
    )
    parser.add_argument(
        "--model",
        default=MODEL,
        help=f"Gemini model to use (default: {MODEL})",
    )
    parser.add_argument(
        "--trace",
        default=None,
        help="Path for JSONL trace file (tool calls + responses). Omit to disable.",
    )
    args = parser.parse_args()
    label = args.label
    output = args.output or str(MCP_DIR / f"match_state{'_' + label if label else ''}.json")
    trace_path = Path(args.trace) if args.trace else None
    asyncio.run(run_agent(args.url, output, trace_path, model=args.model, label=label))


if __name__ == "__main__":
    main()
