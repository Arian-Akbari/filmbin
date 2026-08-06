import '../../core/network/api_client.dart';
import '../models/models.dart';

/// Sections 5.13–5.15 — stars, written reviews and reports.
class ReviewsRepository {
  ReviewsRepository(this._api);

  final ApiClient _api;

  void _invalidate(String imdbId) {
    _api.invalidate('/titles/$imdbId');
    _api.invalidate('/users/me');
  }

  Future<int> rate(String imdbId, int score) async {
    _invalidate(imdbId);
    final data = await _api.post('/titles/$imdbId/rating', data: {'score': score});
    return (data as Map)['score'] as int;
  }

  Future<void> removeRating(String imdbId) async {
    _invalidate(imdbId);
    await _api.delete('/titles/$imdbId/rating');
  }

  Future<ReviewPage> reviews(
    String imdbId, {
    bool hideSpoilers = false,
    int limit = 50,
    int offset = 0,
  }) async {
    final data = await _api.get(
      '/titles/$imdbId/reviews',
      query: {'hide_spoilers': hideSpoilers, 'limit': limit, 'offset': offset},
    );
    return ReviewPage.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<Review> writeReview(
    String imdbId, {
    required String text,
    bool hasSpoiler = false,
  }) async {
    _invalidate(imdbId);
    _api.invalidate('/titles/$imdbId/reviews');
    final data = await _api.post(
      '/titles/$imdbId/reviews',
      data: {'text': text, 'has_spoiler': hasSpoiler},
    );
    return Review.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> deleteReview(int reviewId, {String? imdbId}) async {
    if (imdbId != null) _invalidate(imdbId);
    await _api.delete('/reviews/$reviewId');
  }

  Future<void> report(int reviewId, String reason) =>
      _api.post('/reports', data: {'review_id': reviewId, 'reason': reason});

  Future<ReviewPage> myReviews() async {
    final data = await _api.get('/reviews/mine');
    return ReviewPage.fromJson(Map<String, dynamic>.from(data as Map));
  }
}
