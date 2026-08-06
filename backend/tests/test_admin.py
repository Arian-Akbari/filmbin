"""Sections 4.3 and 7.7 — the two access levels and what the admin can do."""

from __future__ import annotations

from httpx import AsyncClient

from tests.conftest import auth_headers, register
from tests.fakes import MATRIX_ID

ADMIN_PATHS = [
    "/api/v1/admin/users",
    "/api/v1/admin/reviews",
    "/api/v1/admin/reports",
    "/api/v1/admin/stats",
    "/api/v1/admin/titles",
]


async def test_regular_users_are_locked_out(client: AsyncClient, user_headers: dict) -> None:
    for path in ADMIN_PATHS:
        response = await client.get(path, headers=user_headers)
        assert response.status_code == 403, path
        assert response.json()["error"]["code"] == "PERMISSION_DENIED"


async def test_anonymous_callers_are_locked_out(client: AsyncClient) -> None:
    for path in ADMIN_PATHS:
        assert (await client.get(path)).status_code == 401, path


async def test_admin_lists_and_disables_users(
    client: AsyncClient, admin_headers: dict, user_tokens: dict
) -> None:
    listing = await client.get("/api/v1/admin/users", headers=admin_headers)
    assert listing.status_code == 200
    users = listing.json()["items"]
    assert {u["username"] for u in users} >= {"arian", "admin"}

    target = next(u for u in users if u["username"] == "arian")
    disabled = await client.patch(
        f"/api/v1/admin/users/{target['id']}", json={"is_active": False}, headers=admin_headers
    )
    assert disabled.status_code == 200
    assert disabled.json()["is_active"] is False

    blocked = await client.get("/api/v1/users/me", headers=auth_headers(user_tokens))
    assert blocked.status_code == 403
    assert blocked.json()["error"]["code"] == "ACCOUNT_DISABLED"


async def test_admin_cannot_disable_themselves(client: AsyncClient, admin_headers: dict) -> None:
    me = (await client.get("/api/v1/users/me", headers=admin_headers)).json()
    response = await client.patch(
        f"/api/v1/admin/users/{me['id']}", json={"is_active": False}, headers=admin_headers
    )
    assert response.status_code == 400
    assert response.json()["error"]["code"] == "CANNOT_MODIFY_SELF"


async def test_admin_promotes_a_user(client: AsyncClient, admin_headers: dict) -> None:
    tokens = await register(client, username="mod", email="mod@example.com")
    me = (await client.get("/api/v1/users/me", headers=auth_headers(tokens))).json()

    promoted = await client.patch(
        f"/api/v1/admin/users/{me['id']}", json={"role": "admin"}, headers=admin_headers
    )
    assert promoted.json()["role"] == "admin"
    assert (
        await client.get("/api/v1/admin/stats", headers=auth_headers(tokens))
    ).status_code == 200


async def test_admin_removes_an_inappropriate_review(
    client: AsyncClient, admin_headers: dict, user_headers: dict
) -> None:
    created = await client.post(
        f"/api/v1/titles/{MATRIX_ID}/reviews",
        json={"text": "متن نامناسب"},
        headers=user_headers,
    )
    review_id = created.json()["id"]

    listed = await client.get("/api/v1/admin/reviews", headers=admin_headers)
    assert any(r["id"] == review_id for r in listed.json()["items"])

    removed = await client.delete(f"/api/v1/admin/reviews/{review_id}", headers=admin_headers)
    assert removed.status_code == 204

    public = await client.get(f"/api/v1/titles/{MATRIX_ID}/reviews")
    assert public.json()["total"] == 0


async def test_admin_handles_reports(
    client: AsyncClient, admin_headers: dict, user_headers: dict
) -> None:
    author = await register(client, username="poster", email="poster@example.com")
    review_id = (
        await client.post(
            f"/api/v1/titles/{MATRIX_ID}/reviews",
            json={"text": "نظر گزارش‌شده"},
            headers=auth_headers(author),
        )
    ).json()["id"]
    await client.post(
        "/api/v1/reports",
        json={"review_id": review_id, "reason": "اسپویل بدون هشدار"},
        headers=user_headers,
    )

    pending = await client.get("/api/v1/admin/reports", headers=admin_headers)
    assert pending.json()["items"][0]["reason"] == "اسپویل بدون هشدار"
    report_id = pending.json()["items"][0]["id"]
    assert pending.json()["items"][0]["review"]["text"] == "نظر گزارش‌شده"

    resolved = await client.patch(
        f"/api/v1/admin/reports/{report_id}",
        json={"status": "resolved", "delete_review": True, "resolution_note": "حذف شد"},
        headers=admin_headers,
    )
    assert resolved.status_code == 200
    assert resolved.json()["status"] == "resolved"
    assert (await client.get(f"/api/v1/titles/{MATRIX_ID}/reviews")).json()["total"] == 0


async def test_admin_sees_system_statistics(
    client: AsyncClient, admin_headers: dict, user_headers: dict
) -> None:
    await client.post(
        f"/api/v1/titles/{MATRIX_ID}/rating", json={"score": 5}, headers=user_headers
    )
    await client.post(
        f"/api/v1/titles/{MATRIX_ID}/reviews", json={"text": "نظر"}, headers=user_headers
    )

    stats = (await client.get("/api/v1/admin/stats", headers=admin_headers)).json()
    assert stats["users"] >= 2
    assert stats["active_users"] >= 2
    assert stats["cached_titles"] >= 1
    assert stats["ratings"] == 1
    assert stats["reviews"] == 1
    assert stats["pending_reports"] == 0
    assert "imdb_circuit_open" in stats
    assert stats["most_tracked"] == [] or "title" in stats["most_tracked"][0]


async def test_admin_manages_cached_titles(client: AsyncClient, admin_headers: dict) -> None:
    await client.get(f"/api/v1/titles/{MATRIX_ID}")

    listing = await client.get("/api/v1/admin/titles", headers=admin_headers)
    assert any(t["imdb_id"] == MATRIX_ID for t in listing.json()["items"])

    evicted = await client.delete(f"/api/v1/admin/titles/{MATRIX_ID}", headers=admin_headers)
    assert evicted.status_code == 204

    after = await client.get("/api/v1/admin/titles", headers=admin_headers)
    assert all(t["imdb_id"] != MATRIX_ID for t in after.json()["items"])
