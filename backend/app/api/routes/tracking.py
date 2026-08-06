"""Sections 5.9–5.12, 5.16 — watch status, episode marks, progress, watchlist."""

from __future__ import annotations

from typing import Annotated, Literal

from fastapi import APIRouter, Query, Response, status
from sqlalchemy import func, select

from app.core.deps import CurrentUser, DbSession
from app.core.errors import NotFoundError
from app.db.models import (
    ActivityType,
    Episode,
    EpisodeWatch,
    Title,
    UserTitle,
    WatchStatus,
    utcnow,
)
from app.imdb import service as imdb_service
from app.schemas.title import ProgressOut
from app.schemas.tracking import FavoriteOut, StatusOut, StatusRequest, WatchlistResponse
from app.services import titles as title_service
from app.services.activity import record
from app.services.progress import compute_progress, episode_totals, watched_count

router = APIRouter(prefix="/titles", tags=["فهرست تماشا"])
watchlist_router = APIRouter(prefix="/watchlist", tags=["فهرست تماشا"])


async def _entry(db: DbSession, user_id: int, title: Title) -> UserTitle:
    entry = (
        await db.execute(
            select(UserTitle).where(
                UserTitle.user_id == user_id, UserTitle.title_id == title.imdb_id
            )
        )
    ).scalar_one_or_none()
    if entry is None:
        entry = UserTitle(user_id=user_id, title_id=title.imdb_id)
        db.add(entry)
        await db.flush()
    return entry


async def _refresh_derived_status(db: DbSession, user_id: int, title: Title) -> None:
    """Keep the status in step with the episode marks (section 5.10 → 5.9)."""
    if title.kind != "series":
        return
    if not await imdb_service.episodes_are_complete(db, title):
        # Deciding "finished" against a half-mirrored season list would be wrong.
        await imdb_service.sync_all_episodes(db, title.imdb_id)
    total = await episode_totals(db, title.imdb_id)
    if total == 0:
        return

    watched = await watched_count(db, user_id, title.imdb_id)
    entry = await _entry(db, user_id, title)

    if watched >= total:
        if entry.status != WatchStatus.WATCHED.value:
            entry.status = WatchStatus.WATCHED.value
            entry.finished_at = utcnow()
            await record(db, user_id, ActivityType.FINISHED, title_id=title.imdb_id)
    elif watched > 0:
        if entry.status in (None, WatchStatus.WATCHED.value):
            entry.status = WatchStatus.WATCHING.value
            entry.finished_at = None
    await db.flush()


async def _progress_payload(db: DbSession, user_id: int, title: Title) -> ProgressOut:
    return ProgressOut(**await compute_progress(db, user_id, title))


@router.put(
    "/{imdb_id}/status",
    response_model=StatusOut,
    summary="ثبت وضعیت تماشا",
    description=(
        "یکی از وضعیت‌های «قصد دارم تماشا کنم»، «در حال تماشا»، «مشاهده شده»، "
        "«متوقف شده» و «رهاشده» را ثبت می‌کند. ثبت دوبارهٔ همان وضعیت رکورد تکراری نمی‌سازد."
    ),
    responses={401: {"description": "نیاز به ورود"}, 404: {"description": "اثر پیدا نشد"}},
)
async def set_status(
    imdb_id: str, payload: StatusRequest, db: DbSession, user: CurrentUser
) -> StatusOut:
    title = await imdb_service.get_title(db, imdb_id)
    entry = await _entry(db, user.id, title)

    changed = entry.status != payload.status.value
    entry.status = payload.status.value
    entry.finished_at = utcnow() if payload.status == WatchStatus.WATCHED else None
    await db.flush()

    if changed:
        await record(
            db,
            user.id,
            ActivityType.STATUS_CHANGED,
            title_id=imdb_id,
            payload={"status": entry.status},
        )

    return StatusOut(
        imdb_id=imdb_id,
        status=entry.status,
        is_favorite=entry.is_favorite,
        updated_at=entry.updated_at,
    )


