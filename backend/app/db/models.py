"""Server-side data model (section 7.4).

Two families of tables live here:

* **Mirror tables** (`titles`, `seasons`, `episodes`, `imdb_cache`) — a local copy
  of what IMDb told us, so repeat requests never leave the server and an IMDb
  outage degrades instead of breaking (sections 7.5 and 8.4).
* **Domain tables** (everything else) — users and everything they produce:
  watch state, episode marks, ratings, reviews, lists, reports, social graph.
"""

from __future__ import annotations

import enum
from datetime import UTC, datetime

from sqlalchemy import (
    Boolean,
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    JSON,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy import TypeDecorator
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


def utcnow() -> datetime:
    return datetime.now(UTC)


def as_utc(moment: datetime | None) -> datetime | None:
    """SQLite hands back naive datetimes; make them comparable again."""
    if moment is None:
        return None
    return moment if moment.tzinfo else moment.replace(tzinfo=UTC)


class UtcDateTime(TypeDecorator):
    """A timestamp that is always timezone-aware on the way out.

    SQLite has no timezone type, so SQLAlchemy hands back naive datetimes even
    for ``UtcDateTime(timezone=True)``. Serialising those drops the offset, and a
    client reading «2026-07-28T19:03» as local time shows a review posted a
    second ago as «۳ ساعت پیش». Stamping UTC here fixes it once, for every
    column, instead of at each call site.
    """

    impl = DateTime
    cache_ok = True

    def process_bind_param(self, value: datetime | None, dialect: object) -> datetime | None:
        return as_utc(value)

    def process_result_value(
        self, value: datetime | None, dialect: object
    ) -> datetime | None:
        return as_utc(value)


class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(
        UtcDateTime(timezone=True), default=utcnow, nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        UtcDateTime(timezone=True), default=utcnow, onupdate=utcnow, nullable=False
    )


# --------------------------------------------------------------------------
# enums
# --------------------------------------------------------------------------


class UserRole(str, enum.Enum):
    USER = "user"
    ADMIN = "admin"


class TitleKind(str, enum.Enum):
    MOVIE = "movie"
    SERIES = "series"


class WatchStatus(str, enum.Enum):
    """Section 5.9. «موردعلاقه» is a flag rather than a state, so a title can be
    both *watching* and *favorite* at the same time (section 5.16)."""

    PLAN_TO_WATCH = "plan_to_watch"
    WATCHING = "watching"
    WATCHED = "watched"
    PAUSED = "paused"
    DROPPED = "dropped"


class ReportStatus(str, enum.Enum):
    PENDING = "pending"
    RESOLVED = "resolved"
    REJECTED = "rejected"


class ActivityType(str, enum.Enum):
    RATED = "rated"
    REVIEWED = "reviewed"
    STATUS_CHANGED = "status_changed"
    FINISHED = "finished"
    LIST_CREATED = "list_created"
    FOLLOWED = "followed"


# --------------------------------------------------------------------------
# users & auth
# --------------------------------------------------------------------------


class User(Base, TimestampMixin):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    full_name: Mapped[str] = mapped_column(String(120), nullable=False)
    username: Mapped[str] = mapped_column(String(40), unique=True, index=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(120), nullable=False)
    avatar_url: Mapped[str | None] = mapped_column(String(500))
    bio: Mapped[str | None] = mapped_column(String(300))
    role: Mapped[str] = mapped_column(String(20), default=UserRole.USER.value)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    last_login_at: Mapped[datetime | None] = mapped_column(UtcDateTime(timezone=True))

    sessions: Mapped[list[Session]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )

    @property
    def is_admin(self) -> bool:
        return self.role == UserRole.ADMIN.value


class Session(Base):
    """One refresh token = one signed-in device (section 5.2)."""

    __tablename__ = "sessions"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    token_hash: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    device: Mapped[str | None] = mapped_column(String(120))
    expires_at: Mapped[datetime] = mapped_column(UtcDateTime(timezone=True))
    revoked_at: Mapped[datetime | None] = mapped_column(UtcDateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(
        UtcDateTime(timezone=True), default=utcnow
    )

    user: Mapped[User] = relationship(back_populates="sessions")


class PasswordReset(Base):
    __tablename__ = "password_resets"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    token_hash: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    expires_at: Mapped[datetime] = mapped_column(UtcDateTime(timezone=True))
    used_at: Mapped[datetime | None] = mapped_column(UtcDateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(
        UtcDateTime(timezone=True), default=utcnow
    )


# --------------------------------------------------------------------------
# IMDb mirror
# --------------------------------------------------------------------------


class Title(Base):
    __tablename__ = "titles"

    imdb_id: Mapped[str] = mapped_column(String(20), primary_key=True)
    kind: Mapped[str] = mapped_column(String(10), index=True)
    title: Mapped[str] = mapped_column(String(300), index=True)
    original_title: Mapped[str | None] = mapped_column(String(300))
    year: Mapped[int | None] = mapped_column(Integer, index=True)
    end_year: Mapped[int | None] = mapped_column(Integer)
    poster_url: Mapped[str | None] = mapped_column(String(600))
    plot: Mapped[str | None] = mapped_column(Text)
    genres: Mapped[list | None] = mapped_column(JSON, default=list)
    runtime_minutes: Mapped[int | None] = mapped_column(Integer)
    imdb_rating: Mapped[float | None] = mapped_column(Float)
    imdb_votes: Mapped[int | None] = mapped_column(Integer)
    countries: Mapped[list | None] = mapped_column(JSON, default=list)
    directors: Mapped[list | None] = mapped_column(JSON, default=list)
    creators: Mapped[list | None] = mapped_column(JSON, default=list)
    cast: Mapped[list | None] = mapped_column(JSON, default=list)
    season_count: Mapped[int | None] = mapped_column(Integer)
    episode_count: Mapped[int | None] = mapped_column(Integer)
    is_ongoing: Mapped[bool | None] = mapped_column(Boolean)
    popularity_rank: Mapped[int | None] = mapped_column(Integer)
    # Where the row stands: a search hit is a stub, a detail fetch fills it in.
    has_details: Mapped[bool] = mapped_column(Boolean, default=False)
    episodes_synced_at: Mapped[datetime | None] = mapped_column(UtcDateTime(timezone=True))
    fetched_at: Mapped[datetime] = mapped_column(
        UtcDateTime(timezone=True), default=utcnow
    )

    seasons: Mapped[list[Season]] = relationship(
        back_populates="series", cascade="all, delete-orphan"
    )
    episodes: Mapped[list[Episode]] = relationship(
        back_populates="series", cascade="all, delete-orphan"
    )


class Season(Base):
    __tablename__ = "seasons"
    __table_args__ = (UniqueConstraint("series_id", "number", name="uq_season"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    series_id: Mapped[str] = mapped_column(
        ForeignKey("titles.imdb_id", ondelete="CASCADE"), index=True
    )
    number: Mapped[int] = mapped_column(Integer)
    episode_count: Mapped[int] = mapped_column(Integer, default=0)
    # When this season's episode list was last pulled from IMDb. `Title.
    # episodes_synced_at` means the same thing for *every* season at once.
    synced_at: Mapped[datetime | None] = mapped_column(UtcDateTime(timezone=True))

    series: Mapped[Title] = relationship(back_populates="seasons")


class Episode(Base):
    __tablename__ = "episodes"
    __table_args__ = (
        Index("ix_episode_series_season", "series_id", "season_number", "episode_number"),
    )

    imdb_id: Mapped[str] = mapped_column(String(20), primary_key=True)
    series_id: Mapped[str] = mapped_column(
        ForeignKey("titles.imdb_id", ondelete="CASCADE"), index=True
    )
    season_number: Mapped[int] = mapped_column(Integer)
    episode_number: Mapped[int] = mapped_column(Integer)
    title: Mapped[str | None] = mapped_column(String(300))
    plot: Mapped[str | None] = mapped_column(Text)
    air_date: Mapped[str | None] = mapped_column(String(20))
    runtime_minutes: Mapped[int | None] = mapped_column(Integer)
    imdb_rating: Mapped[float | None] = mapped_column(Float)
    still_url: Mapped[str | None] = mapped_column(String(600))

    series: Mapped[Title] = relationship(back_populates="episodes")


class ImdbCache(Base):
    """Raw payload cache for list-shaped IMDb answers (search, charts)."""

    __tablename__ = "imdb_cache"

    key: Mapped[str] = mapped_column(String(200), primary_key=True)
    payload: Mapped[dict] = mapped_column(JSON)
    fetched_at: Mapped[datetime] = mapped_column(
        UtcDateTime(timezone=True), default=utcnow, index=True
    )


# --------------------------------------------------------------------------
# user activity
# --------------------------------------------------------------------------


class UserTitle(Base, TimestampMixin):
    """Watch state of one title for one user (sections 5.9, 5.12, 5.16)."""

    __tablename__ = "user_titles"
    __table_args__ = (UniqueConstraint("user_id", "title_id", name="uq_user_title"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    title_id: Mapped[str] = mapped_column(
        ForeignKey("titles.imdb_id", ondelete="CASCADE"), index=True
    )
    status: Mapped[str | None] = mapped_column(String(20), index=True)
    is_favorite: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    finished_at: Mapped[datetime | None] = mapped_column(UtcDateTime(timezone=True))

    title: Mapped[Title] = relationship(lazy="joined")


class EpisodeWatch(Base):
    __tablename__ = "episode_watches"
    __table_args__ = (
        UniqueConstraint("user_id", "episode_id", name="uq_user_episode"),
        Index("ix_watch_user_series", "user_id", "series_id"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    episode_id: Mapped[str] = mapped_column(
        ForeignKey("episodes.imdb_id", ondelete="CASCADE")
    )
    series_id: Mapped[str] = mapped_column(String(20), index=True)
    season_number: Mapped[int] = mapped_column(Integer)
    episode_number: Mapped[int] = mapped_column(Integer)
    runtime_minutes: Mapped[int | None] = mapped_column(Integer)
    watched_at: Mapped[datetime] = mapped_column(
        UtcDateTime(timezone=True), default=utcnow
    )


class Rating(Base, TimestampMixin):
    """One row per (user, title) — re-posting edits instead of duplicating."""

    __tablename__ = "ratings"
    __table_args__ = (UniqueConstraint("user_id", "title_id", name="uq_user_rating"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    title_id: Mapped[str] = mapped_column(
        ForeignKey("titles.imdb_id", ondelete="CASCADE"), index=True
    )
    score: Mapped[int] = mapped_column(Integer)


class Review(Base, TimestampMixin):
    __tablename__ = "reviews"
    __table_args__ = (UniqueConstraint("user_id", "title_id", name="uq_user_review"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    title_id: Mapped[str] = mapped_column(
        ForeignKey("titles.imdb_id", ondelete="CASCADE"), index=True
    )
    text: Mapped[str] = mapped_column(Text)
    has_spoiler: Mapped[bool] = mapped_column(Boolean, default=False)
    is_hidden: Mapped[bool] = mapped_column(Boolean, default=False)

    user: Mapped[User] = relationship(lazy="joined")


class CustomList(Base, TimestampMixin):
    __tablename__ = "custom_lists"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    name: Mapped[str] = mapped_column(String(80))
    description: Mapped[str | None] = mapped_column(String(300))
    is_public: Mapped[bool] = mapped_column(Boolean, default=True)

    items: Mapped[list[CustomListItem]] = relationship(
        back_populates="list", cascade="all, delete-orphan", order_by="CustomListItem.position"
    )


class CustomListItem(Base):
    __tablename__ = "custom_list_items"
    __table_args__ = (UniqueConstraint("list_id", "title_id", name="uq_list_title"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    list_id: Mapped[int] = mapped_column(
        ForeignKey("custom_lists.id", ondelete="CASCADE"), index=True
    )
    title_id: Mapped[str] = mapped_column(
        ForeignKey("titles.imdb_id", ondelete="CASCADE")
    )
    position: Mapped[int] = mapped_column(Integer, default=0)
    added_at: Mapped[datetime] = mapped_column(UtcDateTime(timezone=True), default=utcnow)

    list: Mapped[CustomList] = relationship(back_populates="items")
    title: Mapped[Title] = relationship(lazy="joined")


class Report(Base):
    __tablename__ = "reports"

    id: Mapped[int] = mapped_column(primary_key=True)
    reporter_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    review_id: Mapped[int | None] = mapped_column(
        ForeignKey("reviews.id", ondelete="CASCADE"), index=True
    )
    reason: Mapped[str] = mapped_column(String(300))
    status: Mapped[str] = mapped_column(String(20), default=ReportStatus.PENDING.value)
    resolution_note: Mapped[str | None] = mapped_column(String(300))
    created_at: Mapped[datetime] = mapped_column(
        UtcDateTime(timezone=True), default=utcnow
    )
    resolved_at: Mapped[datetime | None] = mapped_column(UtcDateTime(timezone=True))


class Follow(Base):
    __tablename__ = "follows"
    __table_args__ = (
        UniqueConstraint("follower_id", "following_id", name="uq_follow"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    follower_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    following_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    created_at: Mapped[datetime] = mapped_column(
        UtcDateTime(timezone=True), default=utcnow
    )


class Activity(Base):
    """Feed entries — what the people you follow have been up to."""

    __tablename__ = "activities"
    __table_args__ = (Index("ix_activity_user_time", "user_id", "created_at"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    type: Mapped[str] = mapped_column(String(30))
    title_id: Mapped[str | None] = mapped_column(String(20))
    payload: Mapped[dict | None] = mapped_column(JSON)
    created_at: Mapped[datetime] = mapped_column(
        UtcDateTime(timezone=True), default=utcnow, index=True
    )


class ChatMessage(Base):
    """Per-title live chat room (bonus feature)."""

    __tablename__ = "chat_messages"
    __table_args__ = (Index("ix_chat_room_time", "room", "created_at"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    room: Mapped[str] = mapped_column(String(40), index=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    text: Mapped[str] = mapped_column(String(1000))
    created_at: Mapped[datetime] = mapped_column(
        UtcDateTime(timezone=True), default=utcnow
    )

    user: Mapped[User] = relationship(lazy="joined")
