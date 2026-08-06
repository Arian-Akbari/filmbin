"""User-facing profile shapes (sections 5.1, 5.4, 5.19)."""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator

USERNAME_PATTERN = r"^[a-zA-Z0-9_]{3,30}$"


class UserSummary(BaseModel):
    """The three counters every profile shows automatically (section 5.1)."""

    watched_movies: int = 0
    followed_series: int = 0
    favorites: int = 0


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    full_name: str
    username: str
    email: str
    avatar_url: str | None = None
    bio: str | None = None
    role: str
    is_active: bool = True
    created_at: datetime
    summary: UserSummary = UserSummary()


class PublicUserOut(BaseModel):
    """Someone else's profile — no email, no role, no account flags."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    full_name: str
    username: str
    avatar_url: str | None = None
    bio: str | None = None
    created_at: datetime
    summary: UserSummary = UserSummary()
    followers: int = 0
    following: int = 0
    is_following: bool = False


class UpdateProfileRequest(BaseModel):
    full_name: str | None = Field(default=None, min_length=2, max_length=120)
    username: str | None = Field(default=None, pattern=USERNAME_PATTERN)
    bio: str | None = Field(default=None, max_length=300)

    @field_validator("full_name", "bio")
    @classmethod
    def _strip(cls, value: str | None) -> str | None:
        return value.strip() if value else value


class ChangePasswordRequest(BaseModel):
    current_password: str = Field(min_length=1)
    new_password: str = Field(min_length=8, max_length=128)


class AvatarResponse(BaseModel):
    avatar_url: str


class GenreCount(BaseModel):
    genre: str
    count: int


class StatsOut(BaseModel):
    """Section 5.19 — the activity dashboard."""

    watched_movies: int
    watched_series: int
    watched_episodes: int
    total_watch_minutes: int
    total_watch_hours: float
    favorite_genres: list[GenreCount]
    top_genre: str | None
    average_rating: float | None
    ratings_count: int
    reviews_count: int
    favorites_count: int
    lists_count: int
    status_breakdown: dict[str, int]
