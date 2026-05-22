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
import re
import statistics
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

from rich.console import Console
from rich.progress import (
    BarColumn,
    MofNCompleteColumn,
    Progress,
    SpinnerColumn,
    TextColumn,
    TimeElapsedColumn,
)

_console = Console(stderr=True)

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
# Inject run-specific context (scope, score overlay location, etc.) via the
# `context` parameter of run_agent — it is prepended before this template.
ANALYSIS_PROMPT = """\
Watch this beach volleyball match video carefully.

Produce a structured breakdown of every rally WITHOUT calling any annotation tools yet.
For each rally, output:

Rally N  [MM:SS–MM:SS]
  Server: <team side e1|e2> / <player position: front-left|back-left|front-right|back-right>
  Server position on court: x≈<estimate>, y≈<estimate>
  Touches:
    1. <team e1|e2> <touch-type: serve|reception|set|attack|block|dig|fault> at x≈<estimate>, y≈<estimate>  player=<p1|p2|p3|p4>
    2. …
  Winner: <team side e1|e2>
  Score: E1 X – E2 Y   ← cumulative score after this point (compute from sequence or read overlay if visible)
  Notes: <anything unusual — out ball, block, fault, ace, score mismatch>

Touch-type vocabulary:
  serve      — the initial service contact
  reception  — first touch receiving the serve
  set        — second touch setting up the attack (passe haute)
  attack     — offensive spike, tip or roll shot
  block      — net block (jump at net to deflect)
  dig        — defensive dig (not the first serve reception)
  fault      — ball goes into the net or out of bounds

Coordinate system (normalised 0–1):
  x: 0.0 = left baseline · 0.5 = net · 1.0 = right baseline
  y: 0.0 = top sideline · 1.0 = bottom sideline

Be precise. Estimate real x, y values from what you see on court.
Do NOT write x=0.25 or x=0.75 for every touch — those are placeholder values, not real positions.
A serve from the left back zone starts at x≈0.08–0.18. An attack landing deep right: x≈0.82–0.96.
Mid-court contacts happen around x≈0.25–0.38 (e1) or x≈0.62–0.75 (e2).
"""

# Pass 2: turn the analysis into tool calls.
# Stable core — do not embed run-specific constraints here.
ANNOTATION_INSTRUCTIONS = """\
You are a beach volleyball match annotator with access to a set of tools.

═══ COORDINATE SYSTEM ═══════════════════════════════════════════════════
x axis: 0.0 = left baseline  ·  0.5 = net  ·  1.0 = right baseline
y axis: 0.0 = top sideline   ·  1.0 = bottom sideline

Team e1 (LEFT side, x < 0.5):   p1 = front (near net), p2 = back
Team e2 (RIGHT side, x > 0.5):  p3 = front (near net), p4 = back

Typical zones — e1 side (mirror for e2: use 1.0 − x):
  Back zone (serve / dig):   x ≈ 0.05–0.20
  Mid zone:                  x ≈ 0.20–0.38
  Attack zone (near net):    x ≈ 0.38–0.48
  y varies: near top sideline ≈ 0.10–0.25, centre ≈ 0.45–0.55, near bottom ≈ 0.75–0.92

═══ SETUP ═══════════════════════════════════════════════════════════════
Call start_match once.
  initial_server_id: p1=left-front, p2=left-back, p3=right-front, p4=right-back.

═══ PER-RALLY ANNOTATION ════════════════════════════════════════════════
Use the rally breakdown above as your reference for EACH rally:

1. add_ball_impact (is_server_position=True, touch_type="serve"):
   Server's actual back-zone position — NOT a generic 0.25 or 0.75.

2. add_ball_impact for EVERY ball touch listed in the breakdown, in order:
   • x, y: use the precise coordinates from the breakdown. Each touch must differ.
   • team_side: 'e1' left of net, 'e2' right of net.
   • player_id: p1–p4 based on the player's actual position.
   • touch_type: one of serve | reception | set | attack | block | dig | fault
   • is_block: True only when a player jumps at the net to deflect (also set touch_type="block").
   • is_outside: True when the ball lands out of bounds.
   • video_time_sec: timestamp in seconds for this touch.

3. add_point once the rally ends.

CRITICAL — minimum impacts per rally:
  • Every rally MUST have at least 2 add_ball_impact calls: the server position (is_server_position=True)
    PLUS at least 1 actual ball contact.
  • A serve ace: server position + serve landing on opponent's side.
  • A service fault: server position + the fault contact (is_outside=True).
  • Short rallies have 2 impacts; average rallies 3–6; long rallies 7+.

═══ QUALITY RULES ═══════════════════════════════════════════════════════
• NEVER use x=0.25 or x=0.75 as a default — use real estimated positions.
• NEVER default y=0.5 for all touches — vary y per touch.
• Serving position is always in the back zone (x ≤ 0.20 for e1, x ≥ 0.80 for e2).
• Annotate EVERY rally in the breakdown. Do not skip any.
• Use undo_last_impact to correct a wrong touch before calling add_point.
"""


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _job_ref(uid: str, job_id: str):
    """Return a Firestore DocumentReference for the annotation job, or None."""
    try:
        import firebase_admin  # noqa: PLC0415
        from firebase_admin import credentials, firestore as fs  # noqa: PLC0415

        sa = MCP_DIR / "service-account.json"
        if not firebase_admin._apps:
            firebase_admin.initialize_app(credentials.Certificate(str(sa)))
        return fs.client().collection("users").document(uid).collection("jobs").document(job_id)
    except Exception as exc:  # noqa: BLE001
        print(f"  [job] Firestore init failed: {exc}", file=sys.stderr)
        return None


