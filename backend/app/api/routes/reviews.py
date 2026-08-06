"""Sections 5.13–5.15 — star ratings, written reviews, spoilers and reports."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Query, Response, status
from sqlalchemy import func, select

from app.core.deps import CurrentUser, DbSession, OptionalUser
from app.core.errors import NotFoundError, PermissionDeniedError
from app.db.models import ActivityType, Rating, Report, Review, User, utcnow
from app.imdb import service as imdb_service
from app.schemas.review import (
    RatingOut,
    RatingRequest,
    ReportCreate,
    ReportOut,
    ReviewCreate,
    ReviewListResponse,
    ReviewOut,
)
from app.services.activity import record

router = APIRouter(prefix="/titles", tags=["امتیاز و نظر"])
standalone_router = APIRouter(tags=["امتیاز و نظر"])


@router.post(
    "/{imdb_id}/rating",
    response_model=RatingOut,
    summary="ثبت یا ویرایش امتیاز",
    description="امتیاز کیفی از ۱ تا ۵ ستاره. ارسال دوباره امتیاز قبلی را ویرایش می‌کند (بخش ۵.۱۳).",
    responses={401: {"description": "نیاز به ورود"}, 422: {"description": "امتیاز باید بین ۱ تا ۵ باشد"}},
)
async def rate(
    imdb_id: str, payload: RatingRequest, db: DbSession, user: CurrentUser
) -> RatingOut:
    await imdb_service.get_title(db, imdb_id)

    rating = (
        await db.execute(
            select(Rating).where(Rating.user_id == user.id, Rating.title_id == imdb_id)
        )
    ).scalar_one_or_none()
    if rating is None:
        rating = Rating(user_id=user.id, title_id=imdb_id, score=payload.score)
        db.add(rating)
    else:
        rating.score = payload.score
    await db.flush()

    await record(
        db, user.id, ActivityType.RATED, title_id=imdb_id, payload={"score": payload.score}
    )

    row = (
        await db.execute(
            select(func.avg(Rating.score), func.count(Rating.id)).where(
                Rating.title_id == imdb_id
            )
        )
    ).one()
    return RatingOut(
        imdb_id=imdb_id,
        score=payload.score,
        user_rating_average=round(float(row[0]), 2) if row[0] is not None else None,
        user_rating_count=int(row[1] or 0),
    )


@router.delete(
    "/{imdb_id}/rating",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="حذف امتیاز",
)
async def unrate(imdb_id: str, db: DbSession, user: CurrentUser) -> Response:
    rating = (
        await db.execute(
            select(Rating).where(Rating.user_id == user.id, Rating.title_id == imdb_id)
        )
    ).scalar_one_or_none()
    if rating is not None:
        await db.delete(rating)
        await db.flush()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get(
    "/{imdb_id}/reviews",
    response_model=ReviewListResponse,
    summary="نظرهای ثبت‌شده برای یک اثر",
    description=(
        "هر نظر شامل متن، نام کاربر، تصویر کاربر، تاریخ ثبت و وضعیت اسپویل است. "
        "با `hide_spoilers=true` نظرهای اسپویل‌دار کنار گذاشته می‌شوند."
    ),
)
async def list_reviews(
    imdb_id: str,
    db: DbSession,
    hide_spoilers: Annotated[bool, Query(description="کنار گذاشتن نظرهای اسپویل‌دار")] = False,
    limit: Annotated[int, Query(ge=1, le=100)] = 50,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> ReviewListResponse:
    base = select(Review).where(Review.title_id == imdb_id, Review.is_hidden.is_(False))

    spoilers = int(
        (
            await db.execute(
                select(func.count())
                .select_from(Review)
                .where(
                    Review.title_id == imdb_id,
                    Review.is_hidden.is_(False),
                    Review.has_spoiler.is_(True),
                )
            )
        ).scalar_one()
    )

    statement = base
    if hide_spoilers:
        statement = statement.where(Review.has_spoiler.is_(False))

    total = int(
        (
            await db.execute(
                select(func.count()).select_from(statement.subquery())
            )
        ).scalar_one()
    )
    rows = list(
        (
            await db.execute(
                statement.order_by(Review.created_at.desc()).limit(limit).offset(offset)
            )
        ).scalars()
    )

    return ReviewListResponse(
        items=[ReviewOut.model_validate(row) for row in rows],
        total=total,
        hidden_spoilers=spoilers if hide_spoilers else 0,
    )


@router.post(
    "/{imdb_id}/reviews",
    response_model=ReviewOut,
    status_code=status.HTTP_201_CREATED,
    summary="ثبت نظر",
    description=(
        "هر کاربر برای هر اثر یک نظر دارد؛ ارسال دوباره همان نظر را ویرایش می‌کند "
        "تا ثبت تکراری پیش نیاید (بخش ۸.۴). با `has_spoiler` نظر اسپویل‌دار علامت می‌خورد."
    ),
    responses={401: {"description": "نیاز به ورود"}, 422: {"description": "متن نظر خالی است"}},
)
async def write_review(
    imdb_id: str, payload: ReviewCreate, db: DbSession, user: CurrentUser
) -> ReviewOut:
    await imdb_service.get_title(db, imdb_id)

    review = (
        await db.execute(
            select(Review).where(Review.user_id == user.id, Review.title_id == imdb_id)
        )
    ).scalar_one_or_none()
    if review is None:
        review = Review(
            user_id=user.id,
            title_id=imdb_id,
            text=payload.text,
            has_spoiler=payload.has_spoiler,
        )
        db.add(review)
    else:
        review.text = payload.text
        review.has_spoiler = payload.has_spoiler
        review.is_hidden = False
    await db.flush()
    await db.refresh(review, ["user"])

    await record(
        db,
        user.id,
        ActivityType.REVIEWED,
        title_id=imdb_id,
        payload={"has_spoiler": payload.has_spoiler},
    )
    return ReviewOut.model_validate(review)


@standalone_router.delete(
    "/reviews/{review_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="حذف نظر خودم",
    responses={403: {"description": "این نظر متعلق به شما نیست"}},
)
async def delete_review(review_id: int, db: DbSession, user: CurrentUser) -> Response:
    review = await db.get(Review, review_id)
    if review is None:
        raise NotFoundError("نظر پیدا نشد.", code="REVIEW_NOT_FOUND")
    if review.user_id != user.id and not user.is_admin:
        raise PermissionDeniedError("فقط نویسندهٔ نظر می‌تواند آن را حذف کند.")

    await db.delete(review)
    await db.flush()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@standalone_router.post(
    "/reports",
    response_model=ReportOut,
    status_code=status.HTTP_201_CREATED,
    summary="گزارش نظر نامناسب",
    description="گزارش برای بررسی به کارتابل مدیر سیستم می‌رود (بخش ۴.۳).",
)
async def create_report(
    payload: ReportCreate, db: DbSession, user: CurrentUser
) -> ReportOut:
    review = await db.get(Review, payload.review_id)
    if review is None:
        raise NotFoundError("نظر پیدا نشد.", code="REVIEW_NOT_FOUND")

    existing = (
        await db.execute(
            select(Report).where(
                Report.reporter_id == user.id,
                Report.review_id == payload.review_id,
                Report.status == "pending",
            )
        )
    ).scalar_one_or_none()
    if existing is not None:
        return ReportOut.model_validate(existing)

    report = Report(reporter_id=user.id, review_id=payload.review_id, reason=payload.reason)
    db.add(report)
    await db.flush()
    return ReportOut.model_validate(report)


@standalone_router.get(
    "/reviews/mine",
    response_model=ReviewListResponse,
    summary="همهٔ نظرهای من",
)
async def my_reviews(db: DbSession, user: CurrentUser) -> ReviewListResponse:
    rows = list(
        (
            await db.execute(
                select(Review)
                .where(Review.user_id == user.id, Review.is_hidden.is_(False))
                .order_by(Review.updated_at.desc())
            )
        ).scalars()
    )
    return ReviewListResponse(
        items=[ReviewOut.model_validate(row) for row in rows], total=len(rows)
    )
