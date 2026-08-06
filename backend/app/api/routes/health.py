"""Liveness probe — also reports whether IMDb is currently circuit-broken."""

from __future__ import annotations

from fastapi import APIRouter
from sqlalchemy import text

from app.core.config import settings
from app.core.deps import DbSession
from app.imdb.client import imdb_client

router = APIRouter(tags=["سلامت سرویس"])


@router.get("/health", summary="وضعیت سرویس")
async def health(db: DbSession) -> dict:
    try:
        await db.execute(text("SELECT 1"))
        database = "ok"
    except Exception:  # noqa: BLE001
        database = "down"

    return {
        "status": "ok" if database == "ok" else "degraded",
        "version": settings.app_version,
        "database": database,
        "imdb_circuit_open": imdb_client.breaker.is_open,
    }
