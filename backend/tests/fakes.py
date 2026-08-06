"""Canned IMDb payloads.

Shapes copied from real answers of `https://api.graphql.imdb.com/` so the fake
and the real upstream cannot drift apart silently. Tests run fully offline
against these; `tests/test_imdb_live.py` is the one place that talks to the
real service, and it is opt-in.
"""

from __future__ import annotations

from typing import Any

MATRIX_ID = "tt0133093"
BREAKING_BAD_ID = "tt0903747"


def _card(
    imdb_id: str,
    text: str,
    type_id: str = "movie",
    year: int = 1999,
    rating: float = 8.7,
    votes: int = 2_000_000,
    runtime: int = 8160,
    genres: tuple[str, ...] = ("Action", "Sci-Fi"),
    end_year: int | None = None,
) -> dict[str, Any]:
    return {
        "id": imdb_id,
        "titleText": {"text": text},
        "originalTitleText": {"text": text},
        "titleType": {
            "id": type_id,
            "text": "Movie" if type_id == "movie" else "TV Series",
            "isSeries": type_id != "movie",
            "canHaveEpisodes": type_id != "movie",
        },
        "releaseYear": {"year": year, "endYear": end_year},
        "primaryImage": {
            "url": f"https://m.media-amazon.com/images/M/{imdb_id}._V1_.jpg",
            "width": 2100,
            "height": 3156,
        },
        "ratingsSummary": {"aggregateRating": rating, "voteCount": votes},
        "runtime": {"seconds": runtime},
        "genres": {"genres": [{"text": g} for g in genres]},
        "plot": {"plotText": {"plainText": f"Plot of {text}."}},
    }


MATRIX_CARD = _card(MATRIX_ID, "The Matrix")
BREAKING_BAD_CARD = _card(
    BREAKING_BAD_ID,
    "Breaking Bad",
    type_id="tvSeries",
    year=2008,
    end_year=2013,
    rating=9.5,
    votes=2_600_000,
    runtime=2880,
    genres=("Crime", "Drama", "Thriller"),
)
ONGOING_CARD = _card(
    "tt5555555",
    "Ongoing Show",
    type_id="tvSeries",
    year=2024,
    rating=8.0,
    votes=1000,
    runtime=2700,
    genres=("Drama",),
)

_CREDITS = {
    "total": 3,
    "edges": [
        {
            "node": {
                "category": {"id": "actor", "text": "Actor"},
                "name": {
                    "id": "nm0186505",
                    "nameText": {"text": "Bryan Cranston"},
                    "primaryImage": {"url": "https://img/nm0186505._V1_.jpg"},
                },
                "characters": [{"name": "Walter White"}],
            }
        },
        {
            "node": {
                "category": {"id": "actress", "text": "Actress"},
                "name": {
                    "id": "nm0348152",
                    "nameText": {"text": "Anna Gunn"},
                    "primaryImage": {"url": "https://img/nm0348152._V1_.jpg"},
                },
                "characters": [{"name": "Skyler White"}],
            }
        },
        {
            "node": {
                "category": {"id": "composer", "text": "Composer"},
                "name": {"id": "nm999", "nameText": {"text": "Someone Else"}},
            }
        },
    ],
}


def _details(card: dict[str, Any], *, seasons: int, episodes: int, ongoing: bool) -> dict[str, Any]:
    node = dict(card)
    node["countriesOfOrigin"] = {"countries": [{"id": "US", "text": "United States"}]}
    node["principalCredits"] = [
        {
            "category": {"id": "director", "text": "Director"},
            "credits": [{"name": {"id": "nm1", "nameText": {"text": "Vince Gilligan"}}}],
        },
        {
            "category": {"id": "creator", "text": "Creator"},
            "credits": [{"name": {"id": "nm1", "nameText": {"text": "Vince Gilligan"}}}],
        },
    ]
    node["credits"] = _CREDITS
    node["episodes"] = (
        {
            "isOngoing": ongoing,
            "displayableSeasons": {
                "edges": [{"node": {"season": str(n), "text": str(n)}} for n in range(1, seasons + 1)]
            },
            "episodes": {"total": episodes},
        }
        if seasons
        else None
    )
    return node