@router.delete(
    "/{imdb_id}/status",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="حذف وضعیت تماشا",
)
async def clear_status(imdb_id: str, db: DbSession, user: CurrentUser) -> Response:
    entry = (
        await db.execute(
            select(UserTitle).where(
                UserTitle.user_id == user.id, UserTitle.title_id == imdb_id
            )
        )
    ).scalar_one_or_none()
    if entry is not None:
        if entry.is_favorite:
            entry.status = None
            entry.finished_at = None
        else:
            await db.delete(entry)
        await db.flush()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.put(
    "/{imdb_id}/favorite",
    response_model=FavoriteOut,
    summary="افزودن به علاقه‌مندی‌ها",
    description="فهرست علاقه‌مندی‌ها مستقل از وضعیت تماشاست (بخش ۵.۱۶).",
)
async def add_favorite(imdb_id: str, db: DbSession, user: CurrentUser) -> FavoriteOut:
    title = await imdb_service.get_title(db, imdb_id)
    entry = await _entry(db, user.id, title)
    entry.is_favorite = True
    await db.flush()
    return FavoriteOut(imdb_id=imdb_id, is_favorite=True)


@router.delete(
    "/{imdb_id}/favorite", response_model=FavoriteOut, summary="حذف از علاقه‌مندی‌ها"
)
async def remove_favorite(imdb_id: str, db: DbSession, user: CurrentUser) -> FavoriteOut:
    entry = (
        await db.execute(
            select(UserTitle).where(
                UserTitle.user_id == user.id, UserTitle.title_id == imdb_id
            )
        )
    ).scalar_one_or_none()
    if entry is not None:
        entry.is_favorite = False
        if entry.status is None:
            await db.delete(entry)
        await db.flush()
    return FavoriteOut(imdb_id=imdb_id, is_favorite=False)


async def _load_episode(db: DbSession, imdb_id: str, episode_id: str) -> Episode:
    episode = (
        await db.execute(
            select(Episode).where(
                Episode.imdb_id == episode_id, Episode.series_id == imdb_id
            )
        )
    ).scalar_one_or_none()
    if episode is None:
        # The client may know about an episode we have not mirrored yet.
        await imdb_service.sync_all_episodes(db, imdb_id)
        episode = (
            await db.execute(
                select(Episode).where(
                    Episode.imdb_id == episode_id, Episode.series_id == imdb_id
                )
            )
        ).scalar_one_or_none()
    if episode is None:
        raise NotFoundError("این قسمت پیدا نشد.", code="EPISODE_NOT_FOUND", detail=episode_id)
    return episode


@router.put(
    "/{imdb_id}/episodes/{episode_id}/watch",
    response_model=ProgressOut,
    summary="علامت‌گذاری یک قسمت به‌عنوان دیده‌شده",
    description="ثبت تکراری همان قسمت شمارش را دوباره بالا نمی‌برد (بخش ۸.۴).",
)
async def mark_episode(
    imdb_id: str, episode_id: str, db: DbSession, user: CurrentUser
) -> ProgressOut:
    title = await imdb_service.get_title(db, imdb_id)
    episode = await _load_episode(db, imdb_id, episode_id)

    exists = (
        await db.execute(
            select(EpisodeWatch).where(
                EpisodeWatch.user_id == user.id, EpisodeWatch.episode_id == episode_id
            )
        )
    ).scalar_one_or_none()
    if exists is None:
        db.add(
            EpisodeWatch(
                user_id=user.id,
                episode_id=episode.imdb_id,
                series_id=imdb_id,
                season_number=episode.season_number,
                episode_number=episode.episode_number,
                runtime_minutes=episode.runtime_minutes,
            )
        )
        await db.flush()

    await _refresh_derived_status(db, user.id, title)
    return await _progress_payload(db, user.id, title)


@router.delete(
    "/{imdb_id}/episodes/{episode_id}/watch",
    response_model=ProgressOut,
    summary="برداشتن علامت دیده‌شدن یک قسمت",
)
async def unmark_episode(
    imdb_id: str, episode_id: str, db: DbSession, user: CurrentUser
) -> ProgressOut:
    title = await imdb_service.get_title(db, imdb_id)
    watch = (
        await db.execute(
            select(EpisodeWatch).where(
                EpisodeWatch.user_id == user.id, EpisodeWatch.episode_id == episode_id
            )
        )
    ).scalar_one_or_none()
    if watch is not None:
        await db.delete(watch)
        await db.flush()

    await _refresh_derived_status(db, user.id, title)
    return await _progress_payload(db, user.id, title)


