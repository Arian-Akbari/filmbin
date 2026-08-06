"""Cache-aware facade over IMDb (sections 7.3, 7.5, 8.4).

Every read follows the same rule: **answer from the local mirror when it is
fresh, refresh it from IMDb when it is stale, and fall back to whatever we have
when IMDb is unreachable.** That is what keeps the app usable during an outage
and what keeps us from hammering the upstream (section 8.1).
"""

from __future__ import annotations

import hashlib
import json
import logging
from datetime import UTC, datetime, timedelta
from typing import Any, Literal

from sqlalchemy import delete, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.errors import TitleNotFoundError, UpstreamError
from app.db.models import Episode, ImdbCache, Season, Title, utcnow
from app.imdb import queries as Q
from app.imdb.client import imdb_client
from app.imdb.mapper import map_episode, map_name, map_title_card, map_title_details

logger = logging.getLogger("filmbin.imdb.service")

TITLE_COLUMNS = {c.name for c in Title.__table__.columns}
EPISODE_COLUMNS = {c.name for c in Episode.__table__.columns}

Section = Literal[
    "popular_movies", "popular_series", "new_releases", "top_rated", "top_rated_series"
]

_CHART_SECTIONS: dict[str, str] = {
    "popular_movies": "MOST_POPULAR_MOVIES",
    "popular_series": "MOST_POPULAR_TV_SHOWS",
    "top_rated": "TOP_RATED_MOVIES",
    "top_rated_series": "TOP_RATED_TV_SHOWS",
}


def _cache_key(kind: str, payload: dict[str, Any]) -> str:
    blob = json.dumps(payload, sort_keys=True, ensure_ascii=False)
    return f"{kind}:{hashlib.sha1(blob.encode()).hexdigest()[:32]}"


def _is_fresh(moment: datetime | None, hours: int) -> bool:
    if moment is None:
        return False
    if moment.tzinfo is None:
        moment = moment.replace(tzinfo=UTC)
    return datetime.now(UTC) - moment < timedelta(hours=hours)


async def _read_cache(db: AsyncSession, key: str, ttl_hours: int) -> Any | None:
    row = await db.get(ImdbCache, key)
    if row and _is_fresh(row.fetched_at, ttl_hours):
        return row.payload.get("data")
    return None


async def _write_cache(db: AsyncSession, key: str, data: Any) -> None:
    row = await db.get(ImdbCache, key)
    if row:
        row.payload = {"data": data}
        row.fetched_at = utcnow()
    else:
        db.add(ImdbCache(key=key, payload={"data": data}, fetched_at=utcnow()))
    await db.flush()


async def _read_stale_cache(db: AsyncSession, key: str) -> Any | None:
    row = await db.get(ImdbCache, key)
    return row.payload.get("data") if row else None


# --------------------------------------------------------------------------
# persistence helpers
# --------------------------------------------------------------------------


async def upsert_titles(db: AsyncSession, payloads: list[dict[str, Any]]) -> list[Title]:
    """Insert or refresh a batch of titles in two queries, not 2N."""
    payloads = [p for p in payloads if p]
    if not payloads:
        return []

    ids = [p["imdb_id"] for p in payloads]
    existing = {
        row.imdb_id: row
        for row in (await db.execute(select(Title).where(Title.imdb_id.in_(ids)))).scalars()
    }

    result: list[Title] = []
    for payload in payloads:
        fields = {k: v for k, v in payload.items() if k in TITLE_COLUMNS}
        row = existing.get(payload["imdb_id"])
        if row is None:
            row = Title(**fields, fetched_at=utcnow())
            db.add(row)
            existing[row.imdb_id] = row
        else:
            has_details = row.has_details or fields.get("has_details", False)
            for key, value in fields.items():
                # A search hit must never blank out fields a detail fetch filled.
                if value is None and row.has_details:
                    continue
                setattr(row, key, value)
            row.has_details = has_details
            row.fetched_at = utcnow()
        result.append(row)

    await db.flush()
    return result


async def _sync_seasons(db: AsyncSession, series_id: str, seasons: list[int]) -> None:
    if not seasons:
        return
    existing = {
        row.number: row
        for row in (
            await db.execute(select(Season).where(Season.series_id == series_id))
        ).scalars()
    }
    for number in seasons:
        if number not in existing:
            db.add(Season(series_id=series_id, number=number))
    await db.flush()


