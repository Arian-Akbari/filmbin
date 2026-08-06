"""FilmBin backend — the dedicated server of the advanced project model.

The mobile app never talks to IMDb directly (section 9.2). It talks here, and
this service owns the upstream integration, the cache, the user data and the
access rules.
"""

from __future__ import annotations

import logging
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.openapi.utils import get_openapi
from fastapi.staticfiles import StaticFiles
from starlette.middleware.gzip import GZipMiddleware

from app.api.router import api_router
from app.core.config import settings
from app.core.errors import register_exception_handlers
from app.core.rate_limit import RateLimitMiddleware
from app.db.base import engine, init_db
from app.imdb.client import imdb_client

logging.basicConfig(
    level=logging.DEBUG if settings.debug else logging.INFO,
    format="%(asctime)s %(levelname)-7s %(name)s — %(message)s",
)
logger = logging.getLogger("filmbin")

DESCRIPTION = """
رابط برنامه‌نویسی «فیلم‌بین» — سرویس اختصاصی اپلیکیشن مدیریت و دنبال کردن فیلم و سریال.

**معماری:** اپلیکیشن موبایل → بک‌اند اختصاصی → IMDb

بک‌اند مسئول ارتباط با IMDb، استانداردسازی داده‌ها، ذخیرهٔ موقت آن‌ها، مدیریت کاربران،
فهرست‌های شخصی، امتیازها، نظرها و کنترل دسترسی است.

### احراز هویت
پس از ورود، هدر `Authorization: Bearer <access_token>` را روی درخواست‌ها بگذارید.
توکن دسترسی کوتاه‌عمر است و با `POST /api/v1/auth/refresh` تازه می‌شود.

### قالب خطاها
همهٔ خطاها یک شکل دارند:

```json
{
  "error": {
    "status": 404,
    "code": "TITLE_NOT_FOUND",
    "message": "فیلم یا سریال موردنظر پیدا نشد.",
    "detail": "tt0000000"
  }
}
```
"""

TAGS_METADATA = [
    {"name": "سلامت سرویس", "description": "بررسی در دسترس بودن سرویس و پایگاه داده."},
    {"name": "احراز هویت", "description": "ثبت‌نام، ورود، خروج، تمدید نشست و بازیابی رمز عبور."},
    {"name": "کاربران", "description": "پروفایل، تصویر، آمار فعالیت و دنبال کردن کاربران."},
    {"name": "فیلم و سریال", "description": "جست‌وجو، جزئیات اثر، فصل‌ها و قسمت‌ها، ردیف‌های صفحهٔ اصلی."},
    {"name": "فهرست تماشا", "description": "وضعیت تماشا، علاقه‌مندی‌ها، قسمت‌های دیده‌شده و درصد پیشرفت."},
    {"name": "امتیاز و نظر", "description": "ستاره‌دهی، نظرها، اسپویل و گزارش محتوای نامناسب."},
    {"name": "فهرست‌های شخصی", "description": "ساخت و مدیریت فهرست‌های دلخواه کاربر."},
    {"name": "اجتماعی", "description": "خوراک فعالیت و گفت‌وگوی زندهٔ هر اثر."},
    {"name": "مدیریت سیستم", "description": "ابزارهای مدیر: کاربران، نظرها، گزارش‌ها و آمار کلی."},
]


@asynccontextmanager
async def lifespan(app: FastAPI):
    Path(settings.media_dir).mkdir(parents=True, exist_ok=True)
    await init_db()
    await imdb_client.start()
    logger.info("%s %s is up", settings.app_name, settings.app_version)
    yield
    await imdb_client.close()
    await engine.dispose()


app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    description=DESCRIPTION,
    openapi_tags=TAGS_METADATA,
    lifespan=lifespan,
    contact={"name": "آرین اکبری — ۴۰۱۱۰۵۵۸۳", "url": "https://github.com/"},
    license_info={"name": "دانشگاه صنعتی شریف — پروژهٔ درس برنامه‌سازی موبایل"},
)

app.add_middleware(GZipMiddleware, minimum_size=1024)
app.add_middleware(RateLimitMiddleware)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["X-RateLimit-Limit", "X-RateLimit-Remaining", "Retry-After"],
)

register_exception_handlers(app)
app.include_router(api_router, prefix=settings.api_prefix)

Path(settings.media_dir).mkdir(parents=True, exist_ok=True)
app.mount("/media", StaticFiles(directory=str(settings.media_dir)), name="media")


def custom_openapi() -> dict:
    """Adds the bearer scheme by hand — the token is read from the raw header,
    so FastAPI cannot infer it from a dependency."""
    if app.openapi_schema:
        return app.openapi_schema

    schema = get_openapi(
        title=app.title,
        version=app.version,
        description=app.description,
        routes=app.routes,
        tags=TAGS_METADATA,
        contact=app.contact,
        license_info=app.license_info,
    )
    schema.setdefault("components", {}).setdefault("securitySchemes", {})["bearerAuth"] = {
        "type": "http",
        "scheme": "bearer",
        "bearerFormat": "JWT",
        "description": "توکن دسترسی دریافتی از /auth/login",
    }
    schema["security"] = [{"bearerAuth": []}]
    app.openapi_schema = schema
    return schema


app.openapi = custom_openapi


@app.get("/", include_in_schema=False)
async def root() -> dict:
    return {
        "name": settings.app_name,
        "version": settings.app_version,
        "docs": "/docs",
        "openapi": "/openapi.json",
        "api": settings.api_prefix,
    }
