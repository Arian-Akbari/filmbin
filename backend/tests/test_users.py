"""Section 5.4 — profile viewing and editing, plus public profiles."""

from __future__ import annotations

import io

from httpx import AsyncClient

from tests.conftest import register
from tests.fakes import BREAKING_BAD_ID, MATRIX_ID


async def test_me_returns_own_profile(client: AsyncClient, user_headers: dict) -> None:
    response = await client.get("/api/v1/users/me", headers=user_headers)
    assert response.status_code == 200
    body = response.json()
    assert body["username"] == "arian"
    assert body["bio"] == "دانشجوی شریف"
    assert body["summary"]["watched_movies"] == 0


async def test_profile_counters_track_activity(client: AsyncClient, user_headers: dict) -> None:
    """Section 5.1 — watched films, followed series and favourites update themselves."""
    await client.put(
        f"/api/v1/titles/{MATRIX_ID}/status", json={"status": "watched"}, headers=user_headers
    )
    await client.put(
        f"/api/v1/titles/{BREAKING_BAD_ID}/status",
        json={"status": "watching"},
        headers=user_headers,
    )
    await client.put(f"/api/v1/titles/{MATRIX_ID}/favorite", headers=user_headers)

    summary = (await client.get("/api/v1/users/me", headers=user_headers)).json()["summary"]
    assert summary == {"watched_movies": 1, "followed_series": 1, "favorites": 1}


async def test_edit_profile(client: AsyncClient, user_headers: dict) -> None:
    response = await client.patch(
        "/api/v1/users/me",
        json={"full_name": "آرین ا.", "bio": "علاقه‌مند به سینما", "username": "arian_a"},
        headers=user_headers,
    )
    assert response.status_code == 200
    body = response.json()
    assert body["full_name"] == "آرین ا."
    assert body["username"] == "arian_a"
    assert body["bio"] == "علاقه‌مند به سینما"


async def test_username_conflict_on_edit(client: AsyncClient, user_headers: dict) -> None:
    await register(client, username="taken", email="taken@example.com")

    response = await client.patch(
        "/api/v1/users/me", json={"username": "taken"}, headers=user_headers
    )
    assert response.status_code == 409
    assert response.json()["error"]["code"] == "USERNAME_TAKEN"


async def test_change_password(client: AsyncClient, user_headers: dict) -> None:
    wrong = await client.post(
        "/api/v1/users/me/password",
        json={"current_password": "nope", "new_password": "Fresh1Pass!"},
        headers=user_headers,
    )
    assert wrong.status_code == 401

    ok = await client.post(
        "/api/v1/users/me/password",
        json={"current_password": "Str0ngPass!", "new_password": "Fresh1Pass!"},
        headers=user_headers,
    )
    assert ok.status_code == 204

    login = await client.post(
        "/api/v1/auth/login",
        json={"email": "arian@example.com", "password": "Fresh1Pass!"},
    )
    assert login.status_code == 200


async def test_avatar_upload(client: AsyncClient, user_headers: dict) -> None:
    png = (
        b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01"
        b"\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\x9cc\x00\x01"
        b"\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82"
    )
    response = await client.post(
        "/api/v1/users/me/avatar",
        files={"file": ("avatar.png", io.BytesIO(png), "image/png")},
        headers=user_headers,
    )
    assert response.status_code == 200
    assert response.json()["avatar_url"].endswith(".png")

    rejected = await client.post(
        "/api/v1/users/me/avatar",
        files={"file": ("notes.txt", io.BytesIO(b"hello"), "text/plain")},
        headers=user_headers,
    )
    assert rejected.status_code == 422
    assert rejected.json()["error"]["code"] == "UNSUPPORTED_IMAGE"


async def test_public_profile_hides_email(client: AsyncClient, user_headers: dict) -> None:
    await register(client, username="viewer", email="viewer@example.com")

    response = await client.get("/api/v1/users/arian")
    assert response.status_code == 200
    body = response.json()
    assert body["username"] == "arian"
    assert "email" not in body

    missing = await client.get("/api/v1/users/ghost")
    assert missing.status_code == 404
    assert missing.json()["error"]["code"] == "USER_NOT_FOUND"