# --------------------------------------------------------------------------
# public API
# --------------------------------------------------------------------------


async def search_titles(
    db: AsyncSession,
    *,
    query: str | None = None,
    kind: str | None = None,
    genres: list[str] | None = None,
    year_from: int | None = None,
    year_to: int | None = None,
    person_ids: list[str] | None = None,
    min_votes: int | None = None,
    sort_by: str = "POPULARITY",
    sort_order: str = "ASC",
    limit: int = 20,
    cursor: str | None = None,
) -> dict[str, Any]:
    """Section 5.5 — search by title, person, genre or year, with paging."""
    constraints: dict[str, Any] = {}
    if query:
        constraints["titleTextConstraint"] = {"searchTerm": query}
    if kind == "movie":
        constraints["titleTypeConstraint"] = {"anyTitleTypeIds": ["movie", "tvMovie"]}
    elif kind == "series":
        constraints["titleTypeConstraint"] = {
            "anyTitleTypeIds": ["tvSeries", "tvMiniSeries"]
        }
    if genres:
        constraints["genreConstraint"] = {"anyGenreIds": genres}
    if year_from or year_to:
        constraints["releaseDateConstraint"] = {
            "releaseDateRange": {
                "start": f"{year_from or 1900}-01-01",
                "end": f"{year_to or datetime.now(UTC).year + 5}-12-31",
            }
        }
    if person_ids:
        constraints["creditedNameConstraint"] = {"anyNameIds": person_ids}
    if min_votes:
        # Keeps "newest" lists free of obscure entries nobody has rated yet.
        constraints["userRatingsConstraint"] = {"ratingsCountRange": {"min": min_votes}}
    if not constraints:
        constraints["titleTypeConstraint"] = {"anyTitleTypeIds": ["movie", "tvSeries"]}

    variables = {
        "first": limit,
        "after": cursor,
        "constraints": constraints,
        "sort": {"sortBy": sort_by, "sortOrder": sort_order},
    }
    key = _cache_key("search", variables)

    cached = await _read_cache(db, key, settings.cache_ttl_search_hours)
    if cached is not None:
        titles = await upsert_titles(db, cached["items"])
        return {"items": titles, "total": cached["total"], "next_cursor": cached["next_cursor"], "stale": False}

    try:
        data = await imdb_client.execute(Q.SEARCH_TITLES, variables)
        connection = data.get("advancedTitleSearch") or {}
        items = [
            mapped
            for edge in connection.get("edges") or []
            if (mapped := map_title_card((edge.get("node") or {}).get("title") or {}))
        ]
        page = connection.get("pageInfo") or {}
        result = {
            "items": items,
            "total": connection.get("total", len(items)),
            "next_cursor": page.get("endCursor") if page.get("hasNextPage") else None,
        }
        await _write_cache(db, key, result)
        return {**result, "items": await upsert_titles(db, items), "stale": False}
    except UpstreamError:
        stale = await _read_stale_cache(db, key)
        if stale:
            logger.info("serving stale search results for %s", key)
            return {**stale, "items": await upsert_titles(db, stale["items"]), "stale": True}
        local = await _local_search(db, query, kind, limit)
        if local:
            return {"items": local, "total": len(local), "next_cursor": None, "stale": True}
        raise


async def _local_search(
    db: AsyncSession, query: str | None, kind: str | None, limit: int
) -> list[Title]:
    """Last-resort search over the local mirror when IMDb is unreachable."""
    stmt = select(Title)
    if query:
        pattern = f"%{query.lower()}%"
        stmt = stmt.where(
            or_(
                func.lower(Title.title).like(pattern),
                func.lower(Title.original_title).like(pattern),
            )
        )
    if kind:
        stmt = stmt.where(Title.kind == kind)
    stmt = stmt.order_by(Title.imdb_votes.desc().nullslast()).limit(limit)
    return list((await db.execute(stmt)).scalars())


