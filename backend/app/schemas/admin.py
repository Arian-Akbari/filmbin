"""Admin console shapes (sections 4.3, 7.7)."""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.db.models import ReportStatus, UserRole
from app.schemas.review import ReviewOut


class AdminUserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    full_name: str
    username: str
    email: str
    role: str
    is_active: bool
    created_at: datetime
    last_login_at: datetime | None = None
    reviews: int = 0
    ratings: int = 0


class AdminUserListResponse(BaseModel):
    items: list[AdminUserOut]
    total: int


class AdminUserUpdate(BaseModel):
    is_active: bool | None = None
    role: UserRole | None = None


class AdminReviewOut(ReviewOut):
    is_hidden: bool = False
    title_name: str | None = None


class AdminReviewListResponse(BaseModel):
    items: list[AdminReviewOut]
    total: int


class AdminReportOut(BaseModel):
    id: int
    reason: str
    status: str
    resolution_note: str | None = None
    created_at: datetime
    reporter_username: str | None = None
    review: ReviewOut | None = None


class AdminReportListResponse(BaseModel):
    items: list[AdminReportOut]
    total: int


class ReportUpdate(BaseModel):
    status: ReportStatus
    delete_review: bool = False
    resolution_note: str | None = Field(default=None, max_length=300)


class CachedTitleOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    imdb_id: str
    kind: str
    title: str
    year: int | None = None
    has_details: bool
    fetched_at: datetime
    tracked_by: int = 0


class CachedTitleListResponse(BaseModel):
    items: list[CachedTitleOut]
    total: int


class TrackedTitle(BaseModel):
    imdb_id: str
    title: str
    count: int


class AdminStats(BaseModel):
    users: int
    active_users: int
    admins: int
    cached_titles: int
    cached_episodes: int
    ratings: int
    reviews: int
    hidden_reviews: int
    lists: int
    pending_reports: int
    watch_entries: int
    episode_marks: int
    active_sessions: int
    imdb_circuit_open: bool
    most_tracked: list[TrackedTitle]
