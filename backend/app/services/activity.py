"""Activity trail feeding the social timeline (bonus feature)."""

from __future__ import annotations

from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import Activity, ActivityType


async def record(
    db: AsyncSession,
    user_id: int,
    activity_type: ActivityType,
    *,
    title_id: str | None = None,
    payload: dict[str, Any] | None = None,
) -> None:
    db.add(
        Activity(
            user_id=user_id,
            type=activity_type.value,
            title_id=title_id,
            payload=payload,
        )
    )
    await db.flush()
