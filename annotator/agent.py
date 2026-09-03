"""Beach volleyball video annotation agent.

Strategy — ``rally_segmented``
------------------------------
Pass 1 (1 call)   full video → rally time boundaries + match metadata
Download          yt-dlp fetches the source video once, cached by ID
Pass 2 (N calls)  each rally is cut locally with ffmpeg and sent as inline
                  bytes → impacts + winner

Sending short clips instead of the whole video is what keeps this affordable:
Gemini only ever sees a few seconds of footage per call, and there is no Files
API quota to exhaust.

Usage
-----
  uv run --project annotator python -m annotator.agent VIDEO_URL \\
      --label my_run \\
      --model gemini-2.5-flash \\
      --context "First 20 minutes only (00:00-20:00)."

Requires ``yt-dlp`` and ``ffmpeg`` on PATH, plus ``GEMINI_API_KEY`` or
``GOOGLE_CLOUD_PROJECT`` in the environment (or in ``annotator/.env``).
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time
from pathlib import Path

from dotenv import load_dotenv
from google import genai
from google.genai import types
from rich.console import Console
from rich.progress import (
    BarColumn,
    MofNCompleteColumn,
    Progress,
    SpinnerColumn,
    TextColumn,
    TimeElapsedColumn,
)

from . import prompts, video
from .core import MatchAnnotator
from .cost import Usage, log_run, score_accuracy
from .importer import import_match
from .retry import with_retry
from .schemas import MatchTimestamps, RallyAnnotation

PKG_DIR = Path(__file__).parent
DEFAULT_MODEL = "gemini-2.5-flash"

#: Below this, timestamps in a match with several rallies are almost certainly
#: minutes rather than seconds — Gemini occasionally ignores the unit.
_MINUTES_HEURISTIC_MAX_S = 200
_MINUTES_HEURISTIC_MIN_RALLIES = 5

#: Fallback rally length when Gemini returns end <= start.
_FALLBACK_RALLY_S = 15.0

_console = Console(stderr=True)


def _make_client() -> genai.Client:
    """Vertex AI when GOOGLE_CLOUD_PROJECT is set, otherwise the API-key path."""
    project = os.environ.get("GOOGLE_CLOUD_PROJECT")
    if project:
        return genai.Client(vertexai=True, project=project, location="us-central1")
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        raise RuntimeError(
            "Set GOOGLE_CLOUD_PROJECT (Vertex AI) or GEMINI_API_KEY in the "
            "environment or in annotator/.env"
        )
    return genai.Client(api_key=api_key)


def _json_config(schema: type) -> types.GenerateContentConfig:
    return types.GenerateContentConfig(
        response_mime_type="application/json",
        response_schema=schema,
    )


# ── Pass 1: rally boundaries ─────────────────────────────────────────────────

def _sanitize_timestamps(data: MatchTimestamps) -> MatchTimestamps:
    """Repair the two failure modes Gemini reliably exhibits on timestamps.

    1. Values expressed in minutes instead of seconds.
    2. A rally whose end is at or before its start.
    """
    if not data.rallies:
        return data

    max_ts = max(max(r.start_seconds, r.end_seconds) for r in data.rallies)
    if (
        max_ts < _MINUTES_HEURISTIC_MAX_S
        and len(data.rallies) >= _MINUTES_HEURISTIC_MIN_RALLIES
    ):
        _console.print(
            f"  ⚠ Timestamps semblent être des minutes (max={max_ts:.1f}) — conversion ×60",
            style="yellow",
        )
        for r in data.rallies:
            r.start_seconds = round(r.start_seconds * 60, 1)
            r.end_seconds = round(r.end_seconds * 60, 1)

    for r in data.rallies:
        r.start_seconds = max(0.0, r.start_seconds)
        if r.end_seconds <= r.start_seconds:
            r.end_seconds = r.start_seconds + _FALLBACK_RALLY_S

    return data


def _extract_timestamps(
    client: genai.Client, video_uri: str, model: str, context: str | None
) -> tuple[MatchTimestamps, object]:
    """Pass 1: detect rally boundaries from visual cues. Returns (data, usage_metadata)."""
    prompt = prompts.load("rally_timestamps")
    if context:
        prompt = f"{context}\n\n{prompt}"

    contents = [types.Content(role="user", parts=[
        types.Part.from_uri(file_uri=video_uri, mime_type="video/mp4"),
        types.Part.from_text(text=prompt),
    ])]

    response = with_retry(
        lambda: client.models.generate_content(
            model=model, contents=contents, config=_json_config(MatchTimestamps),
        ),
        base_wait=60,
        label="Pass 1",
    )
    data = _sanitize_timestamps(MatchTimestamps.model_validate_json(response.text))
    return data, response.usage_metadata


# ── Pass 2: per-clip annotation ──────────────────────────────────────────────

def _annotate_clip(
    client: genai.Client, clip_path: Path, rally_num: int, duration: float, model: str
) -> tuple[RallyAnnotation, object]:
    """Annotate one rally clip, sent as inline bytes. Returns (annotation, usage_metadata)."""
    prompt = prompts.load("annotate_clip", rally_num=rally_num, duration=duration)
    clip_part = types.Part(
        inline_data=types.Blob(mime_type="video/mp4", data=clip_path.read_bytes())
    )

    response = with_retry(
        lambda: client.models.generate_content(
            model=model,
            contents=[types.Content(role="user", parts=[
                clip_part, types.Part.from_text(text=prompt),
            ])],
            config=_json_config(RallyAnnotation),
        ),
        label=f"Rally {rally_num}",
    )
    return RallyAnnotation.model_validate_json(response.text), response.usage_metadata


def _record_rally(annotator: MatchAnnotator, rally: RallyAnnotation) -> None:
    """Feed one annotated rally into the match state."""
    for imp in rally.impacts:
        annotator.add_ball_impact(
            x=imp.x, y=imp.y, team_side=imp.team_side, is_outside=imp.is_outside,
            is_server_position=imp.is_server_position, is_block=imp.is_block,
            player_id=imp.player_id, touch_type=imp.touch_type,
        )
    if rally.needs_review:
        annotator.add_ambiguous_point(winner=rally.winner, note=rally.review_note or "")
    else:
        annotator.add_point(winner=rally.winner)


# ── Pipeline ─────────────────────────────────────────────────────────────────

def annotate(
    client: genai.Client,
    video_uri: str,
    model: str,
    context: str | None = None,
) -> tuple[MatchAnnotator, Usage, int]:
    """Run the full rally-segmented pipeline. Returns (annotator, usage, rally count)."""
    usage = Usage()

    with Progress(
        SpinnerColumn(),
        TextColumn("[bold cyan]Pass 1[/bold cyan]  Timestamps…"),
        TimeElapsedColumn(), console=_console,
    ) as prog:
        prog.add_task("", total=None)
        timestamps, meta = _extract_timestamps(client, video_uri, model, context)
    usage.add(meta)

    n_rallies = len(timestamps.rallies)
    _console.print(
        f"\n  {n_rallies} rallies identifiés — serveur initial: {timestamps.initial_server_id}"
    )
    for r in timestamps.rallies:
        _console.print(
            f"  Rally {r.rally_num:>2}  {r.start_seconds:>6.1f}s – {r.end_seconds:>6.1f}s",
            style="dim",
        )

    video_path = video.resolve(video_uri)

    annotator = MatchAnnotator()
    annotator.start_match(
        team_e1_name=timestamps.team_e1_name,
        team_e2_name=timestamps.team_e2_name,
        p1=timestamps.p1, p2=timestamps.p2,
        p3=timestamps.p3, p4=timestamps.p4,
        initial_server_id=timestamps.initial_server_id,
    )

    with Progress(
        SpinnerColumn(),
        TextColumn("[bold cyan]Pass 2[/bold cyan]  Annotation"),
        BarColumn(), MofNCompleteColumn(), TimeElapsedColumn(),
        console=_console,
    ) as prog:
        task = prog.add_task("", total=n_rallies)

        for ts in timestamps.rallies:
            if annotator.is_over:
                _console.print(
                    f"\n  Match terminé au rally {ts.rally_num} — "
                    f"{n_rallies - ts.rally_num + 1} rallies restants ignorés.",
                    style="yellow",
                )
                break

            clip_path = video.CLIPS_DIR / f"rally_{ts.rally_num:03d}.mp4"
            video.cut_clip(video_path, ts.start_seconds, ts.end_seconds, clip_path)
            try:
                rally, meta = _annotate_clip(
                    client, clip_path, ts.rally_num,
                    ts.end_seconds - ts.start_seconds, model,
                )
            finally:
                clip_path.unlink(missing_ok=True)

            usage.add(meta)
            _record_rally(annotator, rally)
            prog.advance(task)

    return annotator, usage, n_rallies


# ── CLI ──────────────────────────────────────────────────────────────────────

def main() -> None:
    load_dotenv(PKG_DIR / ".env")

    ap = argparse.ArgumentParser(description="Annotate a beach volleyball video.")
    ap.add_argument("video_uri", help="YouTube URL or local video path")
    ap.add_argument("--label", help="Run label, used for the output filename and cost log")
    ap.add_argument("--model", default=DEFAULT_MODEL)
    ap.add_argument("--context", help="Prepended to the prompts (scope, constraints…)")
    ap.add_argument(
        "--output",
        help="Output JSON path (default: annotator/match_state_<label>.json)",
    )
    ap.add_argument(
        "--import-to-app",
        action="store_true",
        help="Also write the match into match_history/ so the Flutter app picks it up",
    )
    args = ap.parse_args()

    label = args.label or f"run_{int(time.time())}"
    state_path = Path(args.output or PKG_DIR / f"match_state_{label}.json").resolve()

    _console.print(f"Video    : {args.video_uri}", style="dim")
    _console.print(f"Model    : {args.model}", style="dim")
    _console.print(f"Output   : {state_path}", style="dim")

    client = _make_client()
    started = time.monotonic()
    annotator, usage, n_rallies = annotate(
        client, args.video_uri, args.model, args.context
    )
    duration = time.monotonic() - started

    if not annotator.started:
        _console.print("[red]No match state produced — annotation failed.[/red]")
        sys.exit(1)

    state = annotator.to_json()
    state_path.write_text(
        json.dumps(state, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    _console.print(f"\nSaved → {state_path}", style="green")

    if args.import_to_app:
        match_id = import_match(state)
        _console.print(f"Imported as {match_id}", style="green")

    accuracy = score_accuracy(state)
    entry = log_run(
        label=label,
        model=args.model,
        video=args.video_uri,
        duration_s=duration,
        usage=usage,
        rallies=n_rallies,
        ambiguous=annotator.ambiguous_count,
        accuracy=accuracy,
    )

    _console.print("\n── Cost summary ─────────────────────────────")
    _console.print(f"  Model     : {args.model}")
    _console.print(f"  Duration  : {duration:.1f}s")
    _console.print(f"  Tokens    : {usage.inp:,} in / {usage.out:,} out")
    _console.print(f"  Thinking  : {usage.think:,}")
    _console.print(f"  Cost      : ${entry['cost_usd']:.4f}")
    _console.print(f"  Rallies   : {n_rallies}  (ambiguous: {annotator.ambiguous_count})")
    if accuracy:
        _console.print(
            f"  Accuracy  : {accuracy['winner_accuracy'] * 100:.1f}%  "
            f"({accuracy['compared_rallies']} rallies compared)"
        )
        _console.print(
            f"  Score drift: E1±{accuracy['score_drift_e1']}  E2±{accuracy['score_drift_e2']}"
        )
    _console.print("─────────────────────────────────────────────")


if __name__ == "__main__":
    main()
