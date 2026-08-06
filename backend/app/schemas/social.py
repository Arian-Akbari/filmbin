"""Bonus social features: following, the activity feed and per-title chat."""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.schemas.review import ReviewAuthor
from app.schemas.title import TitleSummary


class FollowOut(BaseModel):
    username: str
    is_following: bool
    followers: int


class FeedItem(BaseModel):
    id: int
    type: str
    created_at: datetime
    user: ReviewAuthor
    title: TitleSummary | None = None
    payload: dict | None = None


class FeedResponse(BaseModel):
    items: list[FeedItem]


class ChatMessageIn(BaseModel):
    text: str = Field(min_length=1, max_length=1000)

    @field_validator("text")
    @classmethod
    def _not_blank(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("متن پیام نمی‌تواند خالی باشد")
        return value


class ChatMessageOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    room: str
    text: str
    created_at: datetime
    user: ReviewAuthor


class ChatHistoryResponse(BaseModel):
    items: list[ChatMessageOut]
