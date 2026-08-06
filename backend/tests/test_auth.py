"""Sections 5.1–5.3, 7.6, 7.8 — registration, login, sessions, password reset."""

from __future__ import annotations

from httpx import AsyncClient

from tests.conftest import auth_headers, register


async def test_register_returns_tokens_and_profile(client: AsyncClient) -> None:
    body = await register(client)

    assert body["token_type"] == "bearer"
    assert body["access_token"] and body["refresh_token"]
    assert body["expires_in"] > 0
    user = body["user"]
    assert user["username"] == "arian"
    assert user["email"] == "arian@example.com"
    assert user["role"] == "user"
    assert "password" not in user and "password_hash" not in user
    # Section 5.1: the profile carries automatic counters from the start.
    assert user["summary"] == {"watched_movies": 0, "followed_series": 0, "favorites": 0}


async def test_register_rejects_duplicate_email_and_username(client: AsyncClient) -> None:
    await register(client)

    same_email = await client.post(
        "/api/v1/auth/register",
        json={
            "full_name": "کاربر دوم",
            "username": "other",
            "email": "arian@example.com",
            "password": "Str0ngPass!",
        },
    )
    assert same_email.status_code == 409
    assert same_email.json()["error"]["code"] == "EMAIL_TAKEN"

    same_username = await client.post(
        "/api/v1/auth/register",
        json={
            "full_name": "کاربر سوم",
            "username": "arian",
            "email": "other@example.com",
            "password": "Str0ngPass!",
        },
    )
    assert same_username.status_code == 409
    assert same_username.json()["error"]["code"] == "USERNAME_TAKEN"


async def test_register_validates_input(client: AsyncClient) -> None:
    response = await client.post(
        "/api/v1/auth/register",
        json={"full_name": "x", "username": "a b", "email": "not-an-email", "password": "123"},
    )
    assert response.status_code == 422
    error = response.json()["error"]
    assert error["code"] == "VALIDATION_ERROR"
    assert "email" in error["fields"] and "password" in error["fields"]


async def test_login_and_wrong_password(client: AsyncClient) -> None:
    await register(client)

    ok = await client.post(
        "/api/v1/auth/login",
        json={"email": "arian@example.com", "password": "Str0ngPass!"},
    )
    assert ok.status_code == 200
    assert ok.json()["user"]["username"] == "arian"

    bad = await client.post(
        "/api/v1/auth/login",
        json={"email": "arian@example.com", "password": "wrong-password"},
    )
    assert bad.status_code == 401
    assert bad.json()["error"]["code"] == "INVALID_CREDENTIALS"


async def test_login_session_length_defaults_to_a_month(client: AsyncClient) -> None:
    """Section 5.2 — stay signed in for a month unless a shorter session is asked for."""
    await register(client)

    long_session = await client.post(
        "/api/v1/auth/login",
        json={"email": "arian@example.com", "password": "Str0ngPass!"},
    )
    short_session = await client.post(
        "/api/v1/auth/login",
        json={
            "email": "arian@example.com",
            "password": "Str0ngPass!",
            "remember_me": False,
        },
    )

    month = long_session.json()["refresh_expires_in"]
    day = short_session.json()["refresh_expires_in"]
    assert month == 30 * 24 * 3600
    assert day < month


async def test_refresh_rotates_token_and_logout_revokes_it(client: AsyncClient) -> None:
    tokens = await register(client)

    refreshed = await client.post(
        "/api/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]}
    )
    assert refreshed.status_code == 200
    new_tokens = refreshed.json()
    assert new_tokens["refresh_token"] != tokens["refresh_token"]

    replayed = await client.post(
        "/api/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]}
    )
    assert replayed.status_code == 401

    logout = await client.post(
        "/api/v1/auth/logout",
        json={"refresh_token": new_tokens["refresh_token"]},
        headers=auth_headers(new_tokens),
    )
    assert logout.status_code == 204

    after_logout = await client.post(
        "/api/v1/auth/refresh", json={"refresh_token": new_tokens["refresh_token"]}
    )
    assert after_logout.status_code == 401


async def test_protected_endpoint_needs_a_token(client: AsyncClient) -> None:
    anonymous = await client.get("/api/v1/users/me")
    assert anonymous.status_code == 401
    assert anonymous.json()["error"]["code"] == "UNAUTHENTICATED"

    garbage = await client.get(
        "/api/v1/users/me", headers={"Authorization": "Bearer not.a.jwt"}
    )
    assert garbage.status_code == 401
    assert garbage.json()["error"]["code"] == "INVALID_TOKEN"


async def test_password_reset_flow(client: AsyncClient) -> None:
    """Section 5.3 — request a reset by email, then set a new password."""
    await register(client)

    requested = await client.post(
        "/api/v1/auth/password/forgot", json={"email": "arian@example.com"}
    )
    assert requested.status_code == 200
    token = requested.json()["reset_token"]
    assert token

    unknown_email = await client.post(
        "/api/v1/auth/password/forgot", json={"email": "nobody@example.com"}
    )
    # Never leak which addresses exist.
    assert unknown_email.status_code == 200
    assert unknown_email.json().get("reset_token") is None

    reset = await client.post(
        "/api/v1/auth/password/reset",
        json={"token": token, "password": "NewStr0ng!"},
    )
    assert reset.status_code == 200

    assert (
        await client.post(
            "/api/v1/auth/login",
            json={"email": "arian@example.com", "password": "Str0ngPass!"},
        )
    ).status_code == 401
    assert (
        await client.post(
            "/api/v1/auth/login",
            json={"email": "arian@example.com", "password": "NewStr0ng!"},
        )
    ).status_code == 200

    replay = await client.post(
        "/api/v1/auth/password/reset",
        json={"token": token, "password": "Another1!"},
    )
    assert replay.status_code == 400
    assert replay.json()["error"]["code"] == "INVALID_RESET_TOKEN"


async def test_logout_revokes_only_the_given_device(client: AsyncClient) -> None:
    tokens = await register(client)
    second = await client.post(
        "/api/v1/auth/login",
        json={"email": "arian@example.com", "password": "Str0ngPass!"},
    )
    second_tokens = second.json()

    await client.post(
        "/api/v1/auth/logout",
        json={"refresh_token": tokens["refresh_token"]},
        headers=auth_headers(tokens),
    )

    still_valid = await client.post(
        "/api/v1/auth/refresh", json={"refresh_token": second_tokens["refresh_token"]}
    )
    assert still_valid.status_code == 200
