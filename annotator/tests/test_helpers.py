"""Tests for the pure helpers around the annotation pipeline."""
from __future__ import annotations

import httpx
import pytest
from google.genai.errors import ClientError

from annotator import prompts
from annotator.importer import match_id_for
from annotator.retry import is_transient, with_retry


def _client_error(status: int) -> ClientError:
    return ClientError(status, {"error": {"message": f"boom {status}"}})


class TestMatchId:
    """match_id_for mirrors MatchArchive.idFor in app/lib/domain/match_archive.dart.

    Both sides must derive the same id from the same start time, or importing an
    annotation would create a duplicate archive instead of updating the human one.
    """

    def test_strips_separators_and_zone(self) -> None:
        assert match_id_for("2026-05-20T14:57:25.000Z") == "match_20260520T145725000"

    def test_local_timestamp_without_zone(self) -> None:
        assert match_id_for("2026-05-20T14:57:25.000") == "match_20260520T145725000"


class TestIsTransient:
    @pytest.mark.parametrize("status", [429, 503])
    def test_retryable_api_status(self, status: int) -> None:
        assert is_transient(_client_error(status))

    @pytest.mark.parametrize("status", [400, 401, 404])
    def test_permanent_api_status(self, status: int) -> None:
        assert not is_transient(_client_error(status))

    def test_network_errors(self) -> None:
        assert is_transient(httpx.ConnectError("refused"))
        assert is_transient(httpx.RemoteProtocolError("truncated"))

    def test_unrelated_exception(self) -> None:
        assert not is_transient(ValueError("bad input"))


class TestWithRetry:
    def test_returns_first_success_without_sleeping(self) -> None:
        assert with_retry(lambda: "ok") == "ok"

    def test_retries_then_succeeds(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setattr("annotator.retry.time.sleep", lambda _: None)
        attempts = {"n": 0}

        def flaky() -> str:
            attempts["n"] += 1
            if attempts["n"] < 3:
                raise httpx.ConnectError("refused")
            return "ok"

        assert with_retry(flaky, base_wait=0) == "ok"
        assert attempts["n"] == 3

    def test_permanent_error_is_not_retried(self) -> None:
        attempts = {"n": 0}

        def always_bad() -> str:
            attempts["n"] += 1
            raise ValueError("bad input")

        with pytest.raises(ValueError):
            with_retry(always_bad, base_wait=0)
        assert attempts["n"] == 1, "a non-transient error must fail immediately"

    def test_gives_up_after_the_last_attempt(
        self, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        monkeypatch.setattr("annotator.retry.time.sleep", lambda _: None)
        attempts = {"n": 0}

        def always_flaky() -> str:
            attempts["n"] += 1
            raise httpx.ConnectError("refused")

        with pytest.raises(httpx.ConnectError):
            with_retry(always_flaky, tries=3, base_wait=0)
        assert attempts["n"] == 3


class TestPrompts:
    def test_loads_and_formats(self) -> None:
        text = prompts.load("annotate_clip", rally_num=7, duration=12.4)
        assert "rally #7" in text
        assert "approx. 12s" in text

    def test_loads_without_placeholders(self) -> None:
        assert "VISUAL SIGNALS" in prompts.load("rally_timestamps")

    def test_unknown_prompt_raises(self) -> None:
        with pytest.raises(FileNotFoundError):
            prompts.load("does_not_exist")
