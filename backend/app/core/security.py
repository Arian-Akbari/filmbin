"""Password hashing and JWT handling (section 7.6, 8.3).

Passwords never touch the database in clear text — bcrypt with a per-password
salt. Refresh tokens are random 256-bit strings; only their SHA-256 digest is
stored, so a database leak cannot be replayed against the API.
"""

from __future__ import annotations

import hashlib
import secrets
from datetime import UTC, datetime, timedelta
from typing import Any, Literal

import bcrypt
import jwt

from app.core.config import settings
from app.core.errors import AuthenticationError, TokenExpiredError

TokenType = Literal["access", "refresh"]
_BCRYPT_MAX_BYTES = 72  # bcrypt truncates beyond this; we pre-hash instead.


def _prepare(password: str) -> bytes:
    raw = password.encode("utf-8")
    if len(raw) > _BCRYPT_MAX_BYTES:
        raw = hashlib.sha256(raw).hexdigest().encode("ascii")
    return raw


def hash_password(password: str) -> str:
    return bcrypt.hashpw(_prepare(password), bcrypt.gensalt()).decode("ascii")


def verify_password(password: str, password_hash: str) -> bool:
    try:
        return bcrypt.checkpw(_prepare(password), password_hash.encode("ascii"))
    except ValueError:
        return False


def create_access_token(user_id: int, role: str) -> tuple[str, datetime]:
    expires_at = datetime.now(UTC) + timedelta(minutes=settings.access_token_minutes)
    payload = {
        "sub": str(user_id),
        "role": role,
        "type": "access",
        "iat": int(datetime.now(UTC).timestamp()),
        "exp": int(expires_at.timestamp()),
        "jti": secrets.token_hex(8),
    }
    token = jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)
    return token, expires_at


def decode_access_token(token: str) -> dict[str, Any]:
    try:
        payload = jwt.decode(
            token, settings.jwt_secret, algorithms=[settings.jwt_algorithm]
        )
    except jwt.ExpiredSignatureError as exc:
        raise TokenExpiredError() from exc
    except jwt.PyJWTError as exc:
        raise AuthenticationError("توکن ارسالی معتبر نیست.", code="INVALID_TOKEN") from exc
    if payload.get("type") != "access":
        raise AuthenticationError("نوع توکن درست نیست.", code="INVALID_TOKEN")
    return payload


def generate_opaque_token() -> tuple[str, str]:
    """Return (clear_token, sha256_digest). Only the digest is persisted."""
    token = secrets.token_urlsafe(32)
    return token, hash_token(token)


def hash_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()
