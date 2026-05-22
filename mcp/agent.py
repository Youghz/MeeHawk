"""
Beach volleyball annotation agent — raw google-genai client (no ADK).

Strategies
----------
single_pass    : video + tools in one session (most precise — recommended)
two_pass       : analysis breakdown → tool calls (legacy, for comparison)
structured_json: video → structured JSON, no tools (fastest, cheapest)

Usage
-----
  uv run --project mcp python mcp/agent.py VIDEO_URL \\
      --label my_run \\
      --strategy single_pass \\
      --model gemini-2.5-flash \\
      --context "First 20 minutes only."
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
from pathlib import Path

from dotenv import load_dotenv
from rich.console import Console
from rich.progress import (
    BarColumn,
    MofNCompleteColumn,
    Progress,
    SpinnerColumn,
    TextColumn,
    TimeElapsedColumn,
)

MCP_DIR = Path(__file__).parent
COST_LOG = MCP_DIR / "cost_log.jsonl"
MODEL = "gemini-2.5-flash"

_console = Console(stderr=True)

# ── Pricing (Vertex AI, USD / 1M tokens) ──────────────────────────────────────

_PRICE = {"input": 0.075, "output": 0.30, "thinking": 3.50}


def _cost_usd(inp: int, out: int, think: int) -> float:
    return (inp * _PRICE["input"] + out * _PRICE["output"] + think * _PRICE["thinking"]) / 1_000_000


# ── Tool declarations ──────────────────────────────────────────────────────────

def _build_tools():
    from google.genai import types

    return types.Tool(function_declarations=[
        types.FunctionDeclaration(
            name="start_match",
            description="Initialize the match. Call exactly once before any other tool.",
            parameters=types.Schema(
                type=types.Type.OBJECT,
                properties={
                    "team_e1_name": types.Schema(type=types.Type.STRING),
                    "team_e2_name": types.Schema(type=types.Type.STRING),
                    "p1": types.Schema(type=types.Type.STRING, description="Player 1 of e1 (left team)"),
                    "p2": types.Schema(type=types.Type.STRING, description="Player 2 of e1 (left team)"),
                    "p3": types.Schema(type=types.Type.STRING, description="Player 1 of e2 (right team)"),
                    "p4": types.Schema(type=types.Type.STRING, description="Player 2 of e2 (right team)"),
                    "initial_server_id": types.Schema(type=types.Type.STRING, enum=["p1", "p2", "p3", "p4"]),
                },
                required=["team_e1_name", "team_e2_name", "p1", "p2", "p3", "p4", "initial_server_id"],
            ),
        ),
        types.FunctionDeclaration(
            name="add_ball_impact",
            description="Record one ball touch during the current rally.",
            parameters=types.Schema(
                type=types.Type.OBJECT,
                properties={
                    "x": types.Schema(type=types.Type.NUMBER, description="Normalized x [0,1], 0=left edge"),
                    "y": types.Schema(type=types.Type.NUMBER, description="Normalized y [0,1], 0=top edge"),
                    "team_side": types.Schema(type=types.Type.STRING, enum=["e1", "e2"]),
                    "is_outside": types.Schema(type=types.Type.BOOLEAN, description="True if ball landed out of bounds"),
                    "is_block": types.Schema(type=types.Type.BOOLEAN, description="True if this touch is a block"),
                    "is_server_position": types.Schema(type=types.Type.BOOLEAN, description="True for the server's initial standing position"),
                    "player_id": types.Schema(type=types.Type.STRING, enum=["p1", "p2", "p3", "p4"]),
                    "touch_type": types.Schema(type=types.Type.STRING, enum=["serve", "reception", "set", "attack", "block", "dig", "fault"]),
                },
                required=["x", "y", "team_side", "is_outside"],
            ),
        ),
        types.FunctionDeclaration(
            name="add_point",
            description="Close the current rally and award the point. Call after all ball impacts.",
            parameters=types.Schema(
                type=types.Type.OBJECT,
                properties={
                    "winner": types.Schema(type=types.Type.STRING, enum=["e1", "e2"]),
                },
                required=["winner"],
            ),
        ),
        types.FunctionDeclaration(
            name="add_ambiguous_point",
            description=(
                "Close the rally when the winning cause is NOT visible on video but can be inferred "
                "(e.g. server changes without visible fault, ball goes off-frame). "
                "A human reviewer will complete the annotation later."
            ),
            parameters=types.Schema(
                type=types.Type.OBJECT,
                properties={
                    "winner": types.Schema(type=types.Type.STRING, enum=["e1", "e2"]),
                    "note": types.Schema(type=types.Type.STRING, description="What you observed and why the cause is ambiguous"),
                },
                required=["winner", "note"],
            ),
        ),
        types.FunctionDeclaration(
            name="undo_last_impact",
            description="Remove the last ball impact from the current rally.",
            parameters=types.Schema(type=types.Type.OBJECT, properties={}),
        ),
        types.FunctionDeclaration(
            name="undo_point",
            description="Cancel the last recorded point (revert score by one).",
            parameters=types.Schema(type=types.Type.OBJECT, properties={}),
        ),
        types.FunctionDeclaration(
            name="get_match_state",
            description="Return current score, server, and history summary.",
            parameters=types.Schema(type=types.Type.OBJECT, properties={}),
        ),
        types.FunctionDeclaration(
            name="clear_rally",
            description="Discard all ball impacts of the current rally and start fresh.",
            parameters=types.Schema(type=types.Type.OBJECT, properties={}),
        ),
    ])


# ── Prompt templates ───────────────────────────────────────────────────────────

SINGLE_PASS_INSTRUCTION = """\
You are a precise beach volleyball annotation agent. Watch the video and annotate every rally immediately by calling tools.

