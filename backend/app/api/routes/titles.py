"""Sections 5.5–5.8, 5.18 — everything the app reads about films and series."""

from __future__ import annotations

from typing import Annotated, Literal

from fastapi import APIRouter, Query
from sqlalchemy import select

from app.core.deps import CurrentUser, DbSession, OptionalUser
from app.db.models import EpisodeWatch
from app.imdb import service as imdb_service
from app.schemas.title import (
    DiscoverResponse,
    DiscoverSection,
    EpisodeOut,
    PersonOut,
    RecommendationResponse,
    SearchResponse,
    SeasonOut,
    TitleDetail,
)
from app.services import titles as title_service
from app.services.recommendations import recommend

router = APIRouter(prefix="/titles", tags=["فیلم و سریال"])

SORTS: dict[str, tuple[str, str]] = {
    "popularity": ("POPULARITY", "ASC"),
    "rating": ("USER_RATING", "DESC"),
    "newest": ("RELEASE_DATE", "DESC"),
    "oldest": ("RELEASE_DATE", "ASC"),
    "votes": ("USER_RATING_COUNT", "DESC"),
}

SECTION_TITLES = {
    "popular_movies": "فیلم‌های محبوب",
    "popular_series": "سریال‌های محبوب",
    "new_releases": "آثار جدید",
    "top_rated": "آثار با امتیاز بالا",
    "top_rated_series": "سریال‌های برتر",
}


@router.get(
    "/search",
    response_model=SearchResponse,
    summary="جست‌وجوی فیلم و سریال",
    description=(
        "جست‌وجو بر اساس نام اثر، نام بازیگر یا کارگردان، ژانر و سال انتشار. "
        "نتیجه‌ها صفحه‌بندی می‌شوند و روی سرور کش می‌شوند تا درخواست تکراری به IMDb نرود."
    ),
    responses={503: {"description": "سرویس IMDb در دسترس نیست"}},
)
async def search(
    db: DbSession,
    user: OptionalUser,
    q: Annotated[str | None, Query(description="بخشی از نام اثر", max_length=120)] = None,
    person: Annotated[
        str | None, Query(description="نام بازیگر یا کارگردان", max_length=120)
    ] = None,
    kind: Annotated[Literal["movie", "series"] | None, Query(description="نوع اثر")] = None,
    genre: Annotated[list[str] | None, Query(description="ژانر — قابل تکرار")] = None,
    year_from: Annotated[int | None, Query(ge=1900, le=2100)] = None,
    year_to: Annotated[int | None, Query(ge=1900, le=2100)] = None,
    sort: Annotated[str, Query(description="popularity | rating | newest | oldest | votes")] = "popularity",
    limit: Annotated[int, Query(ge=1, le=50)] = 20,
    cursor: Annotated[str | None, Query(description="نشانگر صفحهٔ بعد")] = None,
) -> SearchResponse:
    person_ids: list[str] = []
    if person:
        people = await imdb_service.search_people(db, person, limit=3)
        person_ids = [p["id"] for p in people if p.get("id")]

    sort_by, sort_order = SORTS.get(sort, SORTS["popularity"])
    result = await imdb_service.search_titles(
        db,
        query=q,
        kind=kind,
        genres=genre,
        year_from=year_from,
        year_to=year_to,
        person_ids=person_ids,
        sort_by=sort_by,
        sort_order=sort_order,
        limit=limit,
        cursor=cursor,
    )

    items = await title_service.summarize(
        db, result["items"], user.id if user else None
    )
    return SearchResponse(
        items=items,
        total=result["total"],
        next_cursor=result["next_cursor"],
        stale=result["stale"],
    )


@router.get(
    "/people",
    response_model=list[PersonOut],
    summary="پیشنهاد نام بازیگر و کارگردان",
    description="برای تکمیل خودکار فیلد «بازیگر/کارگردان» در صفحهٔ جست‌وجو.",
)
async def people(
    db: DbSession,
    q: Annotated[str, Query(min_length=2, max_length=120)],
    limit: Annotated[int, Query(ge=1, le=20)] = 8,
) -> list[PersonOut]:
    return [PersonOut(**person) for person in await imdb_service.search_people(db, q, limit)]


