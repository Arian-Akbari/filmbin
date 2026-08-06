"""Shared FastAPI dependencies: DB session, current user, role guards."""

from __future__ import annotations

from typing import Annotated

from fastapi import Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AuthenticationError, PermissionDeniedError
from app.core.security import decode_access_token
from app.db.base import get_session
from app.db.models import User

DbSession = Annotated[AsyncSession, Depends(get_session)]


def _bearer_token(request: Request) -> str | None:
    header = request.headers.get("Authorization") or ""
    scheme, _, token = header.partition(" ")
    if scheme.lower() != "bearer" or not token.strip():
        return None
    return token.strip()


async def get_current_user(request: Request, db: DbSession) -> User:
    token = _bearer_token(request)
    if not token:
        raise AuthenticationError()
    payload = decode_access_token(token)
    user = await db.get(User, int(payload["sub"]))
    if user is None:
        raise AuthenticationError("کاربر این توکن دیگر وجود ندارد.", code="USER_NOT_FOUND")
    if not user.is_active:
        raise PermissionDeniedError("حساب کاربری شما غیرفعال شده است.", code="ACCOUNT_DISABLED")
    return user


async def get_optional_user(request: Request, db: DbSession) -> User | None:
    """Guest-friendly endpoints (section 4.1) use this: browsing works signed
    out, but a signed-in caller also gets their own state attached."""
    if not _bearer_token(request):
        return None
    try:
        return await get_current_user(request, db)
    except AuthenticationError:
        return None


async def get_admin_user(
    user: Annotated[User, Depends(get_current_user)],
) -> User:
    if not user.is_admin:
        raise PermissionDeniedError("این بخش فقط برای مدیر سیستم است.")
    return user


CurrentUser = Annotated[User, Depends(get_current_user)]
OptionalUser = Annotated[User | None, Depends(get_optional_user)]
AdminUser = Annotated[User, Depends(get_admin_user)]
