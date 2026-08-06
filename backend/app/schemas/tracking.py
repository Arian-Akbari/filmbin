"""Watch state, watchlist, personal lists (sections 5.9, 5.12, 5.16, 5.17)."""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.db.models import WatchStatus
from app.schemas.title import TitleSummary


class StatusRequest(BaseModel):
    model_config = ConfigDict(json_schema_extra={"example": {"status": "watching"}})

    status: WatchStatus


class StatusOut(BaseModel):
    imdb_id: str
    status: str | None = None
    is_favorite: bool = False
    updated_at: datetime | None = None


class FavoriteOut(BaseModel):
    imdb_id: str
    is_favorite: bool


class WatchlistResponse(BaseModel):
    items: list[TitleSummary]
    counts: dict[str, int]
    total: int


class ListCreate(BaseModel):
    model_config = ConfigDict(
        json_schema_extra={
            "example": {"name": "بهترین فیلم‌های اکشن", "description": "انتخاب شخصی", "is_public": True}
        }
    )

    name: str = Field(min_length=1, max_length=80)
    description: str | None = Field(default=None, max_length=300)
    is_public: bool = True

    @field_validator("name")
    @classmethod
    def _not_blank(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("نام فهرست نمی‌تواند خالی باشد")
        return value


class ListUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=80)
    description: str | None = Field(default=None, max_length=300)
    is_public: bool | None = None

    @field_validator("name")
    @classmethod
    def _not_blank(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = value.strip()
        if not value:
            raise ValueError("نام فهرست نمی‌تواند خالی باشد")
        return value


class ListOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    description: str | None = None
    is_public: bool
    item_count: int = 0
    owner_username: str | None = None
    created_at: datetime
    updated_at: datetime


class ListDetail(ListOut):
    items: list[TitleSummary] = []


class ListItemCreate(BaseModel):
    imdb_id: str = Field(pattern=r"^tt\d{5,12}$")
