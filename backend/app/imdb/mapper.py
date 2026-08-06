"""Turn IMDb's nested GraphQL shapes into the flat rows our DB and API use.

Section 7.3 asks for one consistent shape going back to the app, whatever the
upstream looks like — that normalisation happens here and nowhere else.
"""

from __future__ import annotations

import re
from typing import Any

_SERIES_TYPE_IDS = {"tvSeries", "tvMiniSeries", "tvSpecial"}
_CAST_CATEGORIES = {"actor", "actress", "cast", "self"}
_IMAGE_SUFFIX = re.compile(r"\._V1_.*?(\.(jpg|jpeg|png))$", re.IGNORECASE)


def sized_image(url: str | None, width: int) -> str | None:
    """IMDb serves resized derivatives if you rewrite the filename.

    Asking for a 300px-wide poster instead of the 2100px original is the single
    biggest bandwidth win in the whole app (sections 8.1 and 8.8).
    """
    if not url:
        return None
    if "._V1_" not in url:
        return url
    return _IMAGE_SUFFIX.sub(rf"._V1_QL75_UX{width}_\1", url)


def _get(node: Any, *path: str, default: Any = None) -> Any:
    current = node
    for key in path:
        if not isinstance(current, dict):
            return default
        current = current.get(key)
        if current is None:
            return default
    return current


def _seconds_to_minutes(seconds: Any) -> int | None:
    if not isinstance(seconds, (int, float)) or seconds <= 0:
        return None
    return int(round(seconds / 60))


def map_title_card(node: dict[str, Any]) -> dict[str, Any] | None:
    """The shared `TitleCard` fragment → a `titles` row (partial)."""
    if not node or not node.get("id"):
        return None

    type_id = _get(node, "titleType", "id") or ""
    is_series = bool(_get(node, "titleType", "isSeries")) or type_id in _SERIES_TYPE_IDS
    poster = _get(node, "primaryImage", "url")

    return {
        "imdb_id": node["id"],
        "kind": "series" if is_series else "movie",
        "title": _get(node, "titleText", "text") or node["id"],
        "original_title": _get(node, "originalTitleText", "text"),
        "year": _get(node, "releaseYear", "year"),
        "end_year": _get(node, "releaseYear", "endYear"),
        "poster_url": poster,
        "plot": _get(node, "plot", "plotText", "plainText"),
        "genres": [g["text"] for g in _get(node, "genres", "genres", default=[]) if g.get("text")],
        "runtime_minutes": _seconds_to_minutes(_get(node, "runtime", "seconds")),
        "imdb_rating": _get(node, "ratingsSummary", "aggregateRating"),
        "imdb_votes": _get(node, "ratingsSummary", "voteCount"),
        "type_label": _get(node, "titleType", "text"),
    }


def map_title_details(node: dict[str, Any]) -> dict[str, Any] | None:
    """`TITLE_DETAILS` → a fully populated `titles` row."""
    base = map_title_card(node)
    if base is None:
        return None

    directors: list[str] = []
    creators: list[str] = []
    for block in node.get("principalCredits") or []:
        label = (_get(block, "category", "text") or "").lower()
        names = [
            _get(credit, "name", "nameText", "text")
            for credit in block.get("credits") or []
            if _get(credit, "name", "nameText", "text")
        ]
        if "director" in label:
            directors.extend(names)
        elif "creator" in label or "writer" in label and not creators:
            creators.extend(names)

    cast: list[dict[str, Any]] = []
    for edge in _get(node, "credits", "edges", default=[]):
        credit = edge.get("node") or {}
        category = (_get(credit, "category", "id") or "").lower()
        if category and category not in _CAST_CATEGORIES:
            continue
        name = _get(credit, "name", "nameText", "text")
        if not name:
            continue
        cast.append(
            {
                "id": _get(credit, "name", "id"),
                "name": name,
                "characters": [c["name"] for c in credit.get("characters") or [] if c.get("name")],
                "image": sized_image(_get(credit, "name", "primaryImage", "url"), 200),
            }
        )

    seasons = [
        int(edge["node"]["season"])
        for edge in _get(node, "episodes", "displayableSeasons", "edges", default=[])
        if str(_get(edge, "node", "season", default="")).isdigit()
    ]

    base.update(
        {
            "countries": [
                c["text"]
                for c in _get(node, "countriesOfOrigin", "countries", default=[])
                if c.get("text")
            ],
            "directors": directors,
            "creators": creators,
            "cast": cast,
            "season_count": max(seasons) if seasons else None,
            "episode_count": _get(node, "episodes", "episodes", "total"),
            "is_ongoing": _get(node, "episodes", "isOngoing"),
            "seasons": sorted(seasons),
            "has_details": True,
        }
    )
    return base


def map_episode(node: dict[str, Any], series_id: str) -> dict[str, Any] | None:
    if not node or not node.get("id"):
        return None
    numbers = _get(node, "series", "episodeNumber", default={}) or {}
    season = numbers.get("seasonNumber")
    number = numbers.get("episodeNumber")
    if season is None or number is None:
        return None

    date = node.get("releaseDate") or {}
    air_date = None
    if date.get("year"):
        air_date = "-".join(
            str(part).zfill(2 if key != "year" else 4)
            for key, part in (("year", date.get("year")), ("month", date.get("month")), ("day", date.get("day")))
            if part
        )

    return {
        "imdb_id": node["id"],
        "series_id": series_id,
        "season_number": int(season),
        "episode_number": int(number),
        "title": _get(node, "titleText", "text"),
        "plot": _get(node, "plot", "plotText", "plainText"),
        "air_date": air_date,
        "runtime_minutes": _seconds_to_minutes(_get(node, "runtime", "seconds")),
        "imdb_rating": _get(node, "ratingsSummary", "aggregateRating"),
        # Drawn as a 104×60 thumbnail — never ship the 500 KB original
        # (section 8.8).
        "still_url": sized_image(_get(node, "primaryImage", "url"), 320),
    }


def map_name(entity: dict[str, Any]) -> dict[str, Any] | None:
    if not entity or not entity.get("id"):
        return None
    return {
        "id": entity["id"],
        "name": _get(entity, "nameText", "text"),
        "image": sized_image(_get(entity, "primaryImage", "url"), 200),
        "professions": [
            _get(p, "category", "text")
            for p in entity.get("primaryProfessions") or []
            if _get(p, "category", "text")
        ],
    }
