"""Standard error envelope (section 7.9).

Every failure leaves the API in the same shape::

    {
      "error": {
        "status": 404,
        "code": "TITLE_NOT_FOUND",
        "message": "اثر موردنظر پیدا نشد.",
        "detail": "tt0000000",
        "fields": {"email": "ایمیل تکراری است."}
      }
    }

The mobile client only ever has to understand `code` to react, and can show
`message` to the user directly — the messages are already in Persian.
"""

from __future__ import annotations

from typing import Any

from fastapi import FastAPI, Request, status
from fastapi.encoders import jsonable_encoder
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException


class AppError(Exception):
    """Base class for every error the API raises on purpose."""

    status_code: int = status.HTTP_400_BAD_REQUEST
    code: str = "BAD_REQUEST"
    message: str = "درخواست نامعتبر است."

    def __init__(
        self,
        message: str | None = None,
        *,
        detail: Any = None,
        fields: dict[str, str] | None = None,
        code: str | None = None,
        status_code: int | None = None,
    ) -> None:
        self.message = message or self.message
        self.detail = detail
        self.fields = fields
        if code:
            self.code = code
        if status_code:
            self.status_code = status_code
        super().__init__(self.message)

    def to_payload(self) -> dict[str, Any]:
        error: dict[str, Any] = {
            "status": self.status_code,
            "code": self.code,
            "message": self.message,
        }
        if self.detail is not None:
            error["detail"] = self.detail
        if self.fields:
            error["fields"] = self.fields
        return {"error": error}


class ValidationError(AppError):
    status_code = status.HTTP_422_UNPROCESSABLE_ENTITY
    code = "VALIDATION_ERROR"
    message = "اطلاعات ارسال‌شده معتبر نیست."


class AuthenticationError(AppError):
    status_code = status.HTTP_401_UNAUTHORIZED
    code = "UNAUTHENTICATED"
    message = "برای این کار باید وارد حساب کاربری شوید."


class InvalidCredentialsError(AuthenticationError):
    code = "INVALID_CREDENTIALS"
    message = "ایمیل یا رمز عبور درست نیست."


class TokenExpiredError(AuthenticationError):
    code = "TOKEN_EXPIRED"
    message = "نشست شما منقضی شده است. دوباره وارد شوید."


class PermissionDeniedError(AppError):
    status_code = status.HTTP_403_FORBIDDEN
    code = "PERMISSION_DENIED"
    message = "به این بخش دسترسی ندارید."


class NotFoundError(AppError):
    status_code = status.HTTP_404_NOT_FOUND
    code = "NOT_FOUND"
    message = "موردی که دنبالش بودید پیدا نشد."


class TitleNotFoundError(NotFoundError):
    code = "TITLE_NOT_FOUND"
    message = "فیلم یا سریال موردنظر پیدا نشد."


class ConflictError(AppError):
    status_code = status.HTTP_409_CONFLICT
    code = "CONFLICT"
    message = "این مورد از قبل وجود دارد."


class RateLimitedError(AppError):
    status_code = status.HTTP_429_TOO_MANY_REQUESTS
    code = "RATE_LIMITED"
    message = "تعداد درخواست‌ها زیاد است. کمی بعد دوباره تلاش کنید."


class UpstreamError(AppError):
    """IMDb answered with an error, or did not answer at all."""

    status_code = status.HTTP_502_BAD_GATEWAY
    code = "UPSTREAM_ERROR"
    message = "دریافت اطلاعات از سرویس IMDb با خطا مواجه شد."


class UpstreamUnavailableError(UpstreamError):
    status_code = status.HTTP_503_SERVICE_UNAVAILABLE
    code = "UPSTREAM_UNAVAILABLE"
    message = "سرویس اطلاعاتی در دسترس نیست."


_FIELD_LABELS = {
    "email": "ایمیل",
    "password": "رمز عبور",
    "username": "نام کاربری",
    "full_name": "نام و نام خانوادگی",
    "score": "امتیاز",
    "text": "متن نظر",
    "status": "وضعیت تماشا",
}


def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(AppError)
    async def _app_error(_: Request, exc: AppError) -> JSONResponse:
        return JSONResponse(status_code=exc.status_code, content=exc.to_payload())

    @app.exception_handler(RequestValidationError)
    async def _validation(_: Request, exc: RequestValidationError) -> JSONResponse:
        fields: dict[str, str] = {}
        for err in exc.errors():
            loc = [str(p) for p in err["loc"] if p not in ("body", "query", "path")]
            name = loc[-1] if loc else "input"
            label = _FIELD_LABELS.get(name, name)
            fields[name] = f"{label}: {err['msg']}"
        error = ValidationError(fields=fields, detail=jsonable_encoder(exc.errors()))
        return JSONResponse(status_code=error.status_code, content=error.to_payload())

    @app.exception_handler(StarletteHTTPException)
    async def _http(_: Request, exc: StarletteHTTPException) -> JSONResponse:
        mapping = {
            401: ("UNAUTHENTICATED", "برای این کار باید وارد حساب کاربری شوید."),
            403: ("PERMISSION_DENIED", "به این بخش دسترسی ندارید."),
            404: ("NOT_FOUND", "این آدرس روی سرور وجود ندارد."),
            405: ("METHOD_NOT_ALLOWED", "این متد برای این آدرس مجاز نیست."),
        }
        code, message = mapping.get(exc.status_code, ("HTTP_ERROR", str(exc.detail)))
        error = AppError(message, code=code, status_code=exc.status_code)
        return JSONResponse(
            status_code=exc.status_code,
            content=error.to_payload(),
            headers=getattr(exc, "headers", None),
        )

    @app.exception_handler(Exception)
    async def _unhandled(_: Request, exc: Exception) -> JSONResponse:
        error = AppError(
            "خطای پیش‌بینی‌نشده‌ای در سرور رخ داد.",
            code="INTERNAL_ERROR",
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(exc) if __debug__ else None,
        )
        return JSONResponse(status_code=error.status_code, content=error.to_payload())
