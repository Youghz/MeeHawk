"""
Beach volleyball annotation agent — raw google-genai client (no ADK).

Strategies
----------
rally_segmented: timestamp rallies → download → upload → annotate per segment (recommended)
two_pass       : analysis breakdown → tool calls (legacy, for comparison)
structured_json: video → structured JSON, no tools (fastest, cheapest)
single_pass    : video + tools in one session (expensive — for reference only)

Usage
-----
  uv run --project annotator python -m annotator.agent VIDEO_URL \\
      --label my_run \\
      --strategy rally_segmented \\
      --model gemini-2.5-flash \\
      --context "First 20 minutes only (00:00–20:00)."

Requirements for rally_segmented
---------------------------------
  brew install yt-dlp ffmpeg      # or equivalent
  GEMINI_API_KEY must be set      # Files API not available on Vertex AI
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

from .core import MatchAnnotator
from .state import MatchCodec
from .tools import build_tools

PKG_DIR = Path(__file__).parent
COST_LOG = PKG_DIR / "cost_log.jsonl"
DOWNLOADS_DIR = PKG_DIR / "downloads"
MODEL = "gemini-2.5-flash"

_console = Console(stderr=True)

# ── Pricing (Vertex AI, USD / 1M tokens) ──────────────────────────────────────

_PRICE = {"input": 0.075, "output": 0.30, "thinking": 3.50}


def _cost_usd(inp: int, out: int, think: int) -> float:
    return (inp * _PRICE["input"] + out * _PRICE["output"] + think * _PRICE["thinking"]) / 1_000_000


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
        case "add_ball_impact":
            args.setdefault("is_outside", False)
            return annotator.add_ball_impact(**args)
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
    from google.genai.errors import ClientError
    points = 0

    while True:
        # Retry on 429 quota errors with exponential backoff.
        for attempt in range(6):
            try:
                response = client.models.generate_content(model=model, contents=contents, config=config)
                break
            except ClientError as e:
                if "429" in str(e) and attempt < 5:
                    wait = 60 * (attempt + 1)
                    _console.print(f"\n  ⏳ 429 quota — attente {wait}s (tentative {attempt + 1}/5)…", style="yellow")
                    time.sleep(wait)
                else:
                    raise
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
    load_dotenv(PKG_DIR / ".env")

    prompt = (f"{context}\n\n" if context else "") + "Annotate this beach volleyball match rally by rally using the provided tools."

    contents = [types.Content(role="user", parts=[
        types.Part.from_uri(file_uri=video_uri, mime_type="video/mp4"),
        types.Part.from_text(text=prompt),
    ])]

    tools = build_tools()
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

    tools = build_tools()
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
    from typing import Literal
    from google.genai import types
    from pydantic import BaseModel

    _VALID_IDS = {"p1", "p2", "p3", "p4"}
    _VALID_SIDES = {"e1", "e2"}

    class ImpactSchema(BaseModel):
        x: float
        y: float
        team_side: Literal["e1", "e2"]
        is_outside: bool
        is_server_position: bool = False
        is_block: bool = False
        player_id: Literal["p1", "p2", "p3", "p4"] | None = None
        touch_type: Literal["serve", "reception", "set", "attack", "block", "dig", "fault"] | None = None

    class RallySchema(BaseModel):
        winner: Literal["e1", "e2"]
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
        initial_server_id: Literal["p1", "p2", "p3", "p4"]
        rallies: list[RallySchema]

    prompt = (
        (f"{context}\n\n" if context else "")
        + "Annotate this beach volleyball match. Output every rally with ball impacts (x,y in [0,1]). "
        "Set needs_review=true when the winning cause is not visible on camera. "
        "e1 = left team, e2 = right team. (0,0) = top-left, (1,1) = bottom-right."
    )

    _job_update(job_ref, "annotating", 0.1, "Annotation JSON structuré…")

    contents = [types.Content(role="user", parts=[
        types.Part.from_uri(file_uri=video_uri, mime_type="video/mp4"),
        types.Part.from_text(text=prompt),
    ])]
    config = types.GenerateContentConfig(
        response_mime_type="application/json",
        response_schema=MatchSchema,
    )

    with Progress(
        SpinnerColumn(),
        TextColumn("[bold cyan]structured_json[/bold cyan]  Analyse…"),
        TimeElapsedColumn(), console=_console, transient=False,
    ) as prog:
        prog.add_task("", total=None)
        from google.genai.errors import ClientError
        for attempt in range(6):
            try:
                response = client.models.generate_content(model=model, contents=contents, config=config)
                break
            except ClientError as e:
                if "429" in str(e) and attempt < 5:
                    wait = 60 * (attempt + 1)
                    _console.print(f"\n  ⏳ 429 quota — attente {wait}s…", style="yellow")
                    time.sleep(wait)
                else:
                    raise

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
        if annotator._state and annotator._state.match_over:
            break
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


# ── Rally-segmented strategy helpers ──────────────────────────────────────────

def _make_api_key_client():
    """Return a Gemini Developer client using GEMINI_API_KEY (required for Files API)."""
    from google import genai
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        raise RuntimeError("GEMINI_API_KEY must be set for rally_segmented (Files API not available on Vertex AI)")
    return genai.Client(api_key=api_key)


def _download_video(video_url: str) -> Path:
    """Download a YouTube video with yt-dlp (caches by video ID). Returns local mp4 path."""
    import subprocess

    # Resolve video ID first to check cache.
    id_result = subprocess.run(
        ["yt-dlp", "--print", "id", video_url],
        capture_output=True, text=True, check=True,
    )
    video_id = id_result.stdout.strip()
    DOWNLOADS_DIR.mkdir(exist_ok=True)
    out = DOWNLOADS_DIR / f"{video_id}.mp4"

    if out.exists():
        _console.print(f"  Cached → {out.name}", style="dim")
        return out

    _console.print(f"  Downloading {video_id}…", style="dim")
    subprocess.run(
        [
            "yt-dlp",
            "-o", str(out),
            "--format", "bestvideo[ext=mp4][height<=720]+bestaudio[ext=m4a]/best[ext=mp4][height<=720]/best[ext=mp4]/best",
            "--merge-output-format", "mp4",
            video_url,
        ],
        check=True,
    )
    return out


def _upload_video(client, video_path: Path):
    """Upload a local video to Gemini Files API. Returns the File object when ACTIVE."""
    import mimetypes
    from google.genai import types

    size_mb = video_path.stat().st_size // 1_048_576
    _console.print(f"  Uploading {video_path.name} ({size_mb} MB)…", style="dim")

    mime = mimetypes.guess_type(str(video_path))[0] or "video/mp4"
    uploaded = client.files.upload(file=video_path, config=types.UploadFileConfig(mime_type=mime))

    while uploaded.state.name == "PROCESSING":
        time.sleep(5)
        uploaded = client.files.get(name=uploaded.name)

    if uploaded.state.name != "ACTIVE":
        raise RuntimeError(f"File upload failed — state: {uploaded.state}")

    _console.print(f"  File ready → {uploaded.name}", style="dim")
    return uploaded


def _extract_rally_timestamps(client, video_url: str, model: str, context: str):
    """Pass 1: send the full video and return match metadata + per-rally timestamps.

    Returns (TimestampResponse, usage_metadata).
    """
    from typing import Literal
    from pydantic import BaseModel
    from google.genai import types

    class RallyTimestamp(BaseModel):
        rally_num: int
        start_seconds: float
        end_seconds: float
        winner: Literal["e1", "e2"]
        score_e1_after: int
        score_e2_after: int

    class TimestampResponse(BaseModel):
        team_e1_name: str
        team_e2_name: str
        p1: str
        p2: str
        p3: str
        p4: str
        initial_server_id: Literal["p1", "p2", "p3", "p4"]
        rallies: list[RallyTimestamp]

    prompt = (
        (f"{context}\n\n" if context else "")
        + """\