MATRIX_DETAILS = _details(MATRIX_CARD, seasons=0, episodes=0, ongoing=False)
BREAKING_BAD_DETAILS = _details(BREAKING_BAD_CARD, seasons=2, episodes=5, ongoing=False)
ONGOING_DETAILS = _details(ONGOING_CARD, seasons=1, episodes=2, ongoing=True)

# season -> episodes, per series
EPISODES: dict[str, dict[int, list[dict[str, Any]]]] = {
    BREAKING_BAD_ID: {
        1: [
            {
                "id": "tt0959621",
                "titleText": {"text": "Pilot"},
                "series": {"episodeNumber": {"seasonNumber": 1, "episodeNumber": 1}},
                "releaseDate": {"year": 2008, "month": 1, "day": 20},
                "runtime": {"seconds": 3480},
                "plot": {"plotText": {"plainText": "Walter cooks."}},
                "ratingsSummary": {"aggregateRating": 9.0},
                "primaryImage": {"url": "https://img/ep1._V1_.jpg"},
            },
            {
                "id": "tt1054724",
                "titleText": {"text": "Cat's in the Bag..."},
                "series": {"episodeNumber": {"seasonNumber": 1, "episodeNumber": 2}},
                "releaseDate": {"year": 2008, "month": 1, "day": 27},
                "runtime": {"seconds": 2880},
                "plot": {"plotText": {"plainText": "Cleanup."}},
                "ratingsSummary": {"aggregateRating": 8.6},
                "primaryImage": {"url": "https://img/ep2._V1_.jpg"},
            },
            {
                "id": "tt1054725",
                "titleText": {"text": "...And the Bag's in the River"},
                "series": {"episodeNumber": {"seasonNumber": 1, "episodeNumber": 3}},
                "releaseDate": {"year": 2008, "month": 2, "day": 10},
                "runtime": {"seconds": 2880},
                "plot": {"plotText": {"plainText": "Decision."}},
                "ratingsSummary": {"aggregateRating": 8.7},
                "primaryImage": {"url": "https://img/ep3._V1_.jpg"},
            },
        ],
        2: [
            {
                "id": "tt1054726",
                "titleText": {"text": "Seven Thirty-Seven"},
                "series": {"episodeNumber": {"seasonNumber": 2, "episodeNumber": 1}},
                "releaseDate": {"year": 2009, "month": 3, "day": 8},
                "runtime": {"seconds": 2820},
                "plot": {"plotText": {"plainText": "Trouble."}},
                "ratingsSummary": {"aggregateRating": 8.6},
                "primaryImage": {"url": "https://img/ep4._V1_.jpg"},
            },
            {
                "id": "tt1054727",
                "titleText": {"text": "Grilled"},
                "series": {"episodeNumber": {"seasonNumber": 2, "episodeNumber": 2}},
                "releaseDate": {"year": 2009, "month": 3, "day": 15},
                "runtime": {"seconds": 2820},
                "plot": {"plotText": {"plainText": "Tuco."}},
                "ratingsSummary": {"aggregateRating": 9.2},
                "primaryImage": {"url": "https://img/ep5._V1_.jpg"},
            },
        ],
    },
    "tt5555555": {
        1: [
            {
                "id": "tt5555001",
                "titleText": {"text": "Ongoing Ep 1"},
                "series": {"episodeNumber": {"seasonNumber": 1, "episodeNumber": 1}},
                "releaseDate": {"year": 2024, "month": 5, "day": 1},
                "runtime": {"seconds": 2700},
                "plot": {"plotText": {"plainText": "Start."}},
                "ratingsSummary": {"aggregateRating": 8.0},
                "primaryImage": {"url": "https://img/on1._V1_.jpg"},
            },
            {
                "id": "tt5555002",
                "titleText": {"text": "Ongoing Ep 2"},
                "series": {"episodeNumber": {"seasonNumber": 1, "episodeNumber": 2}},
                "releaseDate": {"year": 2024, "month": 5, "day": 8},
                "runtime": {"seconds": 2700},
                "plot": {"plotText": {"plainText": "More."}},
                "ratingsSummary": {"aggregateRating": 8.1},
                "primaryImage": {"url": "https://img/on2._V1_.jpg"},
            },
        ]
    },
}