@router.get(
    "/discover",
    response_model=DiscoverResponse,
    summary="ردیف‌های صفحهٔ اصلی",
    description="فیلم‌های محبوب، سریال‌های محبوب، آثار جدید و آثار با امتیاز بالا (بخش ۵.۱۸).",
)
async def discover(
    db: DbSession,
    user: OptionalUser,
    limit: Annotated[int, Query(ge=1, le=30)] = 15,
) -> DiscoverResponse:
    sections: list[DiscoverSection] = []
    for key, label in SECTION_TITLES.items():
        try:
            titles = await imdb_service.get_section(db, key, limit=limit)
        except Exception:  # noqa: BLE001 — one broken rail must not blank the page
            titles = []
        if not titles:
            continue
        sections.append(
            DiscoverSection(
                key=key,
                title=label,
                items=await title_service.summarize(db, titles, user.id if user else None),
            )
        )
    return DiscoverResponse(sections=sections)


@router.get(
    "/recommended",
    response_model=RecommendationResponse,
    summary="پیشنهادهای شخصی‌سازی‌شده",
    description="بر پایهٔ ژانرهای پرتکرار در فهرست و علاقه‌مندی‌های کاربر ساخته می‌شود.",
)
async def recommended(
    db: DbSession,
    user: CurrentUser,
    limit: Annotated[int, Query(ge=1, le=30)] = 20,
) -> RecommendationResponse:
    picks, based_on, personalized = await recommend(db, user.id, limit=limit)
    return RecommendationResponse(
        items=await title_service.summarize(db, picks, user.id),
        based_on=based_on,
        personalized=personalized,
    )


@router.get(
    "/{imdb_id}",
    response_model=TitleDetail,
    summary="جزئیات فیلم یا سریال",
    description=(
        "همهٔ اطلاعات صفحهٔ اثر: پوستر، خلاصه، ژانر، کشور سازنده، کارگردان، بازیگران، "
        "امتیاز IMDb و امتیاز کاربران برنامه. برای سریال‌ها فهرست فصل‌ها و وضعیت پخش هم می‌آید."
    ),
    responses={404: {"description": "اثر پیدا نشد"}, 503: {"description": "سرویس IMDb در دسترس نیست"}},
)
async def title_detail(imdb_id: str, db: DbSession, user: OptionalUser) -> TitleDetail:
    title = await imdb_service.get_title(db, imdb_id)
    return await title_service.detail(db, title, user.id if user else None)


@router.get(
    "/{imdb_id}/seasons",
    response_model=list[SeasonOut],
    summary="فهرست فصل‌های یک سریال",
)
async def seasons(imdb_id: str, db: DbSession) -> list[SeasonOut]:
    rows = await imdb_service.get_seasons(db, imdb_id)
    return [SeasonOut(number=row.number, episode_count=row.episode_count) for row in rows]


@router.get(
    "/{imdb_id}/seasons/{season}/episodes",
    response_model=list[EpisodeOut],
    summary="قسمت‌های یک فصل",
    description="شمارهٔ فصل و قسمت، عنوان، تاریخ انتشار، مدت زمان، خلاصه و وضعیت دیده‌شدن (بخش ۵.۸).",
)
async def episodes(
    imdb_id: str, season: int, db: DbSession, user: OptionalUser
) -> list[EpisodeOut]:
    rows = await imdb_service.get_episodes(db, imdb_id, season)

    watched: set[str] = set()
    if user is not None and rows:
        watched = {
            row
            for row in (
                await db.execute(
                    select(EpisodeWatch.episode_id).where(
                        EpisodeWatch.user_id == user.id,
                        EpisodeWatch.episode_id.in_([r.imdb_id for r in rows]),
                    )
                )
            ).scalars()
        }

    return [
        EpisodeOut.model_validate(row).model_copy(
            update={"is_watched": row.imdb_id in watched}
        )
        for row in rows
    ]
