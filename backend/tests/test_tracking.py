"""Sections 5.9–5.12, 5.16 — watch status, episode marks, progress, watchlist."""

from __future__ import annotations

from httpx import AsyncClient

from tests.fakes import BREAKING_BAD_ID, MATRIX_ID

ONGOING_ID = "tt5555555"


async def _mark(client: AsyncClient, headers: dict, series: str, episode: str) -> None:
    response = await client.put(
        f"/api/v1/titles/{series}/episodes/{episode}/watch", headers=headers
    )
    assert response.status_code == 200, response.text


async def _progress(client: AsyncClient, headers: dict, series: str) -> dict:
    response = await client.get(f"/api/v1/titles/{series}/progress", headers=headers)
    assert response.status_code == 200
    return response.json()


async def test_set_and_clear_watch_status(client: AsyncClient, user_headers: dict) -> None:
    """Section 5.9 — the six states a title can be in."""
    for status in ("plan_to_watch", "watching", "watched", "paused", "dropped"):
        response = await client.put(
            f"/api/v1/titles/{MATRIX_ID}/status", json={"status": status}, headers=user_headers
        )
        assert response.status_code == 200
        assert response.json()["status"] == status

    cleared = await client.delete(f"/api/v1/titles/{MATRIX_ID}/status", headers=user_headers)
    assert cleared.status_code == 204

    body = (await client.get(f"/api/v1/titles/{MATRIX_ID}", headers=user_headers)).json()
    assert body["my_status"] is None


async def test_status_requires_auth_and_validates(client: AsyncClient, user_headers: dict) -> None:
    anonymous = await client.put(
        f"/api/v1/titles/{MATRIX_ID}/status", json={"status": "watching"}
    )
    assert anonymous.status_code == 401

    invalid = await client.put(
        f"/api/v1/titles/{MATRIX_ID}/status", json={"status": "sleeping"}, headers=user_headers
    )
    assert invalid.status_code == 422


async def test_setting_the_same_status_twice_is_idempotent(
    client: AsyncClient, user_headers: dict
) -> None:
    """Section 8.4 — «ثبت وضعیت تماشا نباید ناخواسته تکرار شود»."""
    for _ in range(3):
        await client.put(
            f"/api/v1/titles/{MATRIX_ID}/status",
            json={"status": "watching"},
            headers=user_headers,
        )

    watchlist = (await client.get("/api/v1/watchlist", headers=user_headers)).json()
    matching = [i for i in watchlist["items"] if i["imdb_id"] == MATRIX_ID]
    assert len(matching) == 1


async def test_favorites(client: AsyncClient, user_headers: dict) -> None:
    """Section 5.16 — a separate favourites list, independent of watch status."""
    added = await client.put(f"/api/v1/titles/{MATRIX_ID}/favorite", headers=user_headers)
    assert added.status_code == 200
    assert added.json()["is_favorite"] is True

    favorites = (await client.get("/api/v1/watchlist/favorites", headers=user_headers)).json()
    assert [i["imdb_id"] for i in favorites["items"]] == [MATRIX_ID]

    removed = await client.delete(f"/api/v1/titles/{MATRIX_ID}/favorite", headers=user_headers)
    assert removed.status_code == 200
    assert removed.json()["is_favorite"] is False
    empty = (await client.get("/api/v1/watchlist/favorites", headers=user_headers)).json()
    assert empty["items"] == []


async def test_watchlist_is_grouped_by_status(client: AsyncClient, user_headers: dict) -> None:
    """Section 5.12 — the four sections of the watch list."""
    await client.put(
        f"/api/v1/titles/{MATRIX_ID}/status", json={"status": "watching"}, headers=user_headers
    )
    await client.put(
        f"/api/v1/titles/{BREAKING_BAD_ID}/status",
        json={"status": "plan_to_watch"},
        headers=user_headers,
    )

    everything = (await client.get("/api/v1/watchlist", headers=user_headers)).json()
    assert everything["counts"]["watching"] == 1
    assert everything["counts"]["plan_to_watch"] == 1

    only_watching = (
        await client.get("/api/v1/watchlist", params={"status": "watching"}, headers=user_headers)
    ).json()
    assert [i["imdb_id"] for i in only_watching["items"]] == [MATRIX_ID]
    assert only_watching["items"][0]["title"] == "The Matrix"


async def test_episode_marks_and_unmarks(client: AsyncClient, user_headers: dict) -> None:
    """Section 5.10 — mark episodes, and count what is left."""
    await client.get(f"/api/v1/titles/{BREAKING_BAD_ID}/seasons/1/episodes")
    await _mark(client, user_headers, BREAKING_BAD_ID, "tt0959621")

    episodes = (
        await client.get(
            f"/api/v1/titles/{BREAKING_BAD_ID}/seasons/1/episodes", headers=user_headers
        )
    ).json()
    assert episodes[0]["is_watched"] is True
    assert episodes[1]["is_watched"] is False

    progress = await _progress(client, user_headers, BREAKING_BAD_ID)
    assert progress["watched_episodes"] == 1
    assert progress["remaining_episodes"] == 4

    unmarked = await client.delete(
        f"/api/v1/titles/{BREAKING_BAD_ID}/episodes/tt0959621/watch", headers=user_headers
    )
    assert unmarked.status_code == 200
    assert (await _progress(client, user_headers, BREAKING_BAD_ID))["watched_episodes"] == 0