async def search_people(db: AsyncSession, query: str, limit: int = 8) -> list[dict[str, Any]]:
    key = _cache_key("names", {"q": query.lower(), "limit": limit})
    cached = await _read_cache(db, key, settings.cache_ttl_search_hours)
    if cached is not None:
        return cached
    try:
        data = await imdb_client.execute(Q.SEARCH_NAMES, {"q": query, "first": limit})
    except UpstreamError:
        return await _read_stale_cache(db, key) or []
    people = [
        mapped
        for edge in (data.get("mainSearch") or {}).get("edges") or []
        if (mapped := map_name((edge.get("node") or {}).get("entity") or {}))
    ]
    await _write_cache(db, key, people)
    return people


async def get_title(db: AsyncSession, imdb_id: str, *, force: bool = False) -> Title:
    """Section 5.6 / 5.7 — full detail for one movie or series."""
    row = await db.get(Title, imdb_id)
    if row and row.has_details and not force and _is_fresh(row.fetched_at, settings.cache_ttl_details_hours):
        return row

    try:
        data = await imdb_client.execute(Q.TITLE_DETAILS, {"id": imdb_id})
    except UpstreamError:
        if row:
            logger.info("serving stale detail for %s", imdb_id)
            return row
        raise

    node = data.get("title")
    if not node:
        raise TitleNotFoundError(detail=imdb_id)

    payload = map_title_details(node)
    if payload is None:
        raise TitleNotFoundError(detail=imdb_id)

    seasons = payload.pop("seasons", [])
    (title,) = await upsert_titles(db, [payload])
    if seasons:
        await _sync_seasons(db, imdb_id, seasons)
    return title


async def get_titles_by_ids(db: AsyncSession, ids: list[str]) -> list[Title]:
    """Hydrate a set of ids, fetching only the ones we do not already mirror."""
    if not ids:
        return []
    known = {
        row.imdb_id: row
        for row in (await db.execute(select(Title).where(Title.imdb_id.in_(ids)))).scalars()
    }
    missing = [i for i in ids if i not in known]
    if missing:
        try:
            data = await imdb_client.execute(Q.TITLES_BY_IDS, {"ids": missing[:50]})
            fetched = [m for node in data.get("titles") or [] if (m := map_title_card(node))]
            for row in await upsert_titles(db, fetched):
                known[row.imdb_id] = row
        except UpstreamError:
            logger.info("could not hydrate %s missing titles", len(missing))
    return [known[i] for i in ids if i in known]


async def get_seasons(db: AsyncSession, imdb_id: str) -> list[Season]:
    title = await get_title(db, imdb_id)
    rows = list(
        (
            await db.execute(
                select(Season).where(Season.series_id == imdb_id).order_by(Season.number)
            )
        ).scalars()
    )
    # A partially-filled mirror is the normal case, not the exception: opening
    # one season (or a deep link straight to the episode list) creates a single
    # Season row, and the season list would then be missing everything else.
    # Compare against what the title itself says and backfill the gaps.
    missing = [
        number
        for number in range(1, (title.season_count or 0) + 1)
        if number not in {row.number for row in rows}
    ]
    if missing:
        await _sync_seasons(db, imdb_id, missing)
        rows = list(
            (
                await db.execute(
                    select(Season).where(Season.series_id == imdb_id).order_by(Season.number)
                )
            ).scalars()
        )
    return rows


async def get_episodes(
    db: AsyncSession, imdb_id: str, season: int, *, force: bool = False
) -> list[Episode]:
    """Section 5.8 — episode list of one season, mirrored locally."""
    title = await get_title(db, imdb_id)
    stmt = (
        select(Episode)
        .where(Episode.series_id == imdb_id, Episode.season_number == season)
        .order_by(Episode.episode_number)
    )
    rows = list((await db.execute(stmt)).scalars())

    season_row = (
        await db.execute(
            select(Season).where(Season.series_id == imdb_id, Season.number == season)
        )
    ).scalar_one_or_none()
    fresh = season_row is not None and _is_fresh(
        season_row.synced_at, settings.cache_ttl_details_hours
    )
    if rows and fresh and not force:
        return rows

    fetched: list[dict[str, Any]] = []
    cursor: str | None = None
    try:
        while True:
            data = await imdb_client.execute(
                Q.SEASON_EPISODES,
                {"id": imdb_id, "seasons": [str(season)], "first": 50, "after": cursor},
            )
            connection = ((data.get("title") or {}).get("episodes") or {}).get("episodes") or {}
            for edge in connection.get("edges") or []:
                mapped = map_episode(edge.get("node") or {}, imdb_id)
                if mapped:
                    fetched.append(mapped)
            page = connection.get("pageInfo") or {}
            if not page.get("hasNextPage"):
                break
            cursor = page.get("endCursor")
    except UpstreamError:
        if rows:
            return rows
        raise

    if not fetched:
        return rows

    existing = {row.imdb_id: row for row in rows}
    for payload in fetched:
        fields = {k: v for k, v in payload.items() if k in EPISODE_COLUMNS}
        row = existing.get(payload["imdb_id"])
        if row is None:
            db.add(Episode(**fields))
        else:
            for key, value in fields.items():
                setattr(row, key, value)

    if season_row is None:
        db.add(
            Season(
                series_id=imdb_id,
                number=season,
                episode_count=len(fetched),
                synced_at=utcnow(),
            )
        )
    else:
        season_row.episode_count = len(fetched)
        season_row.synced_at = utcnow()

    await db.flush()
    return list((await db.execute(stmt)).scalars())


