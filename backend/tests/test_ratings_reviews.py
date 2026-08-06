"""Sections 5.13–5.15 — star ratings, their distribution, reviews and spoilers."""

from __future__ import annotations

from httpx import AsyncClient

from tests.conftest import auth_headers, register
from tests.fakes import MATRIX_ID

RATING_URL = f"/api/v1/titles/{MATRIX_ID}/rating"
REVIEW_URL = f"/api/v1/titles/{MATRIX_ID}/reviews"


async def test_rate_edit_and_delete(client: AsyncClient, user_headers: dict) -> None:
    """Section 5.13 — one to five stars, editable."""
    created = await client.post(RATING_URL, json={"score": 4}, headers=user_headers)
    assert created.status_code == 200
    assert created.json()["score"] == 4

    edited = await client.post(RATING_URL, json={"score": 5}, headers=user_headers)
    assert edited.json()["score"] == 5

    summary = (await client.get(f"/api/v1/titles/{MATRIX_ID}")).json()
    assert summary["user_rating_count"] == 1
    assert summary["user_rating_average"] == 5.0

    deleted = await client.delete(RATING_URL, headers=user_headers)
    assert deleted.status_code == 204
    assert (await client.get(f"/api/v1/titles/{MATRIX_ID}")).json()["user_rating_count"] == 0


async def test_rating_bounds(client: AsyncClient, user_headers: dict) -> None:
    for score in (0, 6, -1):
        response = await client.post(RATING_URL, json={"score": score}, headers=user_headers)
        assert response.status_code == 422
        assert response.json()["error"]["code"] == "VALIDATION_ERROR"


async def test_rating_requires_auth(client: AsyncClient) -> None:
    assert (await client.post(RATING_URL, json={"score": 3})).status_code == 401


async def test_rating_distribution_is_percentages(client: AsyncClient, user_headers: dict) -> None:
    """Section 5.13 — «درصد تعداد ستاره‌ها برای هر درجه کیفی از ۰ تا ۱۰۰»."""
    await client.post(RATING_URL, json={"score": 5}, headers=user_headers)
    for index in range(3):
        other = await register(
            client, username=f"user{index}", email=f"user{index}@example.com"
        )
        score = 5 if index == 0 else 3
        await client.post(RATING_URL, json={"score": score}, headers=auth_headers(other))

    body = (await client.get(f"/api/v1/titles/{MATRIX_ID}")).json()
    distribution = {row["score"]: row for row in body["rating_distribution"]}

    assert [row["score"] for row in body["rating_distribution"]] == [1, 2, 3, 4, 5]
    assert distribution[5]["count"] == 2
    assert distribution[3]["count"] == 2
    assert distribution[5]["percent"] == 50
    assert distribution[1]["percent"] == 0
    assert sum(row["percent"] for row in body["rating_distribution"]) == 100
    assert body["user_rating_count"] == 4


async def test_write_and_edit_a_review(client: AsyncClient, user_headers: dict) -> None:
    """Section 5.14 — each review carries its author, avatar, date and spoiler flag."""
    created = await client.post(
        REVIEW_URL,
        json={"text": "فیلم فوق‌العاده‌ای بود.", "has_spoiler": False},
        headers=user_headers,
    )
    assert created.status_code == 201
    body = created.json()
    assert body["text"] == "فیلم فوق‌العاده‌ای بود."
    assert body["has_spoiler"] is False
    assert body["user"]["username"] == "arian"
    assert "avatar_url" in body["user"]
    assert body["created_at"]

    listed = (await client.get(REVIEW_URL)).json()
    assert listed["total"] == 1
    assert listed["items"][0]["text"] == "فیلم فوق‌العاده‌ای بود."

    # Section 8.4: posting again edits, it does not duplicate.
    again = await client.post(
        REVIEW_URL, json={"text": "بعد از تماشای دوباره، بهتر هم شد."}, headers=user_headers
    )
    assert again.status_code == 201
    listed = (await client.get(REVIEW_URL)).json()
    assert listed["total"] == 1
    assert listed["items"][0]["text"] == "بعد از تماشای دوباره، بهتر هم شد."


async def test_review_validation_and_auth(client: AsyncClient, user_headers: dict) -> None:
    assert (await client.post(REVIEW_URL, json={"text": "..."})).status_code == 401

    empty = await client.post(REVIEW_URL, json={"text": "   "}, headers=user_headers)
    assert empty.status_code == 422
    assert empty.json()["error"]["code"] == "VALIDATION_ERROR"


async def test_spoiler_flag_is_reported(client: AsyncClient, user_headers: dict) -> None:
    """Section 5.15 — spoilers are flagged so the app can hide them first."""
    await client.post(
        REVIEW_URL,
        json={"text": "آخرش همه چیز لو می‌رود!", "has_spoiler": True},
        headers=user_headers,
    )

    listed = (await client.get(REVIEW_URL)).json()
    assert listed["items"][0]["has_spoiler"] is True

    without_spoilers = (await client.get(REVIEW_URL, params={"hide_spoilers": True})).json()
    assert without_spoilers["items"] == []
    assert without_spoilers["hidden_spoilers"] == 1


async def test_delete_own_review_only(client: AsyncClient, user_headers: dict) -> None:
    created = await client.post(REVIEW_URL, json={"text": "نظر من"}, headers=user_headers)
    review_id = created.json()["id"]

    stranger = await register(client, username="mallory", email="mallory@example.com")
    forbidden = await client.delete(
        f"/api/v1/reviews/{review_id}", headers=auth_headers(stranger)
    )
    assert forbidden.status_code == 403

    mine = await client.delete(f"/api/v1/reviews/{review_id}", headers=user_headers)
    assert mine.status_code == 204
    assert (await client.get(REVIEW_URL)).json()["total"] == 0


async def test_my_review_comes_back_with_the_title(
    client: AsyncClient, user_headers: dict
) -> None:
    await client.post(REVIEW_URL, json={"text": "یادداشت شخصی"}, headers=user_headers)
    body = (await client.get(f"/api/v1/titles/{MATRIX_ID}", headers=user_headers)).json()
    assert body["my_review"]["text"] == "یادداشت شخصی"


async def test_report_an_inappropriate_review(client: AsyncClient, user_headers: dict) -> None:
    author = await register(client, username="author", email="author@example.com")
    created = await client.post(
        REVIEW_URL, json={"text": "توهین‌آمیز"}, headers=auth_headers(author)
    )
    review_id = created.json()["id"]

    reported = await client.post(
        "/api/v1/reports",
        json={"review_id": review_id, "reason": "محتوای نامناسب"},
        headers=user_headers,
    )
    assert reported.status_code == 201
    assert reported.json()["status"] == "pending"
