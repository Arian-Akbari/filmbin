"""Sections 5.4, 5.19 — profiles, avatars, statistics, following."""

from __future__ import annotations

import secrets
from pathlib import Path

from fastapi import APIRouter, File, Request, Response, UploadFile, status
from sqlalchemy import func, select

from app.core.config import settings
from app.core.deps import CurrentUser, DbSession, OptionalUser
from app.core.errors import (
    AppError,
    ConflictError,
    InvalidCredentialsError,
    NotFoundError,
    ValidationError,
)
from app.core.security import hash_password, verify_password
from app.db.models import Follow, User
from app.schemas.social import FollowOut
from app.schemas.user import (
    AvatarResponse,
    ChangePasswordRequest,
    PublicUserOut,
    StatsOut,
    UpdateProfileRequest,
    UserOut,
)
from app.services.stats import profile_summary, user_stats

router = APIRouter(prefix="/users", tags=["کاربران"])

ALLOWED_IMAGE_TYPES = {"image/png": ".png", "image/jpeg": ".jpg", "image/webp": ".webp"}


async def _follow_counts(db: DbSession, user_id: int) -> tuple[int, int]:
    """Followers and following, the pair every profile shape carries."""
    followers = (
        await db.execute(
            select(func.count()).select_from(Follow).where(Follow.following_id == user_id)
        )
    ).scalar_one()
    following = (
        await db.execute(
            select(func.count()).select_from(Follow).where(Follow.follower_id == user_id)
        )
    ).scalar_one()
    return int(followers), int(following)


async def _with_summary(db: DbSession, user: User) -> UserOut:
    profile = UserOut.model_validate(user)
    profile.summary = profile.summary.model_copy(update=await profile_summary(db, user.id))
    profile.followers, profile.following = await _follow_counts(db, user.id)
    return profile


async def _load_user(db: DbSession, username: str) -> User:
    user = (
        await db.execute(select(User).where(User.username == username.lower()))
    ).scalar_one_or_none()
    if user is None or not user.is_active:
        raise NotFoundError("چنین کاربری وجود ندارد.", code="USER_NOT_FOUND")
    return user


@router.get(
    "/me",
    response_model=UserOut,
    summary="اطلاعات پروفایل خودم",
    description="پروفایل کاربر واردشده به همراه شمارنده‌های خودکار (فیلم‌های دیده‌شده، سریال‌های دنبال‌شده، علاقه‌مندی‌ها).",
)
async def me(db: DbSession, user: CurrentUser) -> UserOut:
    return await _with_summary(db, user)


@router.patch(
    "/me",
    response_model=UserOut,
    summary="ویرایش پروفایل",
    responses={409: {"description": "نام کاربری تکراری است"}},
)
async def update_me(
    payload: UpdateProfileRequest, db: DbSession, user: CurrentUser
) -> UserOut:
    if payload.username and payload.username.lower() != user.username:
        taken = (
            await db.execute(
                select(func.count())
                .select_from(User)
                .where(User.username == payload.username.lower())
            )
        ).scalar_one()
        if taken:
            raise ConflictError("این نام کاربری قبلاً گرفته شده است.", code="USERNAME_TAKEN")
        user.username = payload.username.lower()

    if payload.full_name is not None:
        user.full_name = payload.full_name
    if payload.bio is not None:
        user.bio = payload.bio

    await db.flush()
    return await _with_summary(db, user)


