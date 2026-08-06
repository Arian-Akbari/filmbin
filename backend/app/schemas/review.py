"""Ratings, reviews and reports (sections 5.13–5.15)."""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator


class ReviewAuthor(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    username: str
    full_name: str
    avatar_url: str | None = None


class ReviewCreate(BaseModel):
    model_config = ConfigDict(
        json_schema_extra={
            "example": {"text": "پایان‌بندی‌اش واقعاً غافلگیرکننده بود.", "has_spoiler": True}
        }
    )

    text: str = Field(min_length=1, max_length=4000)
    has_spoiler: bool = False

    @field_validator("text")
    @classmethod
    def _not_blank(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("متن نظر نمی‌تواند خالی باشد")
        return value


class ReviewOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    title_id: str
    text: str
    has_spoiler: bool
    created_at: datetime
    updated_at: datetime
    user: ReviewAuthor


class ReviewListResponse(BaseModel):
    items: list[ReviewOut]
    total: int
    hidden_spoilers: int = 0


class RatingRequest(BaseModel):
    """Section 5.13 — one to five stars."""

    model_config = ConfigDict(json_schema_extra={"example": {"score": 4}})

    score: int = Field(ge=1, le=5)


class RatingOut(BaseModel):
    imdb_id: str
    score: int
    user_rating_average: float | None = None
    user_rating_count: int = 0


class ReportCreate(BaseModel):
    review_id: int
    reason: str = Field(min_length=3, max_length=300)


class ReportOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    review_id: int | None
    reason: str
    status: str
    resolution_note: str | None = None
    created_at: datetime