Watch this beach volleyball match and identify every rally.

Player assignment:
- e1 = left team at the start; p1 and p2 are their players
- e2 = right team at the start; p3 and p4 are their players

For EACH rally provide:
- start_seconds: when the server begins serving (float, seconds from video start)
- end_seconds: when the point is awarded (float, seconds from video start)
- winner: which team won (e1 or e2) — read from the scoreboard overlay
- score_e1_after / score_e2_after: scoreboard values AFTER this point

Rules:
- Use the scoreboard (top-right overlay) as the authoritative source.
- A rally starts when the server's arm begins the service motion.
- A rally ends when the referee signals the point or the ball clearly lands.
- Capture ALL rallies within the given scope, in order."""
    )

    contents = [types.Content(role="user", parts=[
        types.Part.from_uri(file_uri=video_url, mime_type="video/mp4"),
        types.Part.from_text(text=prompt),
    ])]

    resp = client.models.generate_content(
        model=model,
        contents=contents,
        config=types.GenerateContentConfig(
            response_mime_type="application/json",
            response_schema=TimestampResponse,
        ),
    )
    return TimestampResponse.model_validate_json(resp.text), resp.usage_metadata


def _annotate_segment(client, uploaded_file, rally_num: int, start_s: float, end_s: float,
                      winner: str, score_e1: int, score_e2: int, model: str):
    """Pass 2: annotate a single rally segment using a file offset window.

    Returns (impacts list, needs_review, review_note, usage_metadata).
    """
    from typing import Literal
    from pydantic import BaseModel
    from google.genai import types

    class ImpactSchema(BaseModel):
        x: float
        y: float
        team_side: Literal["e1", "e2"]
        is_outside: bool
        is_server_position: bool = False
        is_block: bool = False
        player_id: Literal["p1", "p2", "p3", "p4"] | None = None
        touch_type: Literal["serve", "reception", "set", "attack", "block", "dig", "fault"] | None = None

    class SegmentAnnotation(BaseModel):
        impacts: list[ImpactSchema]
        needs_review: bool = False
        review_note: str | None = None

    duration = end_s - start_s
    prompt = f"""\
