/// Sample payloads copied from real backend responses.
///
/// Keeping them in one place means a change in the API contract breaks the
/// tests loudly instead of leaking into the UI.
library;

const kUserJson = {
  'id': 1,
  'full_name': 'آرین اکبری',
  'username': 'arian',
  'email': 'arian@example.com',
  'avatar_url': null,
  'bio': 'دانشجوی شریف',
  'role': 'user',
  'is_active': true,
  'created_at': '2026-07-01T10:00:00Z',
  'summary': {'watched_movies': 3, 'followed_series': 2, 'favorites': 5},
};

const kTokensJson = {
  'access_token': 'access-token',
  'refresh_token': 'refresh-token',
  'token_type': 'bearer',
  'expires_in': 1800,
  'refresh_expires_in': 2592000,
  'user': kUserJson,
};

const kMovieJson = {
  'imdb_id': 'tt0133093',
  'kind': 'movie',
  'title': 'The Matrix',
  'original_title': 'The Matrix',
  'year': 1999,
  'end_year': null,
  'poster_url': 'https://img/poster._V1_QL75_UX500_.jpg',
  'poster_thumb_url': 'https://img/poster._V1_QL75_UX220_.jpg',
  'plot': 'A computer hacker learns about the true nature of reality.',
  'genres': ['Action', 'Sci-Fi'],
  'runtime_minutes': 136,
  'imdb_rating': 8.7,
  'imdb_votes': 2000000,
  'user_rating_average': 4.5,
  'user_rating_count': 2,
  'my_status': 'watching',
  'my_rating': 4,
  'is_favorite': true,
};

const kSeriesDetailJson = {
  'imdb_id': 'tt0903747',
  'kind': 'series',
  'title': 'Breaking Bad',
  'original_title': 'Breaking Bad',
  'year': 2008,
  'end_year': 2013,
  'poster_url': 'https://img/bb._V1_QL75_UX500_.jpg',
  'poster_thumb_url': 'https://img/bb._V1_QL75_UX220_.jpg',
  'plot': 'A chemistry teacher turns to crime.',
  'genres': ['Crime', 'Drama'],
  'runtime_minutes': 48,
  'imdb_rating': 9.5,
  'imdb_votes': 2600000,
  'user_rating_average': null,
  'user_rating_count': 0,
  'my_status': null,
  'my_rating': null,
  'is_favorite': false,
  'countries': ['United States'],
  'directors': ['Vince Gilligan'],
  'creators': ['Vince Gilligan'],
  'cast': [
    {
      'id': 'nm0186505',
      'name': 'Bryan Cranston',
      'characters': ['Walter White'],
      'image': 'https://img/bc.jpg',
    },
  ],
  'season_count': 5,
  'episode_count': 62,
  'is_ongoing': false,
  'status_label': 'پایان‌یافته',
  'seasons': [
    {'number': 1, 'episode_count': 7},
    {'number': 2, 'episode_count': 13},
  ],
  'rating_distribution': [
    {'score': 1, 'count': 0, 'percent': 0},
    {'score': 2, 'count': 0, 'percent': 0},
    {'score': 3, 'count': 1, 'percent': 25},
    {'score': 4, 'count': 1, 'percent': 25},
    {'score': 5, 'count': 2, 'percent': 50},
  ],
  'my_review': null,
  'progress': {
    'total_episodes': 62,
    'watched_episodes': 31,
    'remaining_episodes': 31,
    'percent': 50,
    'color': 'yellow',
    'is_ongoing': false,
  },
};

const kEpisodeJson = {
  'imdb_id': 'tt0959621',
  'series_id': 'tt0903747',
  'season_number': 1,
  'episode_number': 1,
  'title': 'Pilot',
  'plot': 'Walter cooks.',
  'air_date': '2008-01-20',
  'runtime_minutes': 58,
  'imdb_rating': 9.0,
  'still_url': 'https://img/ep1.jpg',
  'is_watched': true,
};

const kReviewJson = {
  'id': 12,
  'title_id': 'tt0133093',
  'text': 'پایان‌بندی‌اش غافلگیرکننده بود.',
  'has_spoiler': true,
  'created_at': '2026-07-20T09:30:00Z',
  'updated_at': '2026-07-20T09:30:00Z',
  'user': {
    'id': 1,
    'username': 'arian',
    'full_name': 'آرین اکبری',
    'avatar_url': null,
  },
};

const kStatsJson = {
  'watched_movies': 12,
  'watched_series': 4,
  'watched_episodes': 210,
  'total_watch_minutes': 9000,
  'total_watch_hours': 150.0,
  'favorite_genres': [
    {'genre': 'Drama', 'count': 9},
    {'genre': 'Crime', 'count': 5},
  ],
  'top_genre': 'Drama',
  'average_rating': 4.2,
  'ratings_count': 16,
  'reviews_count': 3,
  'favorites_count': 7,
  'lists_count': 2,
  'status_breakdown': {'watching': 3, 'watched': 16},
};

const kErrorEnvelope = {
  'error': {
    'status': 404,
    'code': 'TITLE_NOT_FOUND',
    'message': 'فیلم یا سریال موردنظر پیدا نشد.',
    'detail': 'tt0000000',
  },
};
