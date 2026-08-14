"""Sections 5.1–5.3 — registration, sign-in, sessions and password recovery."""

from __future__ import annotations

import logging
from datetime import timedelta

from fastapi import APIRouter, Request, Response, status
from sqlalchemy import func, select

from app.core.config import settings
from app.core.deps import CurrentUser, DbSession
from app.core.errors import AppError, ConflictError, InvalidCredentialsError
from app.core.security import (
    create_access_token,
    generate_opaque_token,
    hash_password,
    hash_token,
    verify_password,
)
from app.db.models import PasswordReset, Session, User, as_utc, utcnow
from app.schemas.auth import (
    ForgotPasswordRequest,
    ForgotPasswordResponse,
    LoginRequest,
    LogoutRequest,
    RefreshRequest,
    RegisterRequest,
    ResetPasswordRequest,
    TokenResponse,
)
from app.schemas.user import UserOut
from app.services.stats import profile_summary

logger = logging.getLogger("filmbin.auth")
router = APIRouter(prefix="/auth", tags=["احراز هویت"])


async def _issue_tokens(
    db: DbSession, user: User, *, days: int, device: str | None
) -> TokenResponse:
    access_token, expires_at = create_access_token(user.id, user.role)
    refresh_token, digest = generate_opaque_token()
    refresh_expires = utcnow() + timedelta(days=days)

    db.add(
        Session(
            user_id=user.id,
            token_hash=digest,
            device=device,
            expires_at=refresh_expires,
        )
    )
    await db.flush()

    profile = UserOut.model_validate(user)
    profile.summary = profile.summary.model_copy(
        update=await profile_summary(db, user.id)
    )

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=int((expires_at - utcnow()).total_seconds()),
        refresh_expires_in=days * 24 * 3600,
        user=profile,
    )


@router.post(
    "/register",
    response_model=TokenResponse,
    status_code=status.HTTP_201_CREATED,
    summary="ثبت‌نام کاربر جدید",
    description=(
        "کاربر تازه را می‌سازد و بلافاصله وارد حساب می‌کند. "
        "ایمیل و نام کاربری باید یکتا باشند و رمز عبور دست‌کم ۸ نویسه."
    ),
    responses={
        409: {"description": "ایمیل یا نام کاربری تکراری است"},
        422: {"description": "اطلاعات ورودی معتبر نیست"},
    },
)
async def register(payload: RegisterRequest, db: DbSession, request: Request) -> TokenResponse:
    email = payload.email.lower().strip()
    username = payload.username.lower().strip()

    if (
        await db.execute(select(func.count()).select_from(User).where(User.email == email))
    ).scalar_one():
        raise ConflictError("این ایمیل قبلاً ثبت شده است.", code="EMAIL_TAKEN")
    if (
        await db.execute(
            select(func.count()).select_from(User).where(User.username == username)
        )
    ).scalar_one():
        raise ConflictError("این نام کاربری قبلاً گرفته شده است.", code="USERNAME_TAKEN")

    user = User(
        full_name=payload.full_name,
        username=username,
        email=email,
        password_hash=hash_password(payload.password),
        bio=payload.bio,
        avatar_url=payload.avatar_url,
        last_login_at=utcnow(),
    )
    db.add(user)
    await db.flush()

    return await _issue_tokens(
        db,
        user,
        days=settings.refresh_token_days,
        device=request.headers.get("user-agent"),
    )


@router.post(
    "/login",
    response_model=TokenResponse,
    summary="ورود به حساب کاربری",
    description=(
        "با ایمیل و رمز عبور وارد می‌شود. به‌صورت پیش‌فرض نشست تا ۳۰ روز معتبر است؛ "
        "با `remember_me: false` فقط یک روز."
    ),
    responses={401: {"description": "ایمیل یا رمز عبور نادرست"}},
)
async def login(payload: LoginRequest, db: DbSession, request: Request) -> TokenResponse:
    user = (
        await db.execute(select(User).where(User.email == payload.email.lower().strip()))
    ).scalar_one_or_none()

    if user is None or not verify_password(payload.password, user.password_hash):
        raise InvalidCredentialsError()
    if not user.is_active:
        raise AppError(
            "حساب کاربری شما غیرفعال شده است.",
            code="ACCOUNT_DISABLED",
            status_code=status.HTTP_403_FORBIDDEN,
        )

    user.last_login_at = utcnow()
    days = settings.refresh_token_days if payload.remember_me else settings.short_session_days
    return await _issue_tokens(
        db, user, days=days, device=payload.device or request.headers.get("user-agent")
    )


