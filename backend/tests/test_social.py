"""Section 13 bonus features — following, activity feed and per-title chat."""

from __future__ import annotations

from httpx import AsyncClient

from tests.conftest import auth_headers, register
from tests.fakes import MATRIX_ID


async def test_follow_and_unfollow(client: AsyncClient, user_headers: dict) -> None:
    await register(client, username="friend", email="friend@example.com")

    followed = await client.put("/api/v1/users/friend/follow", headers=user_headers)
    assert followed.status_code == 200
    assert followed.json()["is_following"] is True

    profile = (await client.get("/api/v1/users/friend", headers=user_headers)).json()
    assert profile["followers"] == 1
    assert profile["is_following"] is True

    unfollowed = await client.delete("/api/v1/users/friend/follow", headers=user_headers)
    assert unfollowed.json()["is_following"] is False


async def test_cannot_follow_yourself(client: AsyncClient, user_headers: dict) -> None:
    response = await client.put("/api/v1/users/arian/follow", headers=user_headers)
    assert response.status_code == 400
    assert response.json()["error"]["code"] == "CANNOT_FOLLOW_SELF"


async def test_feed_shows_activity_of_people_you_follow(
    client: AsyncClient, user_headers: dict
) -> None:
    friend = await register(client, username="cinephile", email="cine@example.com")
    await client.put("/api/v1/users/cinephile/follow", headers=user_headers)

    await client.post(
        f"/api/v1/titles/{MATRIX_ID}/rating", json={"score": 5}, headers=auth_headers(friend)
    )
    await client.post(
        f"/api/v1/titles/{MATRIX_ID}/reviews",
        json={"text": "شاهکار"},
        headers=auth_headers(friend),
    )

    feed = (await client.get("/api/v1/feed", headers=user_headers)).json()
    types = {item["type"] for item in feed["items"]}
    assert {"rated", "reviewed"} <= types
    assert feed["items"][0]["user"]["username"] == "cinephile"
    assert feed["items"][0]["title"]["imdb_id"] == MATRIX_ID


async def test_feed_is_empty_without_follows(client: AsyncClient, user_headers: dict) -> None:
    assert (await client.get("/api/v1/feed", headers=user_headers)).json()["items"] == []


async def test_title_chat_history(client: AsyncClient, user_headers: dict) -> None:
    posted = await client.post(
        f"/api/v1/titles/{MATRIX_ID}/chat",
        json={"text": "کسی نظر دومش رو داره؟"},
        headers=user_headers,
    )
    assert posted.status_code == 201
    assert posted.json()["user"]["username"] == "arian"

    history = (await client.get(f"/api/v1/titles/{MATRIX_ID}/chat")).json()
    assert history["items"][0]["text"] == "کسی نظر دومش رو داره؟"


async def test_chat_needs_auth_and_text(client: AsyncClient, user_headers: dict) -> None:
    assert (
        await client.post(f"/api/v1/titles/{MATRIX_ID}/chat", json={"text": "سلام"})
    ).status_code == 401
    assert (
        await client.post(
            f"/api/v1/titles/{MATRIX_ID}/chat", json={"text": "  "}, headers=user_headers
        )
    ).status_code == 422


def test_chat_websocket_broadcasts(fake_imdb) -> None:
    """The live room is a WebSocket; REST is only the history fallback."""
    from fastapi.testclient import TestClient

    from app.main import app

    with TestClient(app) as http:
        registered = http.post(
            "/api/v1/auth/register",
            json={
                "full_name": "چت‌کننده",
                "username": "chatter",
                "email": "chatter@example.com",
                "password": "Str0ngPass!",
            },
        )
        token = registered.json()["access_token"]

        with http.websocket_connect(
            f"/api/v1/titles/{MATRIX_ID}/chat/ws?token={token}"
        ) as socket:
            socket.send_json({"text": "سلام به همه"})
            message = socket.receive_json()
            assert message["text"] == "سلام به همه"
            assert message["user"]["username"] == "chatter"