async def test_marking_an_episode_twice_counts_once(
    client: AsyncClient, user_headers: dict
) -> None:
    await client.get(f"/api/v1/titles/{BREAKING_BAD_ID}/seasons/1/episodes")
    await _mark(client, user_headers, BREAKING_BAD_ID, "tt0959621")
    await _mark(client, user_headers, BREAKING_BAD_ID, "tt0959621")

    assert (await _progress(client, user_headers, BREAKING_BAD_ID))["watched_episodes"] == 1


async def test_season_bulk_mark(client: AsyncClient, user_headers: dict) -> None:
    response = await client.put(
        f"/api/v1/titles/{BREAKING_BAD_ID}/seasons/1/watch", headers=user_headers
    )
    assert response.status_code == 200
    assert response.json()["watched_episodes"] == 3

    cleared = await client.delete(
        f"/api/v1/titles/{BREAKING_BAD_ID}/seasons/1/watch", headers=user_headers
    )
    assert cleared.json()["watched_episodes"] == 0


async def test_progress_percentage_and_colors(client: AsyncClient, user_headers: dict) -> None:
    """Section 5.11 — percentage plus the colour coding of the progress bar."""
    nothing = await _progress(client, user_headers, BREAKING_BAD_ID)
    assert nothing["total_episodes"] == 5
    assert nothing["percent"] == 0
    assert nothing["color"] == "none"

    await client.put(f"/api/v1/titles/{BREAKING_BAD_ID}/seasons/1/watch", headers=user_headers)
    partial = await _progress(client, user_headers, BREAKING_BAD_ID)
    assert partial["watched_episodes"] == 3
    assert partial["percent"] == 60
    assert partial["color"] == "yellow"

    await client.put(
        f"/api/v1/titles/{BREAKING_BAD_ID}/status", json={"status": "paused"}, headers=user_headers
    )
    paused = await _progress(client, user_headers, BREAKING_BAD_ID)
    assert paused["color"] == "red"

    await client.put(f"/api/v1/titles/{BREAKING_BAD_ID}/seasons/2/watch", headers=user_headers)
    finished = await _progress(client, user_headers, BREAKING_BAD_ID)
    assert finished["percent"] == 100
    # Ended series, everything seen → purple.
    assert finished["color"] == "purple"


async def test_ongoing_series_finished_is_green(client: AsyncClient, user_headers: dict) -> None:
    await client.put(f"/api/v1/titles/{ONGOING_ID}/seasons/1/watch", headers=user_headers)
    progress = await _progress(client, user_headers, ONGOING_ID)
    assert progress["percent"] == 100
    assert progress["is_ongoing"] is True
    assert progress["color"] == "green"


async def test_finishing_every_episode_sets_status_watched(
    client: AsyncClient, user_headers: dict
) -> None:
    await client.put(f"/api/v1/titles/{ONGOING_ID}/seasons/1/watch", headers=user_headers)
    body = (await client.get(f"/api/v1/titles/{ONGOING_ID}", headers=user_headers)).json()
    assert body["my_status"] == "watched"


async def test_progress_of_a_movie_uses_status(client: AsyncClient, user_headers: dict) -> None:
    await client.put(
        f"/api/v1/titles/{MATRIX_ID}/status", json={"status": "watched"}, headers=user_headers
    )
    progress = await _progress(client, user_headers, MATRIX_ID)
    assert progress["total_episodes"] == 0
    assert progress["percent"] == 100
    assert progress["color"] == "purple"


async def test_title_detail_embeds_progress(client: AsyncClient, user_headers: dict) -> None:
    await client.put(f"/api/v1/titles/{BREAKING_BAD_ID}/seasons/1/watch", headers=user_headers)
    body = (await client.get(f"/api/v1/titles/{BREAKING_BAD_ID}", headers=user_headers)).json()
    assert body["progress"]["percent"] == 60
    assert body["progress"]["color"] == "yellow"


async def test_progress_is_not_fooled_by_a_half_mirrored_series(
    client, user_headers, fake_imdb
):
    """Marking one season of a five-season show is not «۱۰۰٪» (section 5.11)."""
    from sqlalchemy import delete

    from app.db.base import SessionLocal
    from app.db.models import Episode

    # Pull season 1 only, then mark it watched.
    await client.get(f"/api/v1/titles/{BREAKING_BAD_ID}/seasons/1/episodes")
    await client.put(
        f"/api/v1/titles/{BREAKING_BAD_ID}/seasons/1/watch", headers=user_headers
    )

    # Simulate an evicted mirror: the freshness stamp survives, the rows do not.
    async with SessionLocal() as db:
        await db.execute(
            delete(Episode).where(
                Episode.series_id == BREAKING_BAD_ID, Episode.season_number != 1
            )
        )
        await db.commit()

    response = await client.get(
        f"/api/v1/titles/{BREAKING_BAD_ID}/progress", headers=user_headers
    )
    assert response.status_code == 200
    body = response.json()
    assert body["total_episodes"] > body["watched_episodes"]
    assert body["percent"] < 100
    assert body["color"] != "purple"
