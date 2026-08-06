"""GraphQL documents sent to IMDb's public endpoint.

Everything the app shows comes from these six documents. They are kept in one
place so swapping the data source later (section 8.6 — maintainability) means
touching this file and `mapper.py`, nothing else.
"""

TITLE_CARD_FRAGMENT = """
fragment TitleCard on Title {
  id
  titleText { text }
  originalTitleText { text }
  titleType { id text isSeries canHaveEpisodes }
  releaseYear { year endYear }
  primaryImage { url width height }
  ratingsSummary { aggregateRating voteCount }
  runtime { seconds }
  genres { genres { text } }
  plot { plotText { plainText } }
}
"""

SEARCH_TITLES = (
    TITLE_CARD_FRAGMENT
    + """
query SearchTitles(
  $first: Int!
  $after: String
  $constraints: AdvancedTitleSearchConstraints!
  $sort: AdvancedTitleSearchSort
) {
  advancedTitleSearch(first: $first, after: $after, constraints: $constraints, sort: $sort) {
    total
    pageInfo { hasNextPage endCursor }
    edges { node { title { ...TitleCard } } }
  }
}
"""
)

SEARCH_NAMES = """
query SearchNames($q: String!, $first: Int!) {
  mainSearch(first: $first, options: {searchTerm: $q, isExactMatch: false, type: NAME}) {
    edges {
      node {
        entity {
          ... on Name {
            id
            nameText { text }
            primaryImage { url }
            primaryProfessions { category { text } }
          }
        }
      }
    }
  }
}
"""

TITLE_DETAILS = (
    TITLE_CARD_FRAGMENT
    + """
query TitleDetails($id: ID!) {
  title(id: $id) {
    ...TitleCard
    countriesOfOrigin { countries { id text } }
    principalCredits {
      category { id text }
      credits { name { id nameText { text } primaryImage { url } } }
    }
    credits(first: 20) {
      total
      edges {
        node {
          category { id text }
          name { id nameText { text } primaryImage { url } }
          ... on Cast { characters { name } }
        }
      }
    }
    episodes {
      isOngoing
      displayableSeasons(first: 80) { edges { node { season text } } }
      episodes(first: 1) { total }
    }
  }
}
"""
)

SEASON_EPISODES = """
query SeasonEpisodes($id: ID!, $seasons: [String!], $first: Int!, $after: ID) {
  title(id: $id) {
    episodes {
      episodes(
        first: $first
        after: $after
        filter: { includeSeasons: $seasons }
        sort: { by: EPISODE_THEN_RELEASE, order: ASC }
      ) {
        total
        pageInfo { hasNextPage endCursor }
        edges {
          node {
            id
            titleText { text }
            series { episodeNumber { seasonNumber episodeNumber } }
            releaseDate { year month day }
            runtime { seconds }
            plot { plotText { plainText } }
            ratingsSummary { aggregateRating }
            primaryImage { url }
          }
        }
      }
    }
  }
}
"""

CHART_TITLES = (
    TITLE_CARD_FRAGMENT
    + """
query ChartTitles($chart: ChartTitleType!, $first: Int!) {
  chartTitles(chart: { chartType: $chart }, first: $first) {
    edges { node { ...TitleCard } }
  }
}
"""
)

TITLES_BY_IDS = (
    TITLE_CARD_FRAGMENT
    + """
query TitlesByIds($ids: [ID!]!) {
  titles(ids: $ids) { ...TitleCard }
}
"""
)
