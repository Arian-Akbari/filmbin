"""Sections 5.5–5.8, 5.18, 5.20, 7.3, 7.5 — everything that comes from IMDb."""

from __future__ import annotations

import pytest
from httpx import AsyncClient

from app.core.errors import UpstreamUnavailableError
from tests.fakes import BREAKING_BAD_ID, MATRIX_ID, FakeImdb

SEARCH = "/api/v1/titles/search"


async def test_guest_can_search_by_title(client: AsyncClient) -> None:
    """Section 4.1 — searching works without signing in."""
    response = await client.get(SEARCH, params={"q": "matrix"})
    assert response.status_code == 200
    body = response.json()
    assert body["total"] >= 1
    first = body["items"][0]
    assert first["imdb_id"] == MATRIX_ID
    assert first["title"] == "The Matrix"
    assert first["year"] == 1999
    assert first["poster_url"] and first["poster_thumb_url"]
    assert "Action" in first["genres"]


async def test_search_results_are_cached(client: AsyncClient, fake_imdb: FakeImdb) -> None:
    """Section 8.1 / 8.8 — the same query must not hit IMDb twice."""
    await client.get(SEARCH, params={"q": "matrix"})
    calls_after_first = len([c for c in fake_imdb.calls if c[0] == "SearchTitles"])

    await client.get(SEARCH, params={"q": "matrix"})
    calls_after_second = len([c for c in fake_imdb.calls if c[0] == "SearchTitles"])

    assert calls_after_first == 1
    assert calls_after_second == 1


async def test_search_filters(client: AsyncClient) -> None:
    """Section 5.5 — filter by type, genre and release year."""
    series_only = await client.get(SEARCH, params={"kind": "series"})
    kinds = {item["kind"] for item in series_only.json()["items"]}
    assert kinds == {"series"}

    by_genre = await client.get(SEARCH, params={"genre": "Crime"})
    assert any(i["imdb_id"] == BREAKING_BAD_ID for i in by_genre.json()["items"])

    by_year = await client.get(SEARCH, params={"year_from": 2000, "year_to": 2010})
    assert by_year.status_code == 200


async def test_search_by_person(client: AsyncClient, fake_imdb: FakeImdb) -> None:
    """Section 5.5 — searching an actor/director resolves the name first."""
    response = await client.get(SEARCH, params={"person": "bryan cranston"})
    assert response.status_code == 200
    operations = [c[0] for c in fake_imdb.calls]
    assert "SearchNames" in operations
    constraints = [c[1]["constraints"] for c in fake_imdb.calls if c[0] == "SearchTitles"]
    assert constraints and "creditedNameConstraint" in constraints[0]


async def test_people_suggestions(client: AsyncClient) -> None:
    response = await client.get("/api/v1/titles/people", params={"q": "bryan"})
    assert response.status_code == 200
    assert response.json()[0]["name"] == "Bryan Cranston"


async def test_movie_details(client: AsyncClient) -> None:
    """Section 5.6 — every field the movie page has to show."""
    response = await client.get(f"/api/v1/titles/{MATRIX_ID}")
    assert response.status_code == 200
    body = response.json()

    assert body["imdb_id"] == MATRIX_ID
    assert body["kind"] == "movie"
    assert body["title"] == "The Matrix"
    assert body["original_title"] == "The Matrix"
    assert body["poster_url"]
    assert body["plot"]
    assert body["year"] == 1999
    assert body["runtime_minutes"] == 136
    assert body["genres"]
    assert body["countries"] == ["United States"]
    assert body["directors"] == ["Vince Gilligan"]
    assert [c["name"] for c in body["cast"]] == ["Bryan Cranston", "Anna Gunn"]
    assert body["cast"][0]["characters"] == ["Walter White"]
    assert body["imdb_rating"] == 8.7
    assert body["user_rating_average"] is None
    assert body["user_rating_count"] == 0


async def test_series_details(client: AsyncClient) -> None:
    """Section 5.7 — series-specific fields."""
    body = (await client.get(f"/api/v1/titles/{BREAKING_BAD_ID}")).json()

    assert body["kind"] == "series"
    assert body["year"] == 2008
    assert body["end_year"] == 2013
    assert body["season_count"] == 2
    assert body["episode_count"] == 5
    assert body["is_ongoing"] is False
    assert body["status_label"] == "پایان‌یافته"
    assert [s["number"] for s in body["seasons"]] == [1, 2]


async def test_details_are_cached(client: AsyncClient, fake_imdb: FakeImdb) -> None:
    await client.get(f"/api/v1/titles/{MATRIX_ID}")
    await client.get(f"/api/v1/titles/{MATRIX_ID}")
    assert len([c for c in fake_imdb.calls if c[0] == "TitleDetails"]) == 1