DETAILS_BY_ID = {
    MATRIX_ID: MATRIX_DETAILS,
    BREAKING_BAD_ID: BREAKING_BAD_DETAILS,
    "tt5555555": ONGOING_DETAILS,
}
CARDS_BY_ID = {
    MATRIX_ID: MATRIX_CARD,
    BREAKING_BAD_ID: BREAKING_BAD_CARD,
    "tt5555555": ONGOING_CARD,
}

NAMES = [
    {
        "id": "nm0186505",
        "nameText": {"text": "Bryan Cranston"},
        "primaryImage": {"url": "https://img/nm0186505._V1_.jpg"},
        "primaryProfessions": [{"category": {"text": "Actor"}}],
    }
]


class FakeImdb:
    """Stand-in for `imdb_client`; records calls so tests can assert caching."""

    def __init__(self) -> None:
        self.calls: list[tuple[str, dict[str, Any]]] = []
        self.fail_with: Exception | None = None

    def operation(self, query: str) -> str:
        for name in (
            "SearchTitles",
            "SearchNames",
            "TitleDetails",
            "SeasonEpisodes",
            "ChartTitles",
            "TitlesByIds",
        ):
            if f"query {name}" in query:
                return name
        return "Unknown"

    async def execute(self, query: str, variables: dict[str, Any] | None = None) -> dict[str, Any]:
        operation = self.operation(query)
        variables = variables or {}
        self.calls.append((operation, variables))
        if self.fail_with is not None:
            raise self.fail_with

        if operation == "TitleDetails":
            node = DETAILS_BY_ID.get(variables.get("id"))
            return {"title": node}

        if operation == "SeasonEpisodes":
            series = EPISODES.get(variables.get("id"), {})
            season = int((variables.get("seasons") or ["1"])[0])
            nodes = series.get(season, [])
            return {
                "title": {
                    "episodes": {
                        "episodes": {
                            "total": len(nodes),
                            "pageInfo": {"hasNextPage": False, "endCursor": None},
                            "edges": [{"node": n} for n in nodes],
                        }
                    }
                }
            }

        if operation == "SearchTitles":
            constraints = variables.get("constraints") or {}
            term = ((constraints.get("titleTextConstraint") or {}).get("searchTerm") or "").lower()
            pool = [MATRIX_CARD, BREAKING_BAD_CARD, ONGOING_CARD]
            if term:
                pool = [c for c in pool if term in c["titleText"]["text"].lower()]
            kinds = (constraints.get("titleTypeConstraint") or {}).get("anyTitleTypeIds")
            if kinds:
                pool = [c for c in pool if c["titleType"]["id"] in kinds]
            genres = (constraints.get("genreConstraint") or {}).get("anyGenreIds")
            if genres:
                pool = [
                    c
                    for c in pool
                    if {g["text"] for g in c["genres"]["genres"]} & set(genres)
                ]
            return {
                "advancedTitleSearch": {
                    "total": len(pool),
                    "pageInfo": {"hasNextPage": False, "endCursor": None},
                    "edges": [{"node": {"title": c}} for c in pool],
                }
            }

        if operation == "ChartTitles":
            chart = variables.get("chart", "")
            pool = [BREAKING_BAD_CARD, ONGOING_CARD] if "TV" in chart else [MATRIX_CARD]
            return {"chartTitles": {"edges": [{"node": c} for c in pool]}}

        if operation == "TitlesByIds":
            ids = variables.get("ids") or []
            return {"titles": [CARDS_BY_ID[i] for i in ids if i in CARDS_BY_ID]}

        if operation == "SearchNames":
            return {"mainSearch": {"edges": [{"node": {"entity": n}} for n in NAMES]}}

        return {}
