"""Turning `Title` rows into API payloads.

Every list endpoint goes through `summarize()`, which fetches the community
rating and the caller's own state in **two queries for the whole page** rather
than two per row — the difference between a snappy list and an N+1 problem
(section 8.7).
"""

from __future__ import annotations

from datetime import UTC, datetime
from typing import Any, Iterable, Sequence

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import Rating, Review, Season, Title, UserTitle
from app.imdb.mapper import sized_image
from app.schemas.review import ReviewOut
from app.schemas.title import ProgressOut, RatingBucket, TitleDetail, TitleSummary
from app.services.progress import compute_progress

POSTER_WIDTH = 500
THUMB_WIDTH = 220


async def rating_aggregates(
    db: AsyncSession, title_ids: Sequence[str]
) -> dict[str, tuple[float, int]]:
    if not title_ids:
        return {}
    rows = await db.execute(
        select(Rating.title_id, func.avg(Rating.score), func.count(Rating.id))
        .where(Rating.title_id.in_(title_ids))
        .group_by(Rating.title_id)
    )
    return {row[0]: (round(float(row[1]), 2), int(row[2])) for row in rows}


async def user_context(
    db: AsyncSession, user_id: int | None, title_ids: Sequence[str]
) -> dict[str, dict[str, Any]]:
    if user_id is None or not title_ids:
        return {}

    context: dict[str, dict[str, Any]] = {}
    entries = await db.execute(
        select(UserTitle).where(
            UserTitle.user_id == user_id, UserTitle.title_id.in_(title_ids)
        )
    )
    for entry in entries.scalars():
        context[entry.title_id] = {
            "my_status": entry.status,
            "is_favorite": entry.is_favorite,
            "my_rating": None,
        }

    ratings = await db.execute(
        select(Rating.title_id, Rating.score).where(
            Rating.user_id == user_id, Rating.title_id.in_(title_ids)
        )
    )
    for title_id, score in ratings:
        context.setdefault(title_id, {"my_status": None, "is_favorite": False})
        context[title_id]["my_rating"] = score

    return context


def _base_payload(title: Title) -> dict[str, Any]:
    return {
        "imdb_id": title.imdb_id,
        "kind": title.kind,
        "title": title.title,
        "original_title": title.original_title,
        "year": title.year,
        "end_year": title.end_year,
        "poster_url": sized_image(title.poster_url, POSTER_WIDTH),
        "poster_thumb_url": sized_image(title.poster_url, THUMB_WIDTH),
        "plot": title.plot,
        "genres": title.genres or [],
        "runtime_minutes": title.runtime_minutes,
        "imdb_rating": title.imdb_rating,
        "imdb_votes": title.imdb_votes,
    }


async def summarize(
    db: AsyncSession, titles: Iterable[Title], user_id: int | None = None
) -> list[TitleSummary]:
    titles = list(titles)
    ids = [t.imdb_id for t in titles]
    aggregates = await rating_aggregates(db, ids)
    context = await user_context(db, user_id, ids)

    summaries: list[TitleSummary] = []
    for title in titles:
        payload = _base_payload(title)
        average, count = aggregates.get(title.imdb_id, (None, 0))
        payload["user_rating_average"] = average
        payload["user_rating_count"] = count
        payload.update(
            context.get(
                title.imdb_id, {"my_status": None, "my_rating": None, "is_favorite": False}
            )
        )
        summaries.append(TitleSummary(**payload))
    return summaries


def distribute(counts: dict[int, int]) -> list[RatingBucket]:
    """Star histogram in percent (section 5.13).

    Rounded with the largest-remainder method so the five bars always add up to
    exactly 100 and the UI never shows a 99% total.
    """
    total = sum(counts.values())
    if total == 0:
        return [RatingBucket(score=score, count=0, percent=0) for score in range(1, 6)]

    exact = {score: counts.get(score, 0) / total * 100 for score in range(1, 6)}
    floors = {score: int(value) for score, value in exact.items()}
    remainder = 100 - sum(floors.values())
    for score, _ in sorted(exact.items(), key=lambda kv: kv[1] - int(kv[1]), reverse=True):
        if remainder <= 0:
            break
        floors[score] += 1
        remainder -= 1

    return [
        RatingBucket(score=score, count=counts.get(score, 0), percent=floors[score])
        for score in range(1, 6)
    ]


async def rating_distribution(db: AsyncSession, title_id: str) -> list[RatingBucket]:
    rows = await db.execute(
        select(Rating.score, func.count(Rating.id))
        .where(Rating.title_id == title_id)
        .group_by(Rating.score)
    )
    return distribute({int(score): int(count) for score, count in rows})


def status_label(title: Title) -> str:
    """Section 5.7 — «وضعیت پخش»."""
    if title.kind == "series":
        if title.is_ongoing:
            return "در حال پخش"
        if title.end_year:
            return "پایان‌یافته"
        return "پایان‌یافته" if title.is_ongoing is False else "نامشخص"
    if title.year and title.year > datetime.now(UTC).year:
        return "منتشرنشده"
    return "منتشرشده"


async def detail(
    db: AsyncSession, title: Title, user_id: int | None = None
) -> TitleDetail:
    (summary,) = await summarize(db, [title], user_id)
    payload = summary.model_dump()

    seasons = list(
        (
            await db.execute(
                select(Season).where(Season.series_id == title.imdb_id).order_by(Season.number)
            )
        ).scalars()
    )

    my_review = None
    if user_id is not None:
        row = (
            await db.execute(
                select(Review).where(
                    Review.user_id == user_id,
                    Review.title_id == title.imdb_id,
                    Review.is_hidden.is_(False),
                )
            )
        ).scalar_one_or_none()
        if row is not None:
            my_review = ReviewOut.model_validate(row)

    progress = None
    if user_id is not None or title.kind == "series":
        progress = ProgressOut(**await compute_progress(db, user_id, title))

    payload.update(
        {
            "countries": title.countries or [],
            "directors": title.directors or [],
            "creators": title.creators or [],
            "cast": title.cast or [],
            "season_count": title.season_count,
            "episode_count": title.episode_count,
            "is_ongoing": title.is_ongoing,
            "status_label": status_label(title),
            "seasons": [
                {"number": s.number, "episode_count": s.episode_count} for s in seasons
            ],
            "rating_distribution": await rating_distribution(db, title.imdb_id),
            "my_review": my_review,
            "progress": progress,
            "updated_at": title.fetched_at,
        }
    )
    return TitleDetail(**payload)
