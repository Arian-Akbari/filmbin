"""Sections 5.17 and 5.19 — personal lists and the activity dashboard."""

from __future__ import annotations

from httpx import AsyncClient

from tests.conftest import auth_headers, register
from tests.fakes import BREAKING_BAD_ID, MATRIX_ID

ONGOING_ID = "tt5555555"


# --------------------------------------------------------------------------
# 5.17 — personal lists
# --------------------------------------------------------------------------


async def test_create_list_and_manage_items(client: AsyncClient, user_headers: dict) -> None:
    created = await client.post(
        "/api/v1/lists",
        json={"name": "بهترین فیلم‌های اکشن", "description": "انتخاب شخصی"},
        headers=user_headers,
    )
    assert created.status_code == 201
    list_id = created.json()["id"]
    assert created.json()["item_count"] == 0

    added = await client.post(
        f"/api/v1/lists/{list_id}/items", json={"imdb_id": MATRIX_ID}, headers=user_headers
    )
    assert added.status_code == 201

    duplicate = await client.post(
        f"/api/v1/lists/{list_id}/items", json={"imdb_id": MATRIX_ID}, headers=user_headers
    )
    assert duplicate.status_code == 409

    detail = (await client.get(f"/api/v1/lists/{list_id}", headers=user_headers)).json()
    assert detail["item_count"] == 1
    assert detail["items"][0]["title"] == "The Matrix"

    removed = await client.delete(
        f"/api/v1/lists/{list_id}/items/{MATRIX_ID}", headers=user_headers
    )
    assert removed.status_code == 204
    assert (await client.get(f"/api/v1/lists/{list_id}", headers=user_headers)).json()[
        "item_count"
    ] == 0


async def test_rename_and_delete_list(client: AsyncClient, user_headers: dict) -> None:
    list_id = (
        await client.post("/api/v1/lists", json={"name": "موقت"}, headers=user_headers)
    ).json()["id"]

    renamed = await client.patch(
        f"/api/v1/lists/{list_id}",
        json={"name": "فیلم‌هایی که باید ببینم", "is_public": False},
        headers=user_headers,
    )
    assert renamed.json()["name"] == "فیلم‌هایی که باید ببینم"
    assert renamed.json()["is_public"] is False

    deleted = await client.delete(f"/api/v1/lists/{list_id}", headers=user_headers)
    assert deleted.status_code == 204
    assert (await client.get(f"/api/v1/lists/{list_id}", headers=user_headers)).status_code == 404


async def test_private_lists_stay_private(client: AsyncClient, user_headers: dict) -> None:
    private_id = (
        await client.post(
            "/api/v1/lists", json={"name": "خصوصی", "is_public": False}, headers=user_headers
        )
    ).json()["id"]
    public_id = (
        await client.post(
            "/api/v1/lists", json={"name": "عمومی", "is_public": True}, headers=user_headers
        )
    ).json()["id"]

    stranger = auth_headers(await register(client, username="nosy", email="nosy@example.com"))

    assert (await client.get(f"/api/v1/lists/{private_id}", headers=stranger)).status_code == 403
    assert (await client.get(f"/api/v1/lists/{public_id}", headers=stranger)).status_code == 200

    mine = (await client.get("/api/v1/lists", headers=user_headers)).json()
    assert len(mine) == 2
    theirs = (await client.get("/api/v1/lists", headers=stranger)).json()
    assert theirs == []


async def test_lists_require_a_name(client: AsyncClient, user_headers: dict) -> None:
    response = await client.post("/api/v1/lists", json={"name": " "}, headers=user_headers)
    assert response.status_code == 422


# --------------------------------------------------------------------------
# 5.19 — user statistics
# --------------------------------------------------------------------------


async def test_stats_dashboard(client: AsyncClient, user_headers: dict) -> None:
    await client.put(
        f"/api/v1/titles/{MATRIX_ID}/status", json={"status": "watched"}, headers=user_headers
    )
    await client.put(f"/api/v1/titles/{BREAKING_BAD_ID}/seasons/1/watch", headers=user_headers)
    await client.put(f"/api/v1/titles/{BREAKING_BAD_ID}/seasons/2/watch", headers=user_headers)
    await client.post(
        f"/api/v1/titles/{MATRIX_ID}/rating", json={"score": 5}, headers=user_headers
    )
    await client.post(
        f"/api/v1/titles/{BREAKING_BAD_ID}/rating", json={"score": 4}, headers=user_headers
    )
    await client.post(
        f"/api/v1/titles/{MATRIX_ID}/reviews", json={"text": "عالی"}, headers=user_headers
    )
    await client.put(f"/api/v1/titles/{MATRIX_ID}/favorite", headers=user_headers)

    stats = (await client.get("/api/v1/users/me/stats", headers=user_headers)).json()

    assert stats["watched_movies"] == 1
    assert stats["watched_series"] == 1
    assert stats["watched_episodes"] == 5
    # 136 minutes of film + 58+48+48+47+47 minutes of episodes.
    assert stats["total_watch_minutes"] == 136 + 58 + 48 + 48 + 47 + 47
    assert stats["total_watch_hours"] == round(stats["total_watch_minutes"] / 60, 1)
    assert stats["average_rating"] == 4.5
    assert stats["ratings_count"] == 2
    assert stats["reviews_count"] == 1
    assert stats["favorites_count"] == 1
    assert stats["status_breakdown"]["watched"] >= 1

    genres = {row["genre"]: row["count"] for row in stats["favorite_genres"]}
    assert genres["Crime"] == 1
    assert genres["Action"] == 1
    assert stats["top_genre"] in genres


async def test_stats_start_at_zero(client: AsyncClient, user_headers: dict) -> None:
    stats = (await client.get("/api/v1/users/me/stats", headers=user_headers)).json()
    assert stats["watched_movies"] == 0
    assert stats["total_watch_minutes"] == 0
    assert stats["average_rating"] is None
    assert stats["favorite_genres"] == []


async def test_stats_need_auth(client: AsyncClient) -> None:
    assert (await client.get("/api/v1/users/me/stats")).status_code == 401
