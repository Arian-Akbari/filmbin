"""Aggregate counters: profile summary, user dashboard, admin overview."""

from __future__ import annotations

from collections import Counter
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import (
    ChatMessage,
    CustomList,
    Episode,
    EpisodeWatch,
    Rating,
    Report,
    ReportStatus,
    Review,
    Session,
    Title,
    User,
    UserRole,
    UserTitle,
    WatchStatus,
    utcnow,
)


async def _scalar(db: AsyncSession, statement) -> int:
    return int((await db.execute(statement)).scalar_one() or 0)


async def profile_summary(db: AsyncSession, user_id: int) -> dict[str, int]:
    """Section 5.1 — the three counters shown on every profile."""
    watched_movies = await _scalar(
        db,
        select(func.count())
        .select_from(UserTitle)
        .join(Title, Title.imdb_id == UserTitle.title_id)
        .where(
            UserTitle.user_id == user_id,
            UserTitle.status == WatchStatus.WATCHED.value,
            Title.kind == "movie",
        ),
    )
    followed_series = await _scalar(
        db,
        select(func.count())
        .select_from(UserTitle)
        .join(Title, Title.imdb_id == UserTitle.title_id)
        .where(
            UserTitle.user_id == user_id,
            UserTitle.status.is_not(None),
            Title.kind == "series",
        ),
    )
    favorites = await _scalar(
        db,
        select(func.count())
        .select_from(UserTitle)
        .where(UserTitle.user_id == user_id, UserTitle.is_favorite.is_(True)),
    )
    return {
        "watched_movies": watched_movies,
        "followed_series": followed_series,
        "favorites": favorites,
    }


async def user_stats(db: AsyncSession, user_id: int) -> dict[str, Any]:
    """Section 5.19 — the full activity dashboard."""
    entries = list(
        (
            await db.execute(
                select(UserTitle, Title)
                .join(Title, Title.imdb_id == UserTitle.title_id)
                .where(UserTitle.user_id == user_id)
            )
        ).all()
    )

    watched_movies = 0
    watched_series = 0
    movie_minutes = 0
    status_breakdown: Counter[str] = Counter()
    genres: Counter[str] = Counter()

    for entry, title in entries:
        if entry.status:
            status_breakdown[entry.status] += 1
        if entry.status == WatchStatus.WATCHED.value:
            if title.kind == "movie":
                watched_movies += 1
                movie_minutes += title.runtime_minutes or 0
            else:
                watched_series += 1
        if entry.status or entry.is_favorite:
            for genre in title.genres or []:
                genres[genre] += 1

    episode_rows = list(
        (
            await db.execute(
                select(EpisodeWatch.runtime_minutes).where(EpisodeWatch.user_id == user_id)
            )
        ).scalars()
    )
    watched_episodes = len(episode_rows)
    episode_minutes = sum(minutes or 0 for minutes in episode_rows)

    rating_row = (
        await db.execute(
            select(func.avg(Rating.score), func.count(Rating.id)).where(
                Rating.user_id == user_id
            )
        )
    ).one()
    average_rating = round(float(rating_row[0]), 2) if rating_row[0] is not None else None

    reviews_count = await _scalar(
        db,
        select(func.count())
        .select_from(Review)
        .where(Review.user_id == user_id, Review.is_hidden.is_(False)),
    )
    lists_count = await _scalar(
        db, select(func.count()).select_from(CustomList).where(CustomList.user_id == user_id)
    )

    total_minutes = movie_minutes + episode_minutes
    ordered_genres = [
        {"genre": genre, "count": count} for genre, count in genres.most_common(8)
    ]

    return {
        "watched_movies": watched_movies,
        "watched_series": watched_series,
        "watched_episodes": watched_episodes,
        "total_watch_minutes": total_minutes,
        "total_watch_hours": round(total_minutes / 60, 1),
        "favorite_genres": ordered_genres,
        "top_genre": ordered_genres[0]["genre"] if ordered_genres else None,
        "average_rating": average_rating,
        "ratings_count": int(rating_row[1] or 0),
        "reviews_count": reviews_count,
        "favorites_count": sum(1 for entry, _ in entries if entry.is_favorite),
        "lists_count": lists_count,
        "status_breakdown": dict(status_breakdown),
    }


async def admin_stats(db: AsyncSession) -> dict[str, Any]:
    """Section 4.3 — «آمار کلی سامانه»."""
    from app.imdb.client import imdb_client

    most_tracked_rows = (
        await db.execute(
            select(Title.imdb_id, Title.title, func.count(UserTitle.id).label("tracked"))
            .join(UserTitle, UserTitle.title_id == Title.imdb_id)
            .group_by(Title.imdb_id, Title.title)
            .order_by(func.count(UserTitle.id).desc())
            .limit(5)
        )
    ).all()

    return {
        "users": await _scalar(db, select(func.count()).select_from(User)),
        "active_users": await _scalar(
            db, select(func.count()).select_from(User).where(User.is_active.is_(True))
        ),
        "admins": await _scalar(
            db,
            select(func.count()).select_from(User).where(User.role == UserRole.ADMIN.value),
        ),
        "cached_titles": await _scalar(db, select(func.count()).select_from(Title)),
        "cached_episodes": await _scalar(db, select(func.count()).select_from(Episode)),
        "ratings": await _scalar(db, select(func.count()).select_from(Rating)),
        "reviews": await _scalar(
            db, select(func.count()).select_from(Review).where(Review.is_hidden.is_(False))
        ),
        "hidden_reviews": await _scalar(
            db, select(func.count()).select_from(Review).where(Review.is_hidden.is_(True))
        ),
        "lists": await _scalar(db, select(func.count()).select_from(CustomList)),
        "pending_reports": await _scalar(
            db,
            select(func.count())
            .select_from(Report)
            .where(Report.status == ReportStatus.PENDING.value),
        ),
        "watch_entries": await _scalar(db, select(func.count()).select_from(UserTitle)),
        "episode_marks": await _scalar(db, select(func.count()).select_from(EpisodeWatch)),
        "active_sessions": await _scalar(
            db,
            select(func.count())
            .select_from(Session)
            .where(Session.revoked_at.is_(None), Session.expires_at > utcnow()),
        ),
        "chat_messages": await _scalar(db, select(func.count()).select_from(ChatMessage)),
        "imdb_circuit_open": imdb_client.breaker.is_open,
        "most_tracked": [
            {"imdb_id": row[0], "title": row[1], "count": int(row[2])}
            for row in most_tracked_rows
        ],
    }
