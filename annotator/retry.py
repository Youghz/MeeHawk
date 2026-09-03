"""Retry with linear backoff for transient Gemini / network failures.

Replaces the four near-identical retry loops that used to live inline in
``agent.py``, each with slightly different backoff and exception sets.
"""
from __future__ import annotations

import time
from typing import Callable, TypeVar

import httpx
from google.genai.errors import ClientError, ServerError
from rich.console import Console

T = TypeVar("T")

_console = Console(stderr=True)

#: Network-level failures — always worth retrying.
_NETWORK_ERRORS = (
    httpx.RemoteProtocolError,
    httpx.ConnectError,
    httpx.ReadError,
    httpx.ReadTimeout,
    ConnectionError,
)

#: API status codes worth retrying: rate limit and transient unavailability.
_RETRYABLE_STATUS = ("429", "503")


def is_transient(exc: BaseException) -> bool:
    """True when [exc] is a rate limit, a transient server error, or a network blip."""
    if isinstance(exc, _NETWORK_ERRORS):
        return True
    if isinstance(exc, (ClientError, ServerError)):
        return any(code in str(exc) for code in _RETRYABLE_STATUS)
    return False


def with_retry(
    fn: Callable[[], T],
    *,
    tries: int = 6,
    base_wait: float = 30.0,
    label: str = "",
) -> T:
    """Call [fn], retrying transient failures with linear backoff.

    Waits ``base_wait × attempt`` between attempts. Non-transient exceptions
    and the final attempt propagate unchanged, so a genuine bug still surfaces
    instead of being retried into a long silence.
    """
    for attempt in range(1, tries + 1):
        try:
            return fn()
        except Exception as exc:  # noqa: BLE001 — re-raised below unless transient
            if attempt == tries or not is_transient(exc):
                raise
            wait = base_wait * attempt
            prefix = f"{label} " if label else ""
            _console.print(
                f"\n  ⏳ {prefix}{type(exc).__name__}: {str(exc)[:40]}… "
                f"attente {wait:.0f}s ({attempt}/{tries - 1})",
                style="yellow",
            )
            time.sleep(wait)
    raise AssertionError("unreachable")  # pragma: no cover