async def test_unknown_title_returns_typed_error(client: AsyncClient) -> None:
    """Section 5.20 — «فیلم یا سریال موردنظر پیدا نشد»."""
    response = await client.get("/api/v1/titles/tt0000000")
    assert response.status_code == 404
    error = response.json()["error"]
    assert error["code"] == "TITLE_NOT_FOUND"
    assert error["message"]


async def test_seasons_and_episodes(client: AsyncClient) -> None:
    """Section 5.8 — season list and per-episode fields."""
    seasons = await client.get(f"/api/v1/titles/{BREAKING_BAD_ID}/seasons")
    assert [s["number"] for s in seasons.json()] == [1, 2]

    episodes = await client.get(f"/api/v1/titles/{BREAKING_BAD_ID}/seasons/1/episodes")
    assert episodes.status_code == 200
    items = episodes.json()
    assert len(items) == 3
    first = items[0]
    assert first["season_number"] == 1
    assert first["episode_number"] == 1
    assert first["title"] == "Pilot"
    assert first["air_date"] == "2008-01-20"
    assert first["runtime_minutes"] == 58
    assert first["plot"]
    assert first["is_watched"] is False


async def test_episodes_are_mirrored_locally(client: AsyncClient, fake_imdb: FakeImdb) -> None:
    """Section 7.5 — a second read of the same season stays on our own database."""
    await client.get(f"/api/v1/titles/{BREAKING_BAD_ID}/seasons/1/episodes")
    await client.get(f"/api/v1/titles/{BREAKING_BAD_ID}/seasons/1/episodes")
    assert len([c for c in fake_imdb.calls if c[0] == "SeasonEpisodes"]) == 1


async def test_home_sections(client: AsyncClient) -> None:
    """Section 5.18 — the rails on the main screen."""
    response = await client.get("/api/v1/titles/discover")
    assert response.status_code == 200
    sections = {s["key"]: s for s in response.json()["sections"]}
    for key in ("popular_movies", "popular_series", "new_releases", "top_rated"):
        assert key in sections
        assert sections[key]["title"]
    assert sections["popular_movies"]["items"]


async def test_recommendations_follow_taste(client: AsyncClient, user_headers: dict) -> None:
    """Section 5.18 — «فیلم‌ها و سریال‌های پیشنهادی» for a signed-in user."""
    await client.put(f"/api/v1/titles/{BREAKING_BAD_ID}/favorite", headers=user_headers)

    response = await client.get("/api/v1/titles/recommended", headers=user_headers)
    assert response.status_code == 200
    body = response.json()
    assert "items" in body
    assert body["based_on"]


async def test_upstream_failure_serves_cache_then_errors(
    client: AsyncClient, fake_imdb: FakeImdb
) -> None:
    """Section 8.4 — an IMDb outage must not take the backend down."""
    await client.get(f"/api/v1/titles/{MATRIX_ID}")  # warm the mirror

    fake_imdb.fail_with = UpstreamUnavailableError()

    cached = await client.get(f"/api/v1/titles/{MATRIX_ID}")
    assert cached.status_code == 200
    assert cached.json()["title"] == "The Matrix"

    cold = await client.get("/api/v1/titles/tt7777777")
    assert cold.status_code == 503
    error = cold.json()["error"]
    assert error["code"] == "UPSTREAM_UNAVAILABLE"
    assert error["message"]


async def test_signed_in_user_sees_own_state_on_a_title(
    client: AsyncClient, user_headers: dict
) -> None:
    await client.put(
        f"/api/v1/titles/{MATRIX_ID}/status", json={"status": "watching"}, headers=user_headers
    )
    await client.post(
        f"/api/v1/titles/{MATRIX_ID}/rating", json={"score": 4}, headers=user_headers
    )

    body = (await client.get(f"/api/v1/titles/{MATRIX_ID}", headers=user_headers)).json()
    assert body["my_status"] == "watching"
    assert body["my_rating"] == 4
    assert body["is_favorite"] is False

    as_guest = (await client.get(f"/api/v1/titles/{MATRIX_ID}")).json()
    assert as_guest["my_status"] is None
    assert as_guest["user_rating_average"] == 4.0


@pytest.mark.parametrize("path", ["/api/v1/titles/search?q=x", f"/api/v1/titles/{MATRIX_ID}"])
async def test_browsing_never_requires_auth(client: AsyncClient, path: str) -> None:
    assert (await client.get(path)).status_code == 200


async def test_season_list_backfills_after_a_partial_mirror(client, fake_imdb):
    """A deep link to one season must not leave the season list truncated."""
    # Only season 2 is touched first — the mirror now holds a single row.
    await client.get(f"/api/v1/titles/{BREAKING_BAD_ID}/seasons/2/episodes")

    response = await client.get(f"/api/v1/titles/{BREAKING_BAD_ID}/seasons")
    assert response.status_code == 200
    numbers = [season["number"] for season in response.json()]
    assert numbers == sorted(numbers)
    assert len(numbers) > 1, "the other seasons were never backfilled"