For each rally:
1. Call add_ball_impact(is_server_position=True) for the server's starting position before the serve.
2. Call add_ball_impact for every subsequent touch: serve, reception, set, attack, block, dig, fault.
3. Call add_point(winner) once the rally is over.
   — OR — add_ambiguous_point(winner, note) when the winning cause is not visible on camera.

Use add_ambiguous_point when:
- You can infer who won (server rotated, scoreboard changed) but cannot see what happened.
- The ball goes out of frame before landing.
- A violation is implied by context (referee whistle, crowd reaction) but not captured on video.

Coordinate system: (0,0) = top-left corner, (1,1) = bottom-right corner.
e1 = left team (x roughly < 0.5), e2 = right team (x roughly > 0.5).
Minimum 2 impacts per rally (server position + serve).
Process ALL rallies in the video. Do not skip any.
"""

ANALYSIS_PROMPT = """\
Watch this beach volleyball match and produce a structured breakdown of every rally.

For each rally output exactly:
Rally N  [MM:SS–MM:SS]
  Server: <e1|e2> / <player name>
  Server position: x≈<0-1>, y≈<0-1>
  Touches:
    1. <team> <serve|reception|set|attack|block|dig|fault> at x≈..., y≈...  player=<p1-p4>
    2. ...
  Winner: <e1|e2>
  Score: E1 X – E2 Y
  Notes: <ambiguous if cause not visible, else empty>

Rules:
- Minimum 2 touches per rally (server position + serve).
- Mark rallies where the winning cause is unclear as ambiguous in Notes.
- Read score from overlay after each point.\
"""

ANNOTATION_INSTRUCTIONS = """\
You are a beach volleyball annotation agent. Annotate the match from the rally breakdown provided.

For each rally:
1. add_ball_impact(is_server_position=True) for server position.
2. add_ball_impact for every touch listed.
3. add_point(winner) — or add_ambiguous_point(winner, note) for rallies marked ambiguous.

