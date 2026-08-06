"""Sections 4.3 and 7.7 — the admin-only half of the API."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Query, Response, status
from sqlalchemy import delete, func, select

from app.core.deps import AdminUser, DbSession
from app.core.errors import AppError, NotFoundError
from app.db.models import (
    CustomListItem,
    Episode,
    EpisodeWatch,
    Rating,
    Report,
    ReportStatus,
    Review,
    Season,
    Title,
    User,
    UserTitle,
    utcnow,
)
from app.imdb import service as imdb_service
from app.schemas.admin import (
    AdminReportListResponse,
    AdminReportOut,
    AdminReviewListResponse,
    AdminReviewOut,
    AdminStats,
    AdminUserListResponse,
    AdminUserOut,
    AdminUserUpdate,
    CachedTitleListResponse,
    CachedTitleOut,
    ReportUpdate,
)
from app.schemas.review import ReviewOut
from app.services.stats import admin_stats

router = APIRouter(prefix="/admin", tags=["مدیریت سیستم"])


@router.get(
    "/users",
    response_model=AdminUserListResponse,
    summary="فهرست کاربران",
    responses={403: {"description": "فقط مدیر سیستم"}},
)
async def list_users(
    db: DbSession,
    _: AdminUser,
    q: Annotated[str | None, Query(description="جست‌وجو در نام، نام کاربری یا ایمیل")] = None,
    limit: Annotated[int, Query(ge=1, le=200)] = 50,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> AdminUserListResponse:
    statement = select(User)
    if q:
        pattern = f"%{q.lower()}%"
        statement = statement.where(
            func.lower(User.username).like(pattern)
            | func.lower(User.email).like(pattern)
            | func.lower(User.full_name).like(pattern)
        )

    total = int(
        (await db.execute(select(func.count()).select_from(statement.subquery()))).scalar_one()
    )
    rows = list(
        (
            await db.execute(statement.order_by(User.created_at.desc()).limit(limit).offset(offset))
        ).scalars()
    )

    review_counts = dict(
        (
            await db.execute(
                select(Review.user_id, func.count(Review.id)).group_by(Review.user_id)
            )
        ).all()
    )
    rating_counts = dict(
        (
            await db.execute(
                select(Rating.user_id, func.count(Rating.id)).group_by(Rating.user_id)
            )
        ).all()
    )

    items = []
    for row in rows:
        item = AdminUserOut.model_validate(row)
        item.reviews = int(review_counts.get(row.id, 0))
        item.ratings = int(rating_counts.get(row.id, 0))
        items.append(item)
    return AdminUserListResponse(items=items, total=total)


@router.patch(
    "/users/{user_id}",
    response_model=AdminUserOut,
    summary="فعال/غیرفعال کردن کاربر یا تغییر نقش",
    responses={400: {"description": "مدیر نمی‌تواند حساب خودش را تغییر دهد"}},
)
async def update_user(
    user_id: int, payload: AdminUserUpdate, db: DbSession, admin: AdminUser
) -> AdminUserOut:
    if user_id == admin.id:
        raise AppError(
            "مدیر نمی‌تواند وضعیت حساب خودش را تغییر دهد.", code="CANNOT_MODIFY_SELF"
        )

    user = await db.get(User, user_id)
    if user is None:
        raise NotFoundError("کاربر پیدا نشد.", code="USER_NOT_FOUND")

    if payload.is_active is not None:
        user.is_active = payload.is_active
    if payload.role is not None:
        user.role = payload.role.value
    await db.flush()
    return AdminUserOut.model_validate(user)


@router.get("/reviews", response_model=AdminReviewListResponse, summary="همهٔ نظرها")
async def list_all_reviews(
    db: DbSession,
    _: AdminUser,
    include_hidden: Annotated[bool, Query()] = True,
    limit: Annotated[int, Query(ge=1, le=200)] = 50,
) -> AdminReviewListResponse:
    statement = select(Review, Title.title).join(
        Title, Title.imdb_id == Review.title_id, isouter=True
    )
    if not include_hidden:
        statement = statement.where(Review.is_hidden.is_(False))

    rows = list((await db.execute(statement.order_by(Review.created_at.desc()).limit(limit))).all())
    total = int((await db.execute(select(func.count()).select_from(Review))).scalar_one())

    items = []
    for review, title_name in rows:
        item = AdminReviewOut.model_validate(review)
        item.title_name = title_name
        items.append(item)
    return AdminReviewListResponse(items=items, total=total)


@router.delete(
    "/reviews/{review_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="حذف نظر نامناسب",
    description="نظر پنهان می‌شود و دیگر در برنامه دیده نمی‌شود، اما برای پیگیری در پایگاه داده می‌ماند.",
)
async def hide_review(review_id: int, db: DbSession, _: AdminUser) -> Response:
    review = await db.get(Review, review_id)
    if review is None:
        raise NotFoundError("نظر پیدا نشد.", code="REVIEW_NOT_FOUND")
    review.is_hidden = True
    await db.flush()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get(
    "/reports", response_model=AdminReportListResponse, summary="گزارش‌های کاربران"
)
async def list_reports(
    db: DbSession,
    _: AdminUser,
    report_status: Annotated[str | None, Query(alias="status")] = None,
    limit: Annotated[int, Query(ge=1, le=200)] = 50,
) -> AdminReportListResponse:
    statement = select(Report)
    if report_status:
        statement = statement.where(Report.status == report_status)

    rows = list(
        (await db.execute(statement.order_by(Report.created_at.desc()).limit(limit))).scalars()
    )
    total = int((await db.execute(select(func.count()).select_from(Report))).scalar_one())

    items: list[AdminReportOut] = []
    for report in rows:
        reporter = await db.get(User, report.reporter_id)
        review = await db.get(Review, report.review_id) if report.review_id else None
        if review is not None:
            await db.refresh(review, ["user"])
        items.append(
            AdminReportOut(
                id=report.id,
                reason=report.reason,
                status=report.status,
                resolution_note=report.resolution_note,
                created_at=report.created_at,
                reporter_username=reporter.username if reporter else None,
                review=ReviewOut.model_validate(review) if review else None,
            )
        )
    return AdminReportListResponse(items=items, total=total)


@router.patch(
    "/reports/{report_id}",
    response_model=AdminReportOut,
    summary="رسیدگی به یک گزارش",
    description="وضعیت گزارش را ثبت می‌کند و در صورت نیاز نظر گزارش‌شده را پنهان می‌کند.",
)
async def resolve_report(
    report_id: int, payload: ReportUpdate, db: DbSession, _: AdminUser
) -> AdminReportOut:
    report = await db.get(Report, report_id)
    if report is None:
        raise NotFoundError("گزارش پیدا نشد.", code="REPORT_NOT_FOUND")

    report.status = payload.status.value
    report.resolution_note = payload.resolution_note
    report.resolved_at = utcnow()

    review = await db.get(Review, report.review_id) if report.review_id else None
    if payload.delete_review and review is not None:
        review.is_hidden = True
    await db.flush()
    if review is not None:
        await db.refresh(review, ["user"])

    reporter = await db.get(User, report.reporter_id)
    return AdminReportOut(
        id=report.id,
        reason=report.reason,
        status=report.status,
        resolution_note=report.resolution_note,
        created_at=report.created_at,
        reporter_username=reporter.username if reporter else None,
        review=ReviewOut.model_validate(review) if review else None,
    )


@router.get(
    "/titles",
    response_model=CachedTitleListResponse,
    summary="اطلاعات ذخیره‌شدهٔ فیلم‌ها و سریال‌ها",
)
async def list_cached_titles(
    db: DbSession,
    _: AdminUser,
    limit: Annotated[int, Query(ge=1, le=200)] = 50,
) -> CachedTitleListResponse:
    rows = list(
        (
            await db.execute(select(Title).order_by(Title.fetched_at.desc()).limit(limit))
        ).scalars()
    )
    tracked = dict(
        (
            await db.execute(
                select(UserTitle.title_id, func.count(UserTitle.id)).group_by(UserTitle.title_id)
            )
        ).all()
    )
    total = int((await db.execute(select(func.count()).select_from(Title))).scalar_one())

    items = []
    for row in rows:
        item = CachedTitleOut.model_validate(row)
        item.tracked_by = int(tracked.get(row.imdb_id, 0))
        items.append(item)
    return CachedTitleListResponse(items=items, total=total)


@router.post(
    "/titles/{imdb_id}/refresh",
    summary="به‌روزرسانی اجباری اطلاعات یک اثر از IMDb",
)
async def refresh_title(imdb_id: str, db: DbSession, _: AdminUser) -> CachedTitleOut:
    title = await imdb_service.get_title(db, imdb_id, force=True)
    return CachedTitleOut.model_validate(title)


@router.delete(
    "/titles/{imdb_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="پاک کردن اثر از حافظهٔ سرور",
    description=(
        "نسخهٔ ذخیره‌شدهٔ اثر و قسمت‌هایش را حذف می‌کند. "
        "توجه: رکوردهای تماشا، امتیاز و نظر مربوط به همین اثر هم پاک می‌شوند."
    ),
)
async def evict_title(imdb_id: str, db: DbSession, _: AdminUser) -> Response:
    title = await db.get(Title, imdb_id)
    if title is None:
        raise NotFoundError("این اثر در حافظه نیست.", code="TITLE_NOT_CACHED")

    await db.execute(delete(EpisodeWatch).where(EpisodeWatch.series_id == imdb_id))
    await db.execute(delete(Episode).where(Episode.series_id == imdb_id))
    await db.execute(delete(Season).where(Season.series_id == imdb_id))
    await db.execute(delete(UserTitle).where(UserTitle.title_id == imdb_id))
    await db.execute(delete(Rating).where(Rating.title_id == imdb_id))
    await db.execute(delete(Review).where(Review.title_id == imdb_id))
    await db.execute(delete(CustomListItem).where(CustomListItem.title_id == imdb_id))
    await db.delete(title)
    await db.flush()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/stats", response_model=AdminStats, summary="آمار کلی سامانه")
async def system_stats(db: DbSession, _: AdminUser) -> AdminStats:
    return AdminStats(**await admin_stats(db))
