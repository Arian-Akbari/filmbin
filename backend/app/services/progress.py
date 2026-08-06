"""Watch progress and its colour coding (section 5.11).

The colour is not decoration — it is the one-glance answer to "where am I with
this show?", so the rule lives on the server and every client shows the same
thing:

* **none** — nothing watched yet.
* **yellow** — some episodes are still unwatched.
* **green** — caught up, but the show is still running.
* **purple** — finished, and there will be no more episodes.
* **red** — the user stopped (paused/dropped) before finishing.
"""

from __future__ import annotations

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import Episode, EpisodeWatch, Title, UserTitle, WatchStatus

STOPPED = {WatchStatus.PAUSED.value, WatchStatus.DROPPED.value}


def progress_color(
    watched: int, total: int, status: str | None, is_ongoing: bool
) -> str:
    if total <= 0:
        # A movie (or a series we have no episode list for): status is all we have.
        if status == WatchStatus.WATCHED.value:
            return "purple"
        if status in STOPPED:
            return "red"
        return "none"
    if status in STOPPED and watched < total:
        return "red"
    if watched <= 0:
        return "none"
    if watched >= total:
        return "green" if is_ongoing else "purple"
    return "yellow"


def build_progress(
    *, watched: int, total: int, status: str | None, is_ongoing: bool
) -> dict:
    if total > 0:
        percent = min(100, round(watched / total * 100))
    else:
        percent = 100 if status == WatchStatus.WATCHED.value else 0
    return {
        "total_episodes": total,
        "watched_episodes": watched,
        "remaining_episodes": max(0, total - watched),
        "percent": percent,
        "color": progress_color(watched, total, status, is_ongoing),
        "is_ongoing": bool(is_ongoing),
    }


async def episode_totals(db: AsyncSession, series_id: str) -> int:
    return int(
        (
            await db.execute(
                select(func.count()).select_from(Episode).where(Episode.series_id == series_id)
            )
        ).scalar_one()
    )


async def watched_count(db: AsyncSession, user_id: int, series_id: str) -> int:
    return int(
        (
            await db.execute(
                select(func.count())
                .select_from(EpisodeWatch)
                .where(EpisodeWatch.user_id == user_id, EpisodeWatch.series_id == series_id)
            )
        ).scalar_one()
    )


async def compute_progress(
    db: AsyncSession, user_id: int | None, title: Title, *, sync: bool = True
) -> dict:
    """Progress for one title. For series we make sure the episode mirror is
    populated first, otherwise the totals would silently be wrong."""
    status = None
    if user_id is not None:
        status = (
            await db.execute(
                select(UserTitle.status).where(
                    UserTitle.user_id == user_id, UserTitle.title_id == title.imdb_id
                )
            )
        ).scalar_one_or_none()

    if title.kind != "series":
        return build_progress(
            watched=0, total=0, status=status, is_ongoing=bool(title.is_ongoing)
        )

    if sync:
        from app.imdb.service import episodes_are_complete, sync_all_episodes

        if not await episodes_are_complete(db, title):
            try:
                await sync_all_episodes(db, title.imdb_id)
            except Exception:  # noqa: BLE001 — progress must never fail the request
                pass
    total = await episode_totals(db, title.imdb_id)

    watched = await watched_count(db, user_id, title.imdb_id) if user_id else 0
    return build_progress(
        watched=watched, total=total, status=status, is_ongoing=bool(title.is_ongoing)
    )
