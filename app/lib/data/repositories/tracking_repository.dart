import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/local_database.dart';
import '../models/models.dart';

/// Sections 5.9–5.12 and 5.16 — the user's own state on a title.
///
/// Writes are optimistic on disk: the local row is updated first, and if the
/// request fails because the phone is offline it goes to the outbox and is
/// replayed later, so no activity is lost (section 8.4).
class TrackingRepository {
  TrackingRepository(this._api, [this._local]);

  final ApiClient _api;
  final LocalDatabase? _local;

  void _invalidate(String imdbId) {
    _api.invalidate('/titles/$imdbId');
    _api.invalidate('/watchlist');
    _api.invalidate('/users/me');
  }

  Future<void> _queueIfOffline(
    ApiException error,
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    if (!error.isOffline && !error.isTimeout) throw error;
    await _local?.enqueue(method, path, body);
  }

  Future<WatchStatus?> setStatus(String imdbId, WatchStatus status) async {
    _invalidate(imdbId);
    await _local?.upsertWatchEntry(imdbId, status: status);
    try {
      final data = await _api.put('/titles/$imdbId/status', data: {'status': status.apiValue});
      return WatchStatus.fromApi((data as Map)['status'] as String?);
    } on ApiException catch (error) {
      await _queueIfOffline(error, 'PUT', '/titles/$imdbId/status', {
        'status': status.apiValue,
      });
      return status;
    }
  }

  Future<void> clearStatus(String imdbId) async {
    _invalidate(imdbId);
    await _local?.removeWatchEntry(imdbId);
    try {
      await _api.delete('/titles/$imdbId/status');
    } on ApiException catch (error) {
      await _queueIfOffline(error, 'DELETE', '/titles/$imdbId/status');
    }
  }

  Future<bool> setFavorite(String imdbId, bool value) async {
    _invalidate(imdbId);
    await _local?.upsertWatchEntry(imdbId, isFavorite: value);
    try {
      final data = value
          ? await _api.put('/titles/$imdbId/favorite')
          : await _api.delete('/titles/$imdbId/favorite');
      return (data as Map)['is_favorite'] as bool? ?? value;
    } on ApiException catch (error) {
      await _queueIfOffline(error, value ? 'PUT' : 'DELETE', '/titles/$imdbId/favorite');
      return value;
    }
  }

  Future<WatchProgress> markEpisode(String imdbId, String episodeId) async {
    _invalidate(imdbId);
    final data = await _api.put('/titles/$imdbId/episodes/$episodeId/watch');
    return WatchProgress.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<WatchProgress> unmarkEpisode(String imdbId, String episodeId) async {
    _invalidate(imdbId);
    final data = await _api.delete('/titles/$imdbId/episodes/$episodeId/watch');
    return WatchProgress.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<WatchProgress> markSeason(String imdbId, int season, {required bool watched}) async {
    _invalidate(imdbId);
    final data = watched
        ? await _api.put('/titles/$imdbId/seasons/$season/watch')
        : await _api.delete('/titles/$imdbId/seasons/$season/watch');
    return WatchProgress.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<WatchProgress> progress(String imdbId) async {
    final data = await _api.get('/titles/$imdbId/progress');
    return WatchProgress.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<WatchlistResult> watchlist({WatchStatus? status, String? kind}) async {
    try {
      final data = await _api.get(
        '/watchlist',
        query: {'status': status?.apiValue, 'kind': kind},
      );
      final result = WatchlistResult.fromJson(Map<String, dynamic>.from(data as Map));
      await _local?.saveWatchlist(result.items);
      return result;
    } on ApiException catch (error) {
      final offline = await _local?.readWatchlist(status: status);
      if ((error.isOffline || error.isTimeout) && offline != null && offline.isNotEmpty) {
        return WatchlistResult(items: offline, counts: const {}, total: offline.length);
      }
      rethrow;
    }
  }

  Future<WatchlistResult> favorites() async {
    try {
      final data = await _api.get('/watchlist/favorites');
      final result = WatchlistResult.fromJson(Map<String, dynamic>.from(data as Map));
      await _local?.saveWatchlist(result.items);
      return result;
    } on ApiException catch (error) {
      final offline = await _local?.readWatchlist(favoritesOnly: true);
      if ((error.isOffline || error.isTimeout) && offline != null && offline.isNotEmpty) {
        return WatchlistResult(items: offline, counts: const {}, total: offline.length);
      }
      rethrow;
    }
  }

  /// Replays everything the user did while offline. Failures stay queued.
  Future<int> flushOutbox() async {
    final local = _local;
    if (local == null) return 0;

    var replayed = 0;
    for (final action in await local.pendingActions()) {
      try {
        switch (action.method) {
          case 'PUT':
            await _api.put(action.path, data: action.body);
          case 'POST':
            await _api.post(action.path, data: action.body);
          case 'DELETE':
            await _api.delete(action.path, data: action.body);
        }
        await local.removeAction(action.id);
        replayed++;
      } on ApiException catch (error) {
        if (error.isOffline) break;
        // A permanent failure (410/404/422) would retry forever — drop it.
        await local.removeAction(action.id);
      }
    }
    return replayed;
  }
}
