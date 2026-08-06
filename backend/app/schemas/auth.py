"""Request/response bodies for authentication (sections 5.1–5.3, 7.8)."""

from __future__ import annotations

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

from app.schemas.user import UserOut

USERNAME_PATTERN = r"^[a-zA-Z0-9_]{3,30}$"


class RegisterRequest(BaseModel):
    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "full_name": "آرین اکبری",
                "username": "arian",
                "email": "arian@example.com",
                "password": "Str0ngPass!",
                "bio": "دانشجوی مهندسی کامپیوتر",
            }
        }
    )

    full_name: str = Field(min_length=2, max_length=120)
    username: str = Field(pattern=USERNAME_PATTERN)
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    bio: str | None = Field(default=None, max_length=300)
    avatar_url: str | None = Field(default=None, max_length=500)

    @field_validator("full_name")
    @classmethod
    def _strip(cls, value: str) -> str:
        value = value.strip()
        if len(value) < 2:
            raise ValueError("نام باید حداقل ۲ نویسه باشد")
        return value


class LoginRequest(BaseModel):
    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "email": "arian@example.com",
                "password": "Str0ngPass!",
                "remember_me": True,
            }
        }
    )

    email: EmailStr
    password: str = Field(min_length=1)
    # Section 5.2 — a month by default, a single day when the user opts out.
    remember_me: bool = True
    device: str | None = Field(default=None, max_length=120)


class RefreshRequest(BaseModel):
    refresh_token: str = Field(min_length=10)


class LogoutRequest(BaseModel):
    refresh_token: str = Field(min_length=10)


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class ResetPasswordRequest(BaseModel):
    token: str = Field(min_length=10)
    password: str = Field(min_length=8, max_length=128)


class ForgotPasswordResponse(BaseModel):
    message: str
    # Present only while `expose_reset_token` is on (development). In production
    # the token travels by email and never appears in an HTTP response.
    reset_token: str | None = None


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int
    refresh_expires_in: int
    user: UserOut
