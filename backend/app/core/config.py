"""Application settings, loaded from environment / .env file."""

from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

BASE_DIR = Path(__file__).resolve().parents[2]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=str(BASE_DIR / ".env"), env_file_encoding="utf-8", extra="ignore"
    )

    # --- app -------------------------------------------------------------
    app_name: str = "FilmBin API"
    app_version: str = "1.0.0"
    debug: bool = False
    api_prefix: str = "/api/v1"

    # --- database --------------------------------------------------------
    # SQLite by default; swap for postgresql+asyncpg://... without code changes.
    database_url: str = f"sqlite+aiosqlite:///{BASE_DIR / 'filmbin.db'}"
    db_echo: bool = False

    # --- auth ------------------------------------------------------------
    jwt_secret: str = "dev-secret-change-me-in-production"
    jwt_algorithm: str = "HS256"
    access_token_minutes: int = 30
    # Section 5.2: a logged-in user should not have to log in again for a month,
    # unless they explicitly asked for a shorter session.
    refresh_token_days: int = 30
    short_session_days: int = 1
    password_reset_minutes: int = 30
    # Development convenience: return the reset token in the HTTP response
    # instead of emailing it. Must be false in production.
    expose_reset_token: bool = True

    # --- imdb ------------------------------------------------------------
    imdb_graphql_url: str = "https://api.graphql.imdb.com/"
    imdb_timeout_seconds: float = 15.0
    imdb_max_retries: int = 2
    # How long a cached IMDb payload stays fresh before we re-fetch.
    cache_ttl_details_hours: int = 72
    cache_ttl_search_hours: int = 12
    cache_ttl_chart_hours: int = 6
    # Circuit breaker: after N consecutive upstream failures, stop calling IMDb
    # for `breaker_cooldown_seconds` and serve whatever is cached.
    breaker_failure_threshold: int = 5
    breaker_cooldown_seconds: int = 60

    # --- limits ----------------------------------------------------------
    rate_limit_requests: int = 120
    rate_limit_window_seconds: int = 60
    auth_rate_limit_requests: int = 10
    auth_rate_limit_window_seconds: int = 60
    max_avatar_bytes: int = 2 * 1024 * 1024

    # --- media -----------------------------------------------------------
    media_dir: Path = BASE_DIR / "media"
    public_base_url: str = ""

    @property
    def is_sqlite(self) -> bool:
        return self.database_url.startswith("sqlite")


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
