"""Test harness: a throwaway SQLite file per session and a fake IMDb upstream."""

from __future__ import annotations

import os
import tempfile
from collections.abc import AsyncIterator
from pathlib import Path

import pytest
import pytest_asyncio

TMP_DB = Path(tempfile.mkdtemp(prefix="filmbin-tests-")) / "test.db"
os.environ["DATABASE_URL"] = f"sqlite+aiosqlite:///{TMP_DB}"
os.environ["JWT_SECRET"] = "test-secret"
os.environ["RATE_LIMIT_REQUESTS"] = "10000"
os.environ["AUTH_RATE_LIMIT_REQUESTS"] = "10000"
os.environ["MEDIA_DIR"] = str(TMP_DB.parent / "media")

from httpx import ASGITransport, AsyncClient  # noqa: E402

from app.db.base import Base, engine  # noqa: E402
from app.imdb import client as imdb_client_module  # noqa: E402
from app.imdb import service as imdb_service  # noqa: E402
from app.main import app  # noqa: E402
from tests.fakes import FakeImdb  # noqa: E402


@pytest.fixture(scope="session")
def anyio_backend() -> str:
    return "asyncio"


@pytest_asyncio.fixture(autouse=True)
async def fresh_database() -> AsyncIterator[None]:
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)
    yield


@pytest.fixture
def fake_imdb(monkeypatch: pytest.MonkeyPatch) -> FakeImdb:
    fake = FakeImdb()
    monkeypatch.setattr(imdb_client_module.imdb_client, "execute", fake.execute)
    monkeypatch.setattr(imdb_service.imdb_client, "execute", fake.execute)
    return fake


@pytest_asyncio.fixture
async def client(fake_imdb: FakeImdb) -> AsyncIterator[AsyncClient]:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


async def register(
    client: AsyncClient,
    *,
    username: str = "arian",
    email: str = "arian@example.com",
    password: str = "Str0ngPass!",
    full_name: str = "آرین اکبری",
) -> dict:
    response = await client.post(
        "/api/v1/auth/register",
        json={
            "full_name": full_name,
            "username": username,
            "email": email,
            "password": password,
            "bio": "دانشجوی شریف",
        },
    )
    assert response.status_code == 201, response.text
    return response.json()


def auth_headers(tokens: dict) -> dict[str, str]:
    return {"Authorization": f"Bearer {tokens['access_token']}"}


@pytest_asyncio.fixture
async def user_tokens(client: AsyncClient) -> dict:
    return await register(client)


@pytest_asyncio.fixture
async def user_headers(user_tokens: dict) -> dict[str, str]:
    return auth_headers(user_tokens)


@pytest_asyncio.fixture
async def admin_headers(client: AsyncClient) -> dict[str, str]:
    """Promote a freshly registered user straight in the database."""
    tokens = await register(
        client, username="admin", email="admin@example.com", full_name="مدیر سیستم"
    )
    from sqlalchemy import update

    from app.db.base import SessionLocal
    from app.db.models import User, UserRole

    async with SessionLocal() as session:
        await session.execute(
            update(User).where(User.email == "admin@example.com").values(role=UserRole.ADMIN.value)
        )
        await session.commit()
    return auth_headers(tokens)