async def sync_all_episodes(db: AsyncSession, imdb_id: str) -> int:
    """Mirror every season of a series.

    Watch progress is meaningless unless we know the real episode total, so this
    runs before the first progress calculation and then only when the mirror is
    stale (`Title.episodes_synced_at`).
    """
    title = await get_title(db, imdb_id)
    seasons = await get_seasons(db, imdb_id)
    total = 0
    for season in seasons:
        total += len(await get_episodes(db, imdb_id, season.number))
    title.episodes_synced_at = utcnow()
    await db.flush()
    return total


async def mirrored_season_count(db: AsyncSession, imdb_id: str) -> int:
    return int(
        (
            await db.execute(
                select(func.count(func.distinct(Episode.season_number))).where(
                    Episode.series_id == imdb_id
                )
            )
        ).scalar_one()
    )


async def episodes_are_complete(db: AsyncSession, title: Title) -> bool:
    """True when every season we know about has its episodes mirrored.

    The freshness stamp alone is not enough: an evicted title, a sync that died
    half-way, or a deep link that pulled a single season all leave the stamp in
    place with rows missing. Progress is computed from the mirrored rows, so
    trusting the stamp there would report «۱۰۰٪» after one season.
    """
    if title.kind != "series":
        return True
    expected = title.season_count or 0
    if expected and await mirrored_season_count(db, title.imdb_id) < expected:
        return False
    return _is_fresh(title.episodes_synced_at, settings.cache_ttl_details_hours)


async def get_section(db: AsyncSession, section: str, limit: int = 20) -> list[Title]:
    """Section 5.18 — the home-screen rails."""
    key = _cache_key("section", {"section": section, "limit": limit})
    cached = await _read_cache(db, key, settings.cache_ttl_chart_hours)
    if cached is not None:
        return await upsert_titles(db, cached)

    try:
        if section == "new_releases":
            year = datetime.now(UTC).year
            result = await search_titles(
                db,
                year_from=year - 1,
                year_to=year,
                min_votes=500,
                sort_by="RELEASE_DATE",
                sort_order="DESC",
                limit=limit,
            )
            titles = result["items"]
            await _write_cache(
                db, key, [_title_to_payload(t) for t in titles]
            )
            return titles

        chart = _CHART_SECTIONS.get(section)
        if chart is None:
            return []
        data = await imdb_client.execute(Q.CHART_TITLES, {"chart": chart, "first": limit})
        items = [
            mapped
            for edge in (data.get("chartTitles") or {}).get("edges") or []
            if (mapped := map_title_card(edge.get("node") or {}))
        ]
        await _write_cache(db, key, items)
        return await upsert_titles(db, items)
    except UpstreamError:
        stale = await _read_stale_cache(db, key)
        if stale:
            return await upsert_titles(db, stale)
        raise


def _title_to_payload(title: Title) -> dict[str, Any]:
    return {c: getattr(title, c) for c in TITLE_COLUMNS if c not in {"fetched_at", "episodes_synced_at"}}


async def purge_cache(db: AsyncSession, older_than_hours: int = 0) -> int:
    cutoff = datetime.now(UTC) - timedelta(hours=older_than_hours)
    result = await db.execute(delete(ImdbCache).where(ImdbCache.fetched_at < cutoff))
    return result.rowcount or 0