Process ALL rallies in order.\
"""


# ── Tool dispatch ──────────────────────────────────────────────────────────────

def _dispatch(annotator, name: str, args: dict) -> dict:
    match name:
        case "start_match":           return annotator.start_match(**args)
        case "add_ball_impact":       return annotator.add_ball_impact(**args)
        case "add_point":             return annotator.add_point(**args)
        case "add_ambiguous_point":   return annotator.add_ambiguous_point(**args)
        case "undo_last_impact":      return annotator.undo_last_impact()
        case "undo_point":            return annotator.undo_point()
        case "get_match_state":       return annotator.get_match_state()
        case "clear_rally":           return annotator.clear_rally()
        case _: raise ValueError(f"unknown tool: {name}")


# ── Gemini client ──────────────────────────────────────────────────────────────

def _make_client():
    from google import genai
    project = os.environ.get("GOOGLE_CLOUD_PROJECT")
    if project:
        return genai.Client(vertexai=True, project=project, location="us-central1")
    return genai.Client(api_key=os.environ["GEMINI_API_KEY"])


# ── Token accumulator ──────────────────────────────────────────────────────────

class _Usage:
    def __init__(self) -> None:
        self.inp = self.out = self.think = self.cached = 0

    def add(self, meta) -> None:
        if meta is None:
            return
        self.inp    += meta.prompt_token_count or 0
        self.out    += meta.candidates_token_count or 0
        self.think  += meta.thoughts_token_count or 0
        self.cached += meta.cached_content_token_count or 0

    def cost(self) -> float:
        return _cost_usd(self.inp, self.out, self.think)


# ── Tool-call loop helper ──────────────────────────────────────────────────────

def _tool_loop(client, model, contents, config, annotator, usage, prog, task, point_names) -> int:
    """Run the generate→dispatch loop until no more function calls. Returns point count."""
    from google.genai import types
    points = 0

    while True:
        response = client.models.generate_content(model=model, contents=contents, config=config)
        usage.add(response.usage_metadata)

        candidate = response.candidates[0]
        content = candidate.content
        contents.append(content)

        fcs = [p.function_call for p in (content.parts or []) if p.function_call]
        if not fcs:
            break

        tool_parts = []
        for fc in fcs:
            fc_args = dict(fc.args) if fc.args else {}
            result = _dispatch(annotator, fc.name, fc_args)
            _console.print(
                f"  → {fc.name}({', '.join(f'{k}={v!r}' for k, v in fc_args.items())})",
                style="dim",
            )
            if fc.name in point_names:
                points += 1
                prog.advance(task)
            tool_parts.append(types.Part.from_function_response(
                name=fc.name,
                response={"result": result},
            ))

        contents.append(types.Content(role="user", parts=tool_parts))

    return points


# ── Strategies ─────────────────────────────────────────────────────────────────

def _single_pass(client, model, video_uri, annotator, context, job_ref) -> tuple[_Usage, int, int]:
    """Video + tools in one Gemini session. Returns (usage, points, ambiguous)."""
    from google.genai import types
    load_dotenv(MCP_DIR / ".env")

    prompt = (f"{context}\n\n" if context else "") + "Annotate this beach volleyball match rally by rally using the provided tools."

    contents = [types.Content(role="user", parts=[
        types.Part.from_uri(file_uri=video_uri, mime_type="video/mp4"),
        types.Part.from_text(text=prompt),
    ])]

    tools = _build_tools()
    config = types.GenerateContentConfig(
        system_instruction=SINGLE_PASS_INSTRUCTION,
        tools=[tools],
        tool_config=types.ToolConfig(
            function_calling_config=types.FunctionCallingConfig(mode="AUTO"),
        ),
    )

    _job_update(job_ref, "annotating", 0.1, "Annotation en cours…")

    usage = _Usage()
    with Progress(
        SpinnerColumn(),
        TextColumn("[bold cyan]single_pass[/bold cyan]  Annotation"),
        BarColumn(), MofNCompleteColumn(), TimeElapsedColumn(),
        console=_console, transient=False,
    ) as prog:
        task = prog.add_task("", total=None)
        points = _tool_loop(client, model, contents, config, annotator, usage, prog, task, {"add_point", "add_ambiguous_point"})

    ambiguous = sum(1 for p in annotator._state.history if p.needs_review) if annotator._state else 0
    return usage, points, ambiguous


def _two_pass(client, model, video_uri, annotator, context, job_ref) -> tuple[_Usage, int, int]:
    """Analysis breakdown → tool annotation. Returns (usage, points, ambiguous)."""
    from google.genai import types

    usage = _Usage()

    # ── Pass 1 ────────────────────────────────────────────────────────────────
    prompt_p1 = (f"{context}\n\n" if context else "") + ANALYSIS_PROMPT
    contents_p1 = [types.Content(role="user", parts=[
        types.Part.from_uri(file_uri=video_uri, mime_type="video/mp4"),
        types.Part.from_text(text=prompt_p1),
    ])]

    _job_update(job_ref, "analyzing", 0.0, "Analyse vidéo (1/2)…")

    with Progress(
        SpinnerColumn(),
        TextColumn("[bold cyan]Pass 1[/bold cyan]  Analyse vidéo…"),
        TimeElapsedColumn(), console=_console, transient=False,
    ) as prog:
        prog.add_task("", total=None)
        resp1 = client.models.generate_content(
            model=model, contents=contents_p1,
            config=types.GenerateContentConfig(
                system_instruction="You are a precise sports video analyst.",
            ),
        )
        usage.add(resp1.usage_metadata)

    rally_breakdown = resp1.text or ""
    n_rallies = max(1, len(re.findall(r"(?m)^Rally \d+", rally_breakdown)))
    _console.print(f"\n── Rally breakdown ({n_rallies} rallyes) ──", style="dim")
    _console.print(rally_breakdown, style="dim")
    _console.print("──────────────────────────────────────────\n", style="dim")

    _job_update(job_ref, "annotating", 0.4, "Annotation (2/2)…")

    # ── Pass 2 ────────────────────────────────────────────────────────────────
    prompt_p2 = (
        f"Here is a detailed breakdown of every rally:\n\n{rally_breakdown}\n\n"
        "Annotate the match by calling the tools in the correct order for each rally."
    )
    contents_p2 = [types.Content(role="user", parts=[types.Part.from_text(text=prompt_p2)])]

    tools = _build_tools()
    config_p2 = types.GenerateContentConfig(
        system_instruction=ANNOTATION_INSTRUCTIONS,
        tools=[tools],
        tool_config=types.ToolConfig(
            function_calling_config=types.FunctionCallingConfig(mode="AUTO"),
        ),
    )

    with Progress(
        SpinnerColumn(),
        TextColumn("[bold cyan]Pass 2[/bold cyan]  Annotation"),
        BarColumn(), MofNCompleteColumn(), TimeElapsedColumn(),
        console=_console, transient=False,
    ) as prog:
        task = prog.add_task("", total=n_rallies)
        points = _tool_loop(client, model, contents_p2, config_p2, annotator, usage, prog, task, {"add_point", "add_ambiguous_point"})

    ambiguous = sum(1 for p in annotator._state.history if p.needs_review) if annotator._state else 0
    return usage, points, ambiguous


def _structured_json(client, model, video_uri, annotator, context, job_ref) -> tuple[_Usage, int, int]:
    """Single API call with structured JSON schema. No tool loop."""
    from google.genai import types
    from pydantic import BaseModel

    class ImpactSchema(BaseModel):
        x: float
        y: float
        team_side: str
        is_outside: bool
        is_server_position: bool = False
        is_block: bool = False
        player_id: str | None = None
        touch_type: str | None = None

    class RallySchema(BaseModel):
        winner: str
        impacts: list[ImpactSchema]
        needs_review: bool = False
        review_note: str | None = None

    class MatchSchema(BaseModel):
        team_e1_name: str
        team_e2_name: str
        p1: str
        p2: str
        p3: str
        p4: str
        initial_server_id: str
        rallies: list[RallySchema]

    prompt = (
        (f"{context}\n\n" if context else "")
        + "Annotate this beach volleyball match. Output every rally with ball impacts (x,y in [0,1]). "
        "Set needs_review=true when the winning cause is not visible on camera. "
        "e1 = left team, e2 = right team. (0,0) = top-left, (1,1) = bottom-right."
    )

    _job_update(job_ref, "annotating", 0.1, "Annotation JSON structuré…")

    with Progress(
        SpinnerColumn(),
        TextColumn("[bold cyan]structured_json[/bold cyan]  Analyse…"),
        TimeElapsedColumn(), console=_console, transient=False,
    ) as prog:
        prog.add_task("", total=None)
        response = client.models.generate_content(
            model=model,
            contents=[types.Content(role="user", parts=[
                types.Part.from_uri(file_uri=video_uri, mime_type="video/mp4"),
                types.Part.from_text(text=prompt),
            ])],
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                response_schema=MatchSchema,
            ),
        )

    usage = _Usage()
    usage.add(response.usage_metadata)

    data = MatchSchema.model_validate_json(response.text)

    # Import programmatically
    annotator.start_match(
        team_e1_name=data.team_e1_name, team_e2_name=data.team_e2_name,
        p1=data.p1, p2=data.p2, p3=data.p3, p4=data.p4,
        initial_server_id=data.initial_server_id,
    )

    ambiguous = 0
    for rally in data.rallies:
        for imp in rally.impacts:
            annotator.add_ball_impact(
                x=imp.x, y=imp.y, team_side=imp.team_side, is_outside=imp.is_outside,
                is_server_position=imp.is_server_position, is_block=imp.is_block,
                player_id=imp.player_id, touch_type=imp.touch_type,
            )
        if rally.needs_review:
            annotator.add_ambiguous_point(winner=rally.winner, note=rally.review_note or "")
            ambiguous += 1
        else:
            annotator.add_point(winner=rally.winner)

    return usage, len(data.rallies), ambiguous


# ── Firestore helpers ──────────────────────────────────────────────────────────

def _init_firebase():
    import firebase_admin
    from firebase_admin import credentials
    if not firebase_admin._apps:
        cred = credentials.ApplicationDefault()
        firebase_admin.initialize_app(cred)


def _job_ref(uid: str | None, job_id: str):
    if uid is None:
        return None
    _init_firebase()
    from firebase_admin import firestore
    db = firestore.client()
    return db.collection("users").document(uid).collection("jobs").document(job_id)


def _job_update(ref, status: str, progress: float, message: str) -> None:
    if ref is None:
        return
    from firebase_admin import firestore as fs
    ref.update({"status": status, "progress": progress, "message": message, "updatedAt": fs.SERVER_TIMESTAMP})


# ── Score accuracy ─────────────────────────────────────────────────────────────

def _score_accuracy(state_path: Path) -> dict | None:
    gt_path = MCP_DIR / "ground_truth.json"
    if not gt_path.exists() or not state_path.exists():
        return None
    gt = json.loads(gt_path.read_text())["rally_sequence"]
    history = json.loads(state_path.read_text()).get("history", [])
    n = min(len(history), len(gt))
    if n == 0:
        return None
    matched = sum(1 for i in range(n) if history[i]["winner"] == gt[i]["winner"])
    last_h = history[n - 1]
    last_gt = gt[n - 1]
    return {
        "compared_rallies": n,
        "winner_accuracy": round(matched / n, 3),
        "score_drift_e1": abs(last_h["scoreE1"] - last_gt["score_e1"]),
        "score_drift_e2": abs(last_h["scoreE2"] - last_gt["score_e2"]),
    }


# ── Import to app ──────────────────────────────────────────────────────────────

def _import(state_path: Path, uid: str | None, label: str | None) -> str:
    if uid:
        sys.path.insert(0, str(MCP_DIR))
        from import_to_app import import_match
        return import_match(state_path, uid=uid, match_id=label)
    return label or "unknown"


# ── Cost log ───────────────────────────────────────────────────────────────────

def _log_cost(label, strategy, model, video_uri, duration, usage, points, ambiguous, accuracy):
    entry = {
        "ts": __import__("datetime").datetime.now(__import__("datetime").timezone.utc).isoformat(),
        "label": label,
        "strategy": strategy,
        "video": video_uri,
        "model": model,
        "duration_s": round(duration, 1),
        "input_tokens": usage.inp,
        "output_tokens": usage.out,
        "thinking_tokens": usage.think,
        "cached_tokens": usage.cached,
        "cost_usd": round(usage.cost(), 6),
        "rallies": points,
        "ambiguous_count": ambiguous,
    }
    if accuracy:
        entry["score_accuracy"] = accuracy
    with open(COST_LOG, "a") as f:
        f.write(json.dumps(entry) + "\n")
    return entry


# ── Main ───────────────────────────────────────────────────────────────────────

def main() -> None:
    load_dotenv(MCP_DIR / ".env")

    ap = argparse.ArgumentParser(description="Annotate a beach volleyball video.")
    ap.add_argument("video_uri", help="YouTube URL or gs:// URI")
    ap.add_argument("--output", help="Output JSON path (default: mcp/match_state_<label>.json)")
    ap.add_argument("--label", help="Run label used for output filename and cost log")
    ap.add_argument("--model", default=MODEL)
    ap.add_argument("--strategy", default="single_pass",
                    choices=["single_pass", "two_pass", "structured_json"])
    ap.add_argument("--context", help="Prepended to the prompt (scope, constraints, etc.)")
    ap.add_argument("--uid", help="Firebase user ID for Firestore job status")
    args = ap.parse_args()

    label = args.label or f"run_{int(time.time())}"
    state_path = Path(args.output or MCP_DIR / f"match_state_{label}.json").resolve()

    _console.print(f"Strategy : [bold]{args.strategy}[/bold]", style="cyan")
    _console.print(f"Video    : {args.video_uri}", style="dim")
    _console.print(f"Model    : {args.model}", style="dim")
    _console.print(f"Output   : {state_path}", style="dim")

    job_ref = _job_ref(args.uid, label)
    if job_ref:
        from firebase_admin import firestore as fs
        job_ref.set({
            "status": "analyzing",
            "progress": 0.0,
            "message": f"Démarrage ({args.strategy})…",
            "videoUrl": args.video_uri,
            "startedAt": fs.SERVER_TIMESTAMP,
            "updatedAt": fs.SERVER_TIMESTAMP,
        })

    client = _make_client()

    sys.path.insert(0, str(MCP_DIR))
    from annotation import MatchAnnotator
    from match_state import MatchCodec

    annotator = MatchAnnotator()
    t0 = time.monotonic()

    match args.strategy:
        case "single_pass":
            usage, points, ambiguous = _single_pass(
                client, args.model, args.video_uri, annotator, args.context, job_ref
            )
        case "two_pass":
            usage, points, ambiguous = _two_pass(
                client, args.model, args.video_uri, annotator, args.context, job_ref
            )
        case "structured_json":
            usage, points, ambiguous = _structured_json(
                client, args.model, args.video_uri, annotator, args.context, job_ref
            )
        case _:
            _console.print(f"Unknown strategy: {args.strategy}", style="red")
            sys.exit(1)

    duration = time.monotonic() - t0

    if annotator._state is None:
        _console.print("[red]No match state produced — annotation failed.[/red]")
        sys.exit(1)

    state_path.write_text(json.dumps(MatchCodec.to_json(annotator._state), ensure_ascii=False, indent=2))
    _console.print(f"\nSaved → {state_path}", style="green")

    _job_update(job_ref, "importing", 0.9, "Importation dans l'app…")

    match_id = _import(state_path, args.uid, label)
    if args.uid:
        _console.print(f"Imported as {match_id}", style="green")

    _job_update(job_ref, "done", 1.0, "Annotation terminée.")

    # Score accuracy vs ground truth
    accuracy = _score_accuracy(state_path)

    # Cost log
    entry = _log_cost(label, args.strategy, args.model, args.video_uri, duration, usage, points, ambiguous, accuracy)

    _console.print("\n── Cost summary ─────────────────────────────")
    _console.print(f"  Strategy  : {args.strategy}")
    _console.print(f"  Model     : {args.model}")
    _console.print(f"  Duration  : {duration:.1f}s")
    _console.print(f"  Tokens    : {usage.inp:,} in / {usage.out:,} out")
    _console.print(f"  Thinking  : {usage.think:,}")
    _console.print(f"  Cost      : ${entry['cost_usd']:.4f}")
    _console.print(f"  Rallies   : {points}  (ambiguous: {ambiguous})")
    if accuracy:
        _console.print(f"  Accuracy  : {accuracy['winner_accuracy']*100:.1f}%  ({accuracy['compared_rallies']} rallies compared)")
        _console.print(f"  Score drift: E1±{accuracy['score_drift_e1']}  E2±{accuracy['score_drift_e2']}")
    _console.print("─────────────────────────────────────────────")


if __name__ == "__main__":
    main()
