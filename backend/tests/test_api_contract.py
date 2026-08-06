"""Cross-cutting API guarantees: the error envelope, docs, health, throttling."""

from __future__ import annotations

from httpx import ASGITransport, AsyncClient

from tests.fakes import MATRIX_ID


async def test_health(client: AsyncClient) -> None:
    response = await client.get("/api/v1/health")
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ok"
    assert body["version"]
    assert body["database"] == "ok"


async def test_unknown_route_uses_the_error_envelope(client: AsyncClient) -> None:
    response = await client.get("/api/v1/nope")
    assert response.status_code == 404
    error = response.json()["error"]
    assert error["status"] == 404
    assert error["code"] == "NOT_FOUND"
    assert error["message"]


async def test_openapi_documents_every_router(client: AsyncClient) -> None:
    """Section 7.10 — the API has to be documented."""
    schema = (await client.get("/openapi.json")).json()
    paths = schema["paths"]

    for path in (
        "/api/v1/auth/register",
        "/api/v1/auth/login",
        "/api/v1/users/me",
        "/api/v1/titles/search",
        "/api/v1/titles/{imdb_id}",
        "/api/v1/titles/{imdb_id}/seasons/{season}/episodes",
        "/api/v1/titles/{imdb_id}/status",
        "/api/v1/titles/{imdb_id}/rating",
        "/api/v1/titles/{imdb_id}/reviews",
        "/api/v1/watchlist",
        "/api/v1/lists",
        "/api/v1/users/me/stats",
        "/api/v1/admin/stats",
    ):
        assert path in paths, path

    assert schema["info"]["title"]
    assert schema["info"]["description"]
    assert "bearerAuth" in schema["components"]["securitySchemes"]

    login = paths["/api/v1/auth/login"]["post"]
    assert login["summary"]
    assert login["description"]
    assert "401" in login["responses"]


async def test_docs_pages_are_served(client: AsyncClient) -> None:
    assert (await client.get("/docs")).status_code == 200
    assert (await client.get("/redoc")).status_code == 200


async def test_cors_allows_the_mobile_client(client: AsyncClient) -> None:
    response = await client.options(
        "/api/v1/titles/search",
        headers={
            "Origin": "http://localhost",
            "Access-Control-Request-Method": "GET",
        },
    )
    assert response.status_code in (200, 204)
    assert response.headers["access-control-allow-origin"]


async def test_validation_error_lists_offending_fields(client: AsyncClient) -> None:
    response = await client.post("/api/v1/auth/login", json={"email": "x"})
    assert response.status_code == 422
    error = response.json()["error"]
    assert error["code"] == "VALIDATION_ERROR"
    assert set(error["fields"]) >= {"email", "password"}


async def test_rate_limiter_kicks_in(monkeypatch, fake_imdb) -> None:
    """Section 8.3 — brute-force protection on the auth endpoints."""
    from app.core import rate_limit
    from app.main import app

    monkeypatch.setattr(rate_limit.settings, "auth_rate_limit_requests", 3)
    monkeypatch.setattr(rate_limit.settings, "auth_rate_limit_window_seconds", 60)

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://ratelimit") as ac:
        codes = []
        for _ in range(5):
            response = await ac.post(
                "/api/v1/auth/login", json={"email": "a@b.com", "password": "whatever"}
            )
            codes.append(response.status_code)

    assert 429 in codes
    assert codes[-1] == 429


async def test_titles_endpoint_paginates(client: AsyncClient) -> None:
    response = await client.get("/api/v1/titles/search", params={"q": "matrix", "limit": 1})
    body = response.json()
    assert len(body["items"]) <= 1
    assert "next_cursor" in body
    assert body["stale"] is False


async def test_all_write_endpoints_reject_anonymous_callers(client: AsyncClient) -> None:
    cases = [
        ("put", f"/api/v1/titles/{MATRIX_ID}/status", {"status": "watching"}),
        ("post", f"/api/v1/titles/{MATRIX_ID}/rating", {"score": 3}),
        ("post", f"/api/v1/titles/{MATRIX_ID}/reviews", {"text": "hi"}),
        ("post", "/api/v1/lists", {"name": "x"}),
        ("post", "/api/v1/reports", {"review_id": 1, "reason": "x"}),
    ]
    for method, path, payload in cases:
        response = await getattr(client, method)(path, json=payload)
        assert response.status_code == 401, path


async def test_timestamps_carry_their_timezone(client, user_headers, fake_imdb):
    """A naive timestamp reads as local time on the client — «۳ ساعت پیش» for a
    review posted a second ago. Every datetime we hand out is UTC-aware."""
    await client.post(
        f"/api/v1/titles/{MATRIX_ID}/reviews",
        headers=user_headers,
        json={"text": "تازه ثبت شد.", "has_spoiler": False},
    )

    response = await client.get(f"/api/v1/titles/{MATRIX_ID}/reviews")
    created = response.json()["items"][0]["created_at"]
    assert created.endswith("Z") or "+00:00" in created, created

    me = await client.get("/api/v1/users/me", headers=user_headers)
    joined = me.json()["created_at"]
    assert joined.endswith("Z") or "+00:00" in joined, joined
