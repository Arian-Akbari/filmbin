import 'package:filmbin/data/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  group('AppUser', () {
    test('parses the profile and its automatic counters', () {
      final user = AppUser.fromJson(kUserJson);

      expect(user.id, 1);
      expect(user.fullName, 'آرین اکبری');
      expect(user.username, 'arian');
      expect(user.isAdmin, isFalse);
      expect(user.summary.watchedMovies, 3);
      expect(user.summary.followedSeries, 2);
      expect(user.summary.favorites, 5);
    });

    test('recognises an administrator', () {
      final admin = AppUser.fromJson({...kUserJson, 'role': 'admin'});
      expect(admin.isAdmin, isTrue);
    });

    test('initials fall back to the username', () {
      expect(AppUser.fromJson(kUserJson).initial, 'آ');
    });
  });

  group('AuthTokens', () {
    test('parses both tokens and the embedded user', () {
      final tokens = AuthTokens.fromJson(kTokensJson);
      expect(tokens.accessToken, 'access-token');
      expect(tokens.refreshToken, 'refresh-token');
      expect(tokens.user.username, 'arian');
    });
  });

  group('TitleSummary', () {
    test('parses a movie card with the caller state attached', () {
      final movie = TitleSummary.fromJson(kMovieJson);

      expect(movie.imdbId, 'tt0133093');
      expect(movie.isSeries, isFalse);
      expect(movie.year, 1999);
      expect(movie.genres, ['Action', 'Sci-Fi']);
      expect(movie.myStatus, WatchStatus.watching);
      expect(movie.myRating, 4);
      expect(movie.isFavorite, isTrue);
      expect(movie.userRatingAverage, 4.5);
    });

    test('formats the runtime the way the detail page shows it', () {
      expect(TitleSummary.fromJson(kMovieJson).runtimeLabel, '۲ ساعت و ۱۶ دقیقه');
      expect(
        TitleSummary.fromJson({...kMovieJson, 'runtime_minutes': 45}).runtimeLabel,
        '۴۵ دقیقه',
      );
      expect(
        TitleSummary.fromJson({...kMovieJson, 'runtime_minutes': null}).runtimeLabel,
        isNull,
      );
    });

    test('shows the release span of a series', () {
      expect(TitleDetail.fromJson(kSeriesDetailJson).summary.yearLabel, '۲۰۰۸–۲۰۱۳');
      expect(TitleSummary.fromJson(kMovieJson).yearLabel, '۱۹۹۹');
    });

    test('survives a payload with missing optional fields', () {
      final sparse = TitleSummary.fromJson({
        'imdb_id': 'tt1',
        'kind': 'movie',
        'title': 'X',
      });
      expect(sparse.title, 'X');
      expect(sparse.genres, isEmpty);
      expect(sparse.myStatus, isNull);
      expect(sparse.posterThumbUrl, isNull);
    });
  });

  group('TitleDetail', () {
    test('parses cast, seasons, distribution and progress', () {
      final detail = TitleDetail.fromJson(kSeriesDetailJson);

      expect(detail.summary.isSeries, isTrue);
      expect(detail.statusLabel, 'پایان‌یافته');
      expect(detail.seasonCount, 5);
      expect(detail.episodeCount, 62);
      expect(detail.cast.first.name, 'Bryan Cranston');
      expect(detail.cast.first.characters.first, 'Walter White');
      expect(detail.seasons.map((s) => s.number), [1, 2]);
      expect(detail.ratingDistribution.length, 5);
      expect(detail.ratingDistribution.last.percent, 50);
      expect(detail.progress!.percent, 50);
      expect(detail.progress!.color, ProgressColor.yellow);
      expect(detail.directors, ['Vince Gilligan']);
      expect(detail.countries, ['United States']);
    });
  });

  group('WatchProgress', () {
    test('maps every colour name from the server', () {
      for (final entry in {
        'none': ProgressColor.none,
        'yellow': ProgressColor.yellow,
        'green': ProgressColor.green,
        'purple': ProgressColor.purple,
        'red': ProgressColor.red,
      }.entries) {
        final progress = WatchProgress.fromJson({
          'total_episodes': 10,
          'watched_episodes': 5,
          'remaining_episodes': 5,
          'percent': 50,
          'color': entry.key,
          'is_ongoing': false,
        });
        expect(progress.color, entry.value);
      }
    });

    test('unknown colour degrades instead of throwing', () {
      final progress = WatchProgress.fromJson({
        'total_episodes': 1,
        'watched_episodes': 0,
        'remaining_episodes': 1,
        'percent': 0,
        'color': 'chartreuse',
        'is_ongoing': false,
      });
      expect(progress.color, ProgressColor.none);
    });

    test('describes itself in Persian', () {
      final progress = WatchProgress.fromJson({
        'total_episodes': 10,
        'watched_episodes': 4,
        'remaining_episodes': 6,
        'percent': 40,
        'color': 'yellow',
        'is_ongoing': false,
      });
      expect(progress.label, '۴ از ۱۰ قسمت');
      expect(progress.fraction, 0.4);
    });
  });

  group('WatchStatus', () {
    test('round-trips through its API value', () {
      for (final status in WatchStatus.values) {
        expect(WatchStatus.fromApi(status.apiValue), status);
      }
    });

    test('has a Persian label for every state', () {
      expect(WatchStatus.planToWatch.label, 'قصد دارم تماشا کنم');
      expect(WatchStatus.watching.label, 'در حال تماشا');
      expect(WatchStatus.watched.label, 'مشاهده شده');
      expect(WatchStatus.paused.label, 'متوقف شده');
      expect(WatchStatus.dropped.label, 'رهاشده');
    });

    test('unknown value maps to null', () {
      expect(WatchStatus.fromApi('sleeping'), isNull);
      expect(WatchStatus.fromApi(null), isNull);
    });
  });

  group('Episode', () {
    test('parses the fields the episode row shows', () {
      final episode = Episode.fromJson(kEpisodeJson);
      expect(episode.seasonNumber, 1);
      expect(episode.episodeNumber, 1);
      expect(episode.title, 'Pilot');
      expect(episode.isWatched, isTrue);
      expect(episode.code, 'S01E01');
      expect(episode.runtimeLabel, '۵۸ دقیقه');
    });
  });

  group('Review', () {
    test('parses author and spoiler flag', () {
      final review = Review.fromJson(kReviewJson);
      expect(review.id, 12);
      expect(review.hasSpoiler, isTrue);
      expect(review.user.username, 'arian');
      expect(review.createdAt.year, 2026);
    });
  });

  group('UserStats', () {
    test('parses the dashboard numbers', () {
      final stats = UserStats.fromJson(kStatsJson);
      expect(stats.watchedMovies, 12);
      expect(stats.watchedEpisodes, 210);
      expect(stats.totalWatchHours, 150.0);
      expect(stats.topGenre, 'Drama');
      expect(stats.favoriteGenres.first.genre, 'Drama');
      expect(stats.averageRating, 4.2);
      expect(stats.watchTimeLabel, '۱۵۰ ساعت');
    });

    test('empty dashboard has no average', () {
      final stats = UserStats.fromJson({
        ...kStatsJson,
        'average_rating': null,
        'favorite_genres': <dynamic>[],
        'total_watch_minutes': 0,
        'total_watch_hours': 0.0,
      });
      expect(stats.averageRating, isNull);
      expect(stats.favoriteGenres, isEmpty);
      expect(stats.watchTimeLabel, '۰ ساعت');
    });
  });
}