@router.put(
    "/{imdb_id}/seasons/{season}/watch",
    response_model=ProgressOut,
    summary="علامت‌گذاری کل یک فصل",
)
async def mark_season(
    imdb_id: str, season: int, db: DbSession, user: CurrentUser
) -> ProgressOut:
    title = await imdb_service.get_title(db, imdb_id)
    episodes = await imdb_service.get_episodes(db, imdb_id, season)
    if not episodes:
        raise NotFoundError("این فصل پیدا نشد.", code="SEASON_NOT_FOUND", detail=season)

    already = {
        row
        for row in (
            await db.execute(
                select(EpisodeWatch.episode_id).where(
                    EpisodeWatch.user_id == user.id,
                    EpisodeWatch.episode_id.in_([e.imdb_id for e in episodes]),
                )
            )
        ).scalars()
    }
    for episode in episodes:
        if episode.imdb_id in already:
            continue
        db.add(
            EpisodeWatch(
                user_id=user.id,
                episode_id=episode.imdb_id,
                series_id=imdb_id,
                season_number=episode.season_number,
                episode_number=episode.episode_number,
                runtime_minutes=episode.runtime_minutes,
            )
        )
    await db.flush()

    await _refresh_derived_status(db, user.id, title)
    return await _progress_payload(db, user.id, title)


@router.delete(
    "/{imdb_id}/seasons/{season}/watch",
    response_model=ProgressOut,
    summary="برداشتن علامت کل یک فصل",
)
async def unmark_season(
    imdb_id: str, season: int, db: DbSession, user: CurrentUser
) -> ProgressOut:
    title = await imdb_service.get_title(db, imdb_id)
    for watch in (
        await db.execute(
            select(EpisodeWatch).where(
                EpisodeWatch.user_id == user.id,
                EpisodeWatch.series_id == imdb_id,
                EpisodeWatch.season_number == season,
            )
        )
    ).scalars():
        await db.delete(watch)
    await db.flush()

    await _refresh_derived_status(db, user.id, title)
    return await _progress_payload(db, user.id, title)


@router.get(
    "/{imdb_id}/progress",
    response_model=ProgressOut,
    summary="درصد پیشرفت تماشا",
    description=(
        "درصد قسمت‌های دیده‌شده به همراه رنگ نوار پیشرفت: "
        "بی‌رنگ، زرد، سبز، بنفش یا قرمز (بخش ۵.۱۱)."
    ),
)
async def progress(imdb_id: str, db: DbSession, user: CurrentUser) -> ProgressOut:
    title = await imdb_service.get_title(db, imdb_id)
    return await _progress_payload(db, user.id, title)


@watchlist_router.get(
    "",
    response_model=WatchlistResponse,
    summary="فهرست تماشای من",
    description="همهٔ آثار ثبت‌شده به همراه شمارش هر وضعیت؛ با پارامتر `status` فیلتر می‌شود (بخش ۵.۱۲).",
)
async def watchlist(
    db: DbSession,
    user: CurrentUser,
    status_filter: Annotated[
        Literal["plan_to_watch", "watching", "watched", "paused", "dropped"] | None,
        Query(alias="status", description="فقط یک وضعیت"),
    ] = None,
    kind: Annotated[Literal["movie", "series"] | None, Query()] = None,
) -> WatchlistResponse:
    counts = {
        row[0]: int(row[1])
        for row in (
            await db.execute(
                select(UserTitle.status, func.count(UserTitle.id))
                .where(UserTitle.user_id == user.id, UserTitle.status.is_not(None))
                .group_by(UserTitle.status)
            )
        ).all()
    }

    statement = (
        select(Title)
        .join(UserTitle, UserTitle.title_id == Title.imdb_id)
        .where(UserTitle.user_id == user.id, UserTitle.status.is_not(None))
        .order_by(UserTitle.updated_at.desc())
    )
    if status_filter:
        statement = statement.where(UserTitle.status == status_filter)
    if kind:
        statement = statement.where(Title.kind == kind)

    rows = list((await db.execute(statement)).scalars())
    items = await title_service.summarize(db, rows, user.id)
    return WatchlistResponse(items=items, counts=counts, total=len(items))


@watchlist_router.get(
    "/favorites",
    response_model=WatchlistResponse,
    summary="آثار موردعلاقه",
    description="فهرست جداگانهٔ علاقه‌مندی‌ها (بخش ۵.۱۶).",
)
async def favorites(db: DbSession, user: CurrentUser) -> WatchlistResponse:
    rows = list(
        (
            await db.execute(
                select(Title)
                .join(UserTitle, UserTitle.title_id == Title.imdb_id)
                .where(UserTitle.user_id == user.id, UserTitle.is_favorite.is_(True))
                .order_by(UserTitle.updated_at.desc())
            )
        ).scalars()
    )
    items = await title_service.summarize(db, rows, user.id)
    return WatchlistResponse(items=items, counts={"favorites": len(items)}, total=len(items))