This clip shows beach volleyball rally #{rally_num} ({duration:.1f}s).
Winner: {winner} — score after: E1={score_e1} / E2={score_e2}.

Annotate every ball touch in order:
1. Server starting position: is_server_position=True (before the serve)
2. Every subsequent touch: serve, reception, set, attack, block, dig, fault

Coordinate system: (0,0)=top-left, (1,1)=bottom-right.
e1 plays on the left (x≈0–0.5), e2 on the right (x≈0.5–1).
Players: p1 p2 for e1 · p3 p4 for e2.

Set needs_review=true only when the winning action is not visible on camera."""

    video_part = types.Part(
        file_data=types.FileData(file_uri=uploaded_file.uri, mime_type=uploaded_file.mime_type or "video/mp4"),
        video_metadata=types.VideoMetadata(
            start_offset=f"{start_s:.3f}s",
            end_offset=f"{end_s:.3f}s",
        ),
    )

    resp = client.models.generate_content(
        model=model,
        contents=[types.Content(role="user", parts=[video_part, types.Part.from_text(text=prompt)])],
        config=types.GenerateContentConfig(
            response_mime_type="application/json",
            response_schema=SegmentAnnotation,
        ),
    )

    data = SegmentAnnotation.model_validate_json(resp.text)
    return data.impacts, data.needs_review, data.review_note, resp.usage_metadata


def _rally_segmented(client, model, video_url, annotator, context, job_ref) -> tuple[_Usage, int, int]:
    """Timestamp rallies → download → upload → annotate per segment.

    Pass 1 (1 API call):  YouTube URL → rally timestamps + match metadata
    Download:             yt-dlp saves video locally (cached by ID)
    Upload:               Gemini Files API → file_uri (one-time)
    Pass 2 (N API calls): Each rally → VideoMetadata(start_offset, end_offset) → impacts
    """
    from google.genai.errors import ClientError

    usage = _Usage()

    # ── Pass 1: extract timestamps ────────────────────────────────────────────
    _job_update(job_ref, "analyzing", 0.05, "Extraction des timestamps…")

    with Progress(
        SpinnerColumn(),
        TextColumn("[bold cyan]Pass 1[/bold cyan]  Timestamps…"),
        TimeElapsedColumn(), console=_console, transient=False,
    ) as prog:
        prog.add_task("", total=None)
        ts_data, ts_meta = _extract_rally_timestamps(client, video_url, model, context)

    usage.add(ts_meta)
    n = len(ts_data.rallies)
    _console.print(f"\n  {n} rallies identifiés — serveur initial: {ts_data.initial_server_id}")
    for r in ts_data.rallies:
        _console.print(
            f"  Rally {r.rally_num:>2}  {r.start_seconds:>6.1f}s – {r.end_seconds:>6.1f}s  "
            f"winner={r.winner}  score={r.score_e1_after}-{r.score_e2_after}",
            style="dim",
        )

    # ── Download + upload ─────────────────────────────────────────────────────
    _job_update(job_ref, "analyzing", 0.2, "Téléchargement de la vidéo…")

    is_youtube = "youtube.com" in video_url or "youtu.be" in video_url
    if is_youtube:
        video_path = _download_video(video_url)
    else:
        video_path = Path(video_url)
        if not video_path.exists():
            raise FileNotFoundError(f"Local video not found: {video_path}")

    _job_update(job_ref, "analyzing", 0.35, "Upload vers Gemini Files API…")
    file_client = _make_api_key_client()
    uploaded = _upload_video(file_client, video_path)

    # ── Init match ────────────────────────────────────────────────────────────
    annotator.start_match(
        team_e1_name=ts_data.team_e1_name,
        team_e2_name=ts_data.team_e2_name,
        p1=ts_data.p1, p2=ts_data.p2,
        p3=ts_data.p3, p4=ts_data.p4,
        initial_server_id=ts_data.initial_server_id,
    )

    # ── Pass 2: per-rally annotation ──────────────────────────────────────────
    _job_update(job_ref, "annotating", 0.4, "Annotation par rally…")

    ambiguous = 0
    with Progress(
        SpinnerColumn(),
        TextColumn("[bold cyan]Pass 2[/bold cyan]  Annotation"),
        BarColumn(), MofNCompleteColumn(), TimeElapsedColumn(),
        console=_console, transient=False,
    ) as prog:
        task = prog.add_task("", total=n)

        for ts in ts_data.rallies:
            if annotator._state and annotator._state.match_over:
                break

            for attempt in range(6):
                try:
                    impacts, needs_review, review_note, meta = _annotate_segment(
                        file_client, uploaded,
                        ts.rally_num, ts.start_seconds, ts.end_seconds,
                        ts.winner, ts.score_e1_after, ts.score_e2_after,
                        model,
                    )
                    break
                except ClientError as e:
                    if "429" in str(e) and attempt < 5:
                        wait = 60 * (attempt + 1)
                        _console.print(f"\n  ⏳ 429 quota — attente {wait}s…", style="yellow")
                        time.sleep(wait)
                    else:
                        raise

            usage.add(meta)

            for imp in impacts:
                annotator.add_ball_impact(
                    x=imp.x, y=imp.y, team_side=imp.team_side, is_outside=imp.is_outside,
                    is_server_position=imp.is_server_position, is_block=imp.is_block,
                    player_id=imp.player_id, touch_type=imp.touch_type,
                )

            if needs_review:
                annotator.add_ambiguous_point(winner=ts.winner, note=review_note or "")
                ambiguous += 1
            else:
                annotator.add_point(winner=ts.winner)

            prog.advance(task)

    # Clean up uploaded file to avoid quota accumulation.
    try:
        file_client.files.delete(name=uploaded.name)
    except Exception:
        pass

    return usage, n, ambiguous


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
    gt_path = PKG_DIR / "ground_truth.json"
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
        from .importer import import_match
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
    load_dotenv(PKG_DIR / ".env")

    ap = argparse.ArgumentParser(description="Annotate a beach volleyball video.")
    ap.add_argument("video_uri", help="YouTube URL or gs:// URI")
    ap.add_argument("--output", help="Output JSON path (default: annotator/match_state_<label>.json)")
    ap.add_argument("--label", help="Run label used for output filename and cost log")
    ap.add_argument("--model", default=MODEL)
    ap.add_argument("--strategy", default="rally_segmented",
                    choices=["rally_segmented", "single_pass", "two_pass", "structured_json"])
    ap.add_argument("--context", help="Prepended to the prompt (scope, constraints, etc.)")
    ap.add_argument("--uid", help="Firebase user ID for Firestore job status")
    args = ap.parse_args()

    label = args.label or f"run_{int(time.time())}"
    state_path = Path(args.output or PKG_DIR / f"match_state_{label}.json").resolve()

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

    annotator = MatchAnnotator()
    t0 = time.monotonic()

    match args.strategy:
        case "rally_segmented":
            usage, points, ambiguous = _rally_segmented(
                client, args.model, args.video_uri, annotator, args.context, job_ref
            )
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
