"""Async SQLAlchemy engine / session wiring."""

from __future__ import annotations

from collections.abc import AsyncIterator

from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import DeclarativeBase

from app.core.config import settings


class Base(DeclarativeBase):
    pass


def _engine_kwargs() -> dict:
    if settings.is_sqlite:
        # SQLite needs no pool tuning, but it does need a longer busy timeout so
        # concurrent writers queue instead of raising "database is locked".
        return {"connect_args": {"timeout": 30}}
    return {"pool_size": 20, "max_overflow": 10, "pool_pre_ping": True}


engine = create_async_engine(
    settings.database_url, echo=settings.db_echo, future=True, **_engine_kwargs()
)

SessionLocal = async_sessionmaker(engine, expire_on_commit=False, class_=AsyncSession)


async def init_db() -> None:
    from app.db import models  # noqa: F401  (register mappers)

    async with engine.begin() as conn:
        if settings.is_sqlite:
            from sqlalchemy import text

            # WAL lets readers run while a writer holds the lock — the difference
            # between "a few users" and "a classroom hitting it at once".
            await conn.execute(text("PRAGMA journal_mode=WAL"))
            await conn.execute(text("PRAGMA foreign_keys=ON"))
        await conn.run_sync(Base.metadata.create_all)


async def get_session() -> AsyncIterator[AsyncSession]:
    async with SessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
