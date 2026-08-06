"""Contract tests against the real IMDb endpoint.

Deselected by default (they need the network and they are slow). Run them when
touching `app/imdb/queries.py` to be sure the documents still match the live
schema::

    pytest -m live
"""

from __future__ import annotations

import pytest

from app.imdb import queries as Q
from app.imdb.client import imdb_client
from app.imdb.mapper import map_episode, map_title_card, map_title_details

pytestmark = pytest.mark.live


@pytest.fixture(autouse=True)
async def fresh_client():
    """Each test gets its own connection pool — pytest-asyncio runs every test
    in a new event loop, and an httpx client cannot outlive the loop it was
    created in."""
    await imdb_client.close()
    yield
    await imdb_client.close()


async def test_live_search() -> None:
    data = await imdb_client.execute(
        Q.SEARCH_TITLES,
        {
            "first": 5,
            "constraints": {"titleTextConstraint": {"searchTerm": "inception"}},
            "sort": {"sortBy": "POPULARITY", "sortOrder": "ASC"},
        },
    )
    edges = data["advancedTitleSearch"]["edges"]
    assert edges
    mapped = map_title_card(edges[0]["node"]["title"])
    assert mapped["imdb_id"].startswith("tt")
    assert mapped["title"]


async def test_live_details_and_episodes() -> None:
    data = await imdb_client.execute(Q.TITLE_DETAILS, {"id": "tt0903747"})
    mapped = map_title_details(data["title"])
    assert mapped["title"] == "Breaking Bad"
    assert mapped["kind"] == "series"
    assert mapped["season_count"] == 5
    assert mapped["cast"]

    episodes = await imdb_client.execute(
        Q.SEASON_EPISODES, {"id": "tt0903747", "seasons": ["1"], "first": 10}
    )
    edges = episodes["title"]["episodes"]["episodes"]["edges"]
    first = map_episode(edges[0]["node"], "tt0903747")
    assert first["season_number"] == 1
    assert first["episode_number"] == 1



async def test_live_charts() -> None:
    data = await imdb_client.execute(
        Q.CHART_TITLES, {"chart": "MOST_POPULAR_MOVIES", "first": 5}
    )
    assert len(data["chartTitles"]["edges"]) == 5