@router.post(
    "/refresh",
    response_model=TokenResponse,
    summary="تمدید نشست",
    description="توکن دسترسی تازه می‌گیرد و توکن تازه‌سازی را می‌چرخاند (توکن قبلی باطل می‌شود).",
    responses={401: {"description": "توکن تازه‌سازی نامعتبر یا منقضی است"}},
)
async def refresh(payload: RefreshRequest, db: DbSession) -> TokenResponse:
    digest = hash_token(payload.refresh_token)
    session = (
        await db.execute(select(Session).where(Session.token_hash == digest))
    ).scalar_one_or_none()

    now = utcnow()
    if (
        session is None
        or session.revoked_at is not None
        or (as_utc(session.expires_at) or now) <= now
    ):
        raise AppError(
            "نشست شما معتبر نیست. دوباره وارد شوید.",
            code="INVALID_REFRESH_TOKEN",
            status_code=status.HTTP_401_UNAUTHORIZED,
        )

    user = await db.get(User, session.user_id)
    if user is None or not user.is_active:
        raise AppError(
            "حساب کاربری در دسترس نیست.",
            code="ACCOUNT_DISABLED",
            status_code=status.HTTP_401_UNAUTHORIZED,
        )

    lifetime = (as_utc(session.expires_at) - as_utc(session.created_at)).days or 1
    session.revoked_at = now
    return await _issue_tokens(db, user, days=lifetime, device=session.device)


@router.post(
    "/logout",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="خروج امن",
    description="فقط نشست همین دستگاه را باطل می‌کند؛ ورودهای دیگر دست‌نخورده می‌مانند.",
)
async def logout(payload: LogoutRequest, db: DbSession, user: CurrentUser) -> Response:
    session = (
        await db.execute(
            select(Session).where(
                Session.token_hash == hash_token(payload.refresh_token),
                Session.user_id == user.id,
            )
        )
    ).scalar_one_or_none()
    if session is not None:
        session.revoked_at = utcnow()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post(
    "/password/forgot",
    response_model=ForgotPasswordResponse,
    summary="درخواست بازیابی رمز عبور",
    description=(
        "برای ایمیل ثبت‌شده یک توکن یک‌بارمصرف می‌سازد. "
        "پاسخ برای ایمیل‌های ناموجود هم موفق است تا فهرست کاربران لو نرود."
    ),
)
async def forgot_password(
    payload: ForgotPasswordRequest, db: DbSession
) -> ForgotPasswordResponse:
    message = "اگر این ایمیل در سامانه ثبت شده باشد، لینک بازیابی برایش ارسال می‌شود."
    user = (
        await db.execute(select(User).where(User.email == payload.email.lower().strip()))
    ).scalar_one_or_none()
    if user is None:
        # The caller still gets a success message, so the log is the only place this shows up.
        logger.info("password reset requested for unknown email %s", payload.email)
        return ForgotPasswordResponse(message=message)

    token, digest = generate_opaque_token()
    db.add(
        PasswordReset(
            user_id=user.id,
            token_hash=digest,
            expires_at=utcnow() + timedelta(minutes=settings.password_reset_minutes),
        )
    )
    await db.flush()
    if settings.expose_reset_token:
        # Stands in for the email we do not send yet; never log a live token in production.
        logger.info("password reset token for %s: %s", user.email, token)
    else:
        logger.info("password reset requested for user %s", user.id)

    return ForgotPasswordResponse(
        message=message,
        reset_token=token if settings.expose_reset_token else None,
    )


@router.post(
    "/password/reset",
    response_model=ForgotPasswordResponse,
    summary="ثبت رمز عبور تازه",
    description="با توکن بازیابی رمز را عوض می‌کند و همهٔ نشست‌های قبلی را می‌بندد.",
    responses={400: {"description": "توکن نامعتبر، استفاده‌شده یا منقضی"}},
)
async def reset_password(
    payload: ResetPasswordRequest, db: DbSession
) -> ForgotPasswordResponse:
    reset = (
        await db.execute(
            select(PasswordReset).where(PasswordReset.token_hash == hash_token(payload.token))
        )
    ).scalar_one_or_none()

    now = utcnow()
    if (
        reset is None
        or reset.used_at is not None
        or (as_utc(reset.expires_at) or now) <= now
    ):
        raise AppError(
            "لینک بازیابی معتبر نیست یا منقضی شده است.",
            code="INVALID_RESET_TOKEN",
            status_code=status.HTTP_400_BAD_REQUEST,
        )

    user = await db.get(User, reset.user_id)
    if user is None:
        raise AppError("کاربر یافت نشد.", code="USER_NOT_FOUND", status_code=404)

    user.password_hash = hash_password(payload.password)
    reset.used_at = now
    # Changing a password signs every device out (section 8.3).
    for session in (
        await db.execute(
            select(Session).where(Session.user_id == user.id, Session.revoked_at.is_(None))
        )
    ).scalars():
        session.revoked_at = now

    return ForgotPasswordResponse(message="رمز عبور با موفقیت تغییر کرد.")
