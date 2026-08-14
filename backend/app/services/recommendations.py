"""«فیلم‌ها و سریال‌های پیشنهادی» — taste-based suggestions (section 5.18).

Deliberately simple and explainable: take the genres the user actually engages
with, weight favourites double, ask IMDb for the best-rated titles in those
genres, and drop anything the user already tracks. When we do not know the user
yet, fall back to what is popular.
"""

from __future__ import annotations

from collections import Counter

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import UpstreamError
from app.db.models import Title, UserTitle
from app.imdb import service as imdb_service


async def taste_profile(db: AsyncSession, user_id: int) -> tuple[list[str], set[str]]:
    rows = (
        await db.execute(
            select(UserTitle, Title)
            .join(Title, Title.imdb_id == UserTitle.title_id)
            .where(UserTitle.user_id == user_id)
        )
    ).all()

    genres: Counter[str] = Counter()
    known: set[str] = set()
    for entry, title in rows:
        known.add(title.imdb_id)
        weight = 2 if entry.is_favorite else 1
        for genre in title.genres or []:
            genres[genre] += weight

    return [genre for genre, _ in genres.most_common(3)], known


async def recommend(
    db: AsyncSession, user_id: int, limit: int = 20
) -> tuple[list[Title], list[str], bool]:
    genres, known = await taste_profile(db, user_id)
    picks: list[Title] = []

    if genres:
        try:
            result = await imdb_service.search_titles(
                db,
                genres=genres,
                # Sorting by rating with no floor gives the shelf to titles a dozen people rated 10/10.
                min_votes=10_000,
                sort_by="USER_RATING",
                sort_order="DESC",
                limit=limit + len(known),
            )
            picks = [t for t in result["items"] if t.imdb_id not in known]
        except UpstreamError:
            picks = []

    if len(picks) < limit:
        # Cold start, or the genre search came back thin — top it up with the
        # popular rails so the shelf is never empty.
        seen = {t.imdb_id for t in picks} | known
        for section in ("popular_movies", "popular_series"):
            try:
                for title in await imdb_service.get_section(db, section, limit=limit):
                    if title.imdb_id not in seen:
                        picks.append(title)
                        seen.add(title.imdb_id)
            except UpstreamError:
                continue
            if len(picks) >= limit:
                break

    based_on = genres or ["محبوب‌ترین‌ها"]
    return picks[:limit], based_on, bool(genres)