@router.post(
    "/me/password",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="تغییر رمز عبور",
    responses={401: {"description": "رمز فعلی نادرست است"}},
)
async def change_password(
    payload: ChangePasswordRequest, db: DbSession, user: CurrentUser
) -> Response:
    if not verify_password(payload.current_password, user.password_hash):
        raise InvalidCredentialsError("رمز عبور فعلی درست نیست.")
    user.password_hash = hash_password(payload.new_password)
    await db.flush()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post(
    "/me/avatar",
    response_model=AvatarResponse,
    summary="بارگذاری تصویر پروفایل",
    responses={422: {"description": "قالب تصویر پشتیبانی نمی‌شود"}},
)
async def upload_avatar(
    request: Request,
    db: DbSession,
    user: CurrentUser,
    file: UploadFile = File(..., description="تصویر PNG، JPEG یا WebP — حداکثر ۲ مگابایت"),
) -> AvatarResponse:
    extension = ALLOWED_IMAGE_TYPES.get((file.content_type or "").lower())
    if extension is None:
        raise ValidationError(
            "فقط تصویر PNG، JPEG یا WebP پذیرفته می‌شود.", code="UNSUPPORTED_IMAGE"
        )

    content = await file.read()
    if len(content) > settings.max_avatar_bytes:
        raise AppError(
            "حجم تصویر بیش از حد مجاز است.",
            code="FILE_TOO_LARGE",
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail={"max_bytes": settings.max_avatar_bytes},
        )

    folder = Path(settings.media_dir) / "avatars"
    folder.mkdir(parents=True, exist_ok=True)
    name = f"{user.id}-{secrets.token_hex(6)}{extension}"
    (folder / name).write_bytes(content)

    base = settings.public_base_url or str(request.base_url).rstrip("/")
    user.avatar_url = f"{base}/media/avatars/{name}"
    await db.flush()
    return AvatarResponse(avatar_url=user.avatar_url)


@router.get(
    "/me/stats",
    response_model=StatsOut,
    summary="آمار فعالیت کاربر",
    description="تعداد فیلم و سریال دیده‌شده، قسمت‌های تماشاشده، مجموع زمان تماشا، ژانر موردعلاقه و میانگین امتیازها (بخش ۵.۱۹).",
)
async def my_stats(db: DbSession, user: CurrentUser) -> StatsOut:
    return StatsOut(**await user_stats(db, user.id))


@router.get(
    "/{username}",
    response_model=PublicUserOut,
    summary="پروفایل عمومی یک کاربر",
    responses={404: {"description": "کاربر پیدا نشد"}},
)
async def public_profile(
    username: str, db: DbSession, viewer: OptionalUser
) -> PublicUserOut:
    user = await _load_user(db, username)

    followers, following = await _follow_counts(db, user.id)

    is_following = False
    if viewer is not None:
        is_following = bool(
            (
                await db.execute(
                    select(func.count())
                    .select_from(Follow)
                    .where(Follow.follower_id == viewer.id, Follow.following_id == user.id)
                )
            ).scalar_one()
        )

    profile = PublicUserOut.model_validate(user)
    profile.summary = profile.summary.model_copy(update=await profile_summary(db, user.id))
    profile.followers = int(followers)
    profile.following = int(following)
    profile.is_following = is_following
    return profile


@router.put(
    "/{username}/follow",
    response_model=FollowOut,
    summary="دنبال کردن کاربر",
    responses={400: {"description": "نمی‌توان خود را دنبال کرد"}},
)
async def follow(username: str, db: DbSession, user: CurrentUser) -> FollowOut:
    target = await _load_user(db, username)
    if target.id == user.id:
        raise AppError("نمی‌توانید خودتان را دنبال کنید.", code="CANNOT_FOLLOW_SELF")

    existing = (
        await db.execute(
            select(Follow).where(
                Follow.follower_id == user.id, Follow.following_id == target.id
            )
        )
    ).scalar_one_or_none()
    if existing is None:
        db.add(Follow(follower_id=user.id, following_id=target.id))
        await db.flush()

    followers = (
        await db.execute(
            select(func.count()).select_from(Follow).where(Follow.following_id == target.id)
        )
    ).scalar_one()
    return FollowOut(username=target.username, is_following=True, followers=int(followers))


@router.delete(
    "/{username}/follow", response_model=FollowOut, summary="لغو دنبال کردن"
)
async def unfollow(username: str, db: DbSession, user: CurrentUser) -> FollowOut:
    target = await _load_user(db, username)
    existing = (
        await db.execute(
            select(Follow).where(
                Follow.follower_id == user.id, Follow.following_id == target.id
            )
        )
    ).scalar_one_or_none()
    if existing is not None:
        await db.delete(existing)
        await db.flush()

    followers = (
        await db.execute(
            select(func.count()).select_from(Follow).where(Follow.following_id == target.id)
        )
    ).scalar_one()
    return FollowOut(username=target.username, is_following=False, followers=int(followers))
