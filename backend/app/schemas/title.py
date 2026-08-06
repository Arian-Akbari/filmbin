"""Title, episode and discovery shapes (sections 5.5–5.8, 5.11, 5.18)."""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict

from app.schemas.review import ReviewOut


class CastMember(BaseModel):
    id: str | None = None
    name: str
    characters: list[str] = []
    image: str | None = None


class SeasonOut(BaseModel):
    number: int
    episode_count: int = 0


class RatingBucket(BaseModel):
    """One bar of the star histogram — `percent` is 0…100 (section 5.13)."""

    score: int
    count: int
    percent: int


class ProgressOut(BaseModel):
    """Section 5.11 — how far through a series the user is."""

    total_episodes: int
    watched_episodes: int
    remaining_episodes: int
    percent: int
    color: str
    is_ongoing: bool = False


class TitleSummary(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    imdb_id: str
    kind: str
    title: str
    original_title: str | None = None
    year: int | None = None
    end_year: int | None = None
    poster_url: str | None = None
    poster_thumb_url: str | None = None
    plot: str | None = None
    genres: list[str] = []
    runtime_minutes: int | None = None
    imdb_rating: float | None = None
    imdb_votes: int | None = None
    user_rating_average: float | None = None
    user_rating_count: int = 0
    my_status: str | None = None
    my_rating: int | None = None
    is_favorite: bool = False


class TitleDetail(TitleSummary):
    countries: list[str] = []
    directors: list[str] = []
    creators: list[str] = []
    cast: list[CastMember] = []
    season_count: int | None = None
    episode_count: int | None = None
    is_ongoing: bool | None = None
    status_label: str | None = None
    seasons: list[SeasonOut] = []
    rating_distribution: list[RatingBucket] = []
    my_review: ReviewOut | None = None
    progress: ProgressOut | None = None
    updated_at: datetime | None = None


class EpisodeOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    imdb_id: str
    series_id: str
    season_number: int
    episode_number: int
    title: str | None = None
    plot: str | None = None
    air_date: str | None = None
    runtime_minutes: int | None = None
    imdb_rating: float | None = None
    still_url: str | None = None
    is_watched: bool = False


class SearchResponse(BaseModel):
    items: list[TitleSummary]
    total: int
    next_cursor: str | None = None
    # True when IMDb was unreachable and we answered from the local mirror.
    stale: bool = False


class PersonOut(BaseModel):
    id: str
    name: str | None = None
    image: str | None = None
    professions: list[str] = []


class DiscoverSection(BaseModel):
    key: str
    title: str
    items: list[TitleSummary]


class DiscoverResponse(BaseModel):
    sections: list[DiscoverSection]


class RecommendationResponse(BaseModel):
    items: list[TitleSummary]
    based_on: list[str]
    # False for a brand-new account: the picks are just what is popular, so the
    # app can keep the «پیشنهاد برای شما» shelf hidden instead of repeating the
    # popular rail back at the user.
    personalized: bool = False
