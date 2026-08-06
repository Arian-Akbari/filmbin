"""Unit tests for the pieces that have no HTTP surface."""

from __future__ import annotations

import pytest

from app.core.errors import AppError, NotFoundError
from app.core.security import (
    create_access_token,
    decode_access_token,
    hash_password,
    hash_token,
    verify_password,
)
from app.imdb.client import CircuitBreaker
from app.imdb.mapper import map_episode, map_name, map_title_card, map_title_details, sized_image
from app.services.progress import progress_color
from tests.fakes import BREAKING_BAD_DETAILS, BREAKING_BAD_ID, EPISODES, MATRIX_CARD, NAMES


# --------------------------------------------------------------------------
# security
# --------------------------------------------------------------------------


def test_passwords_are_hashed_not_stored() -> None:
    """Section 8.3 — «رمزهای عبور نباید به صورت متن ساده ذخیره شوند»."""
    digest = hash_password("Str0ngPass!")
    assert digest != "Str0ngPass!"
    assert digest.startswith("$2")
    assert verify_password("Str0ngPass!", digest)
    assert not verify_password("wrong", digest)


def test_two_hashes_of_the_same_password_differ() -> None:
    assert hash_password("same") != hash_password("same")


def test_long_passwords_do_not_break_bcrypt() -> None:
    long_password = "ب" * 200
    digest = hash_password(long_password)
    assert verify_password(long_password, digest)


def test_access_token_roundtrip() -> None:
    token, expires_at = create_access_token(7, "admin")
    payload = decode_access_token(token)
    assert payload["sub"] == "7"
    assert payload["role"] == "admin"
    assert expires_at is not None


def test_tampered_token_is_rejected() -> None:
    token, _ = create_access_token(1, "user")
    with pytest.raises(AppError):
        decode_access_token(token[:-2] + "xy")


def test_refresh_tokens_are_stored_as_digests() -> None:
    assert hash_token("abc") == hash_token("abc")
    assert len(hash_token("abc")) == 64
    assert hash_token("abc") != "abc"


# --------------------------------------------------------------------------
# IMDb mapping
# --------------------------------------------------------------------------


def test_image_urls_are_resized_for_mobile() -> None:
    """Sections 8.1 / 8.8 — never ship a 2100px poster to a phone."""
    original = "https://m.media-amazon.com/images/M/MV5BOWE4._V1_.jpg"
    assert sized_image(original, 300) == (
        "https://m.media-amazon.com/images/M/MV5BOWE4._V1_QL75_UX300_.jpg"
    )
    assert sized_image(None, 300) is None
    assert sized_image("https://example.com/plain.png", 300) == "https://example.com/plain.png"


def test_map_title_card() -> None:
    mapped = map_title_card(MATRIX_CARD)
    assert mapped["imdb_id"] == "tt0133093"
    assert mapped["kind"] == "movie"
    assert mapped["runtime_minutes"] == 136
    assert mapped["genres"] == ["Action", "Sci-Fi"]
    assert mapped["imdb_rating"] == 8.7


def test_map_title_details_keeps_only_cast_members() -> None:
    mapped = map_title_details(BREAKING_BAD_DETAILS)
    assert mapped["kind"] == "series"
    assert mapped["directors"] == ["Vince Gilligan"]
    assert [c["name"] for c in mapped["cast"]] == ["Bryan Cranston", "Anna Gunn"]
    assert mapped["season_count"] == 2
    assert mapped["episode_count"] == 5
    assert mapped["seasons"] == [1, 2]
    assert mapped["has_details"] is True


def test_map_episode() -> None:
    mapped = map_episode(EPISODES[BREAKING_BAD_ID][1][0], BREAKING_BAD_ID)
    assert mapped["imdb_id"] == "tt0959621"
    assert mapped["season_number"] == 1
    assert mapped["episode_number"] == 1
    assert mapped["air_date"] == "2008-01-20"
    assert mapped["runtime_minutes"] == 58


def test_map_episode_without_numbering_is_skipped() -> None:
    assert map_episode({"id": "tt1", "series": {}}, "tt0") is None


def test_map_name() -> None:
    assert map_name(NAMES[0])["name"] == "Bryan Cranston"
    assert map_name({}) is None


# --------------------------------------------------------------------------
# progress colours (section 5.11)
# --------------------------------------------------------------------------


@pytest.mark.parametrize(
    ("watched", "total", "status", "ongoing", "expected"),
    [
        (0, 10, None, False, "none"),
        (0, 10, "plan_to_watch", False, "none"),
        (3, 10, "watching", False, "yellow"),
        (3, 10, "paused", False, "red"),
        (3, 10, "dropped", False, "red"),
        (0, 10, "dropped", False, "red"),
        (10, 10, "watched", False, "purple"),
        (10, 10, "watching", True, "green"),
        (0, 0, "watched", False, "purple"),
        (0, 0, None, False, "none"),
    ],
)
def test_progress_color(
    watched: int, total: int, status: str | None, ongoing: bool, expected: str
) -> None:
    assert progress_color(watched, total, status, ongoing) == expected


# --------------------------------------------------------------------------
# resilience
# --------------------------------------------------------------------------


def test_circuit_breaker_opens_then_recovers() -> None:
    """Section 8.4 — repeated IMDb failures must stop being retried."""
    breaker = CircuitBreaker(threshold=3, cooldown=0.05)

    for _ in range(2):
        breaker.record_failure()
    assert not breaker.is_open

    breaker.record_failure()
    assert breaker.is_open

    import time

    time.sleep(0.06)
    assert not breaker.is_open  # half-open again

    breaker.record_success()
    assert breaker.failures == 0


def test_error_payload_shape() -> None:
    """Section 7.9 — status code, code, message and extra detail."""
    payload = NotFoundError(detail="tt1", fields={"id": "نامعتبر"}).to_payload()
    assert payload["error"]["status"] == 404
    assert payload["error"]["code"] == "NOT_FOUND"
    assert payload["error"]["message"]
    assert payload["error"]["detail"] == "tt1"
    assert payload["error"]["fields"] == {"id": "نامعتبر"}