def _job_update(ref, status: str, progress: float, message: str) -> None:
    """Write job status to Firestore; silently no-ops if ref is None."""
    if ref is None:
        return
    try:
        from firebase_admin import firestore as fs  # noqa: PLC0415

        ref.set(
            {"status": status, "progress": progress, "message": message,
             "updatedAt": fs.SERVER_TIMESTAMP},
            merge=True,
        )
    except Exception as exc:  # noqa: BLE001
        print(f"  [job] write failed: {exc}", file=sys.stderr)


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
    uid: str | None = None,
    context: str | None = None,
) -> None:
    load_dotenv(MCP_DIR / ".env")

    state_path = Path(output).resolve()
    run_start = time.monotonic()

    job_id = label or state_path.stem
    job_ref = _job_ref(uid, job_id) if uid else None
    if job_ref is not None:
        from firebase_admin import firestore as fs  # noqa: PLC0415
        job_ref.set({
            "status": "analyzing",
            "progress": 0.0,
            "message": "Analyse vidéo (1/2)…",
            "videoUrl": video_uri,
            "startedAt": fs.SERVER_TIMESTAMP,
            "updatedAt": fs.SERVER_TIMESTAMP,
        })

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

    # ── Pass 1: rally analysis ─────────────────────────────────────────────────
    if trace_path:
        _console.print(f"Trace : {trace_path}", style="dim")

    # Use separate session services so Pass 1's video context does NOT bleed
    # into Pass 2's context window.
    analysis_session_service = InMemorySessionService()
    analysis_runner = Runner(agent=analysis_agent, app_name="meehawk_analysis", session_service=analysis_session_service)
    analysis_session = await analysis_session_service.create_session(app_name="meehawk_analysis", user_id="user")

    prompt_text = (f"{context}\n\n" if context else "") + ANALYSIS_PROMPT
    analysis_message = types.Content(
        role="user",
        parts=[
            types.Part.from_uri(file_uri=video_uri, mime_type="video/mp4"),
            types.Part.from_text(text=prompt_text),
        ],
    )

    pass1_usage = _PassUsage()
    rally_breakdown = ""
    with Progress(
        SpinnerColumn(),
        TextColumn("[bold cyan]Pass 1[/bold cyan]  Analyse vidéo…"),
        TimeElapsedColumn(),
        console=_console,
        transient=False,
    ) as prog:
        _t1 = prog.add_task("", total=None)
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
        prog.update(_t1, description="[bold cyan]Pass 1[/bold cyan]  [green]✓[/green] Analyse terminée")

    n_rallies = max(1, len(re.findall(r"(?m)^Rally \d+", rally_breakdown)))
    _console.print(
        f"\n── Rally breakdown ({n_rallies} rallyes) ──────────────────────",
        style="dim",
    )
    _console.print(rally_breakdown, style="dim")
    _console.print("─────────────────────────────────────────\n", style="dim")

    _job_update(job_ref, "annotating", 0.4, "Annotation des rallyes (2/2)…")

    # ── Pass 2: annotation using tools ────────────────────────────────────────
    _console.print(f"Output : {state_path}", style="dim")

    annotation_session_service = InMemorySessionService()
    annotation_runner = Runner(agent=annotation_agent, app_name="meehawk", session_service=annotation_session_service)
    annotation_session = await annotation_session_service.create_session(app_name="meehawk", user_id="user")

    annotation_message = types.Content(
        role="user",
        parts=[
            types.Part.from_text(
                text=(
                    f"Here is a detailed breakdown of every rally:\n\n"
                    f"{rally_breakdown}\n\n"
                    "Now annotate the match by calling the tools in the correct order for each rally."
                )
            ),
        ],
    )

    pass2_usage = _PassUsage()
    with Progress(
        SpinnerColumn(),
        TextColumn("[bold cyan]Pass 2[/bold cyan]  Annotation"),
        BarColumn(),
        MofNCompleteColumn(),
        TimeElapsedColumn(),
        console=_console,
        transient=False,
    ) as prog:
        _t2 = prog.add_task("", total=n_rallies)
        async for event in annotation_runner.run_async(
            user_id="user",
            session_id=annotation_session.id,
            new_message=annotation_message,
        ):
            if event.usage_metadata:
                pass2_usage.add(event.usage_metadata)
            # Advance progress bar each time a point is awarded.
            if event.content:
                for part in event.content.parts:
                    if (
                        hasattr(part, "function_call")
                        and part.function_call
                        and part.function_call.name == "add_point"
                    ):
                        prog.advance(_t2)
            _log_event(event, trace_write)

    await toolset.close()

    if trace_write:
        trace_write({"type": "run_end", "ts": _now()})
    if trace_file:
        trace_file.close()

    print(f"\nSaved to {state_path}", file=sys.stderr)

    _job_update(job_ref, "importing", 0.9, "Importation dans l'app…")

    # Auto-import into the Flutter web app's matches folder.
    if uid:
        from import_to_app import import_match  # noqa: PLC0415
        match_id = import_match(state_path, uid=uid, match_id=label)
    else:
        match_id = label or "unknown"
    print(f"Imported as {match_id} — open http://localhost:8080 to view", file=sys.stderr)

    _job_update(job_ref, "done", 1.0, "Annotation terminée.")

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
    parser.add_argument(
        "--uid",
        default=None,
        help="Firebase user UID to import the match under (skips Firestore import if omitted)",
    )
    parser.add_argument(
        "--context",
        default=None,
        help=(
            "Run-specific context prepended to the analysis prompt. "
            "Use to restrict scope (e.g. 'First set only, stop at 20:00') "
            "or describe score overlay location."
        ),
    )
    args = parser.parse_args()
    label = args.label
    output = args.output or str(MCP_DIR / f"match_state{'_' + label if label else ''}.json")
    trace_path = Path(args.trace) if args.trace else None
    asyncio.run(run_agent(
        args.url, output, trace_path,
        model=args.model, label=label, uid=args.uid, context=args.context,
    ))


if __name__ == "__main__":
    main()
