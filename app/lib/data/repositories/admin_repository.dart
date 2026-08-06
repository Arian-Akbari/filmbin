import '../../core/network/api_client.dart';
import '../models/models.dart';

/// Section 4.3 — admin console calls. Every one of these is refused by the
/// backend for a normal user, so the UI only hides what is already protected.
class AdminRepository {
  AdminRepository(this._api);

  final ApiClient _api;

  Future<List<AdminUserRow>> users({String? query}) async {
    final data = await _api.get('/admin/users', query: {'q': query}, forceRefresh: true);
    return ((data as Map)['items'] as List)
        .map((e) => AdminUserRow.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<AdminUserRow> updateUser(int userId, {bool? isActive, String? role}) async {
    _api.invalidate('/admin');
    final data = await _api.patch(
      '/admin/users/$userId',
      data: {'is_active': ?isActive, 'role': ?role},
    );
    return AdminUserRow.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<List<AdminReviewRow>> reviews() async {
    final data = await _api.get('/admin/reviews', forceRefresh: true);
    return ((data as Map)['items'] as List)
        .map((e) => AdminReviewRow.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> hideReview(int reviewId) async {
    _api.invalidate('/admin');
    await _api.delete('/admin/reviews/$reviewId');
  }

  Future<List<AdminReport>> reports({String? status}) async {
    final data = await _api.get(
      '/admin/reports',
      query: {'status': status},
      forceRefresh: true,
    );
    return ((data as Map)['items'] as List)
        .map((e) => AdminReport.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<AdminReport> resolveReport(
    int reportId, {
    required String status,
    bool deleteReview = false,
    String? note,
  }) async {
    _api.invalidate('/admin');
    final data = await _api.patch(
      '/admin/reports/$reportId',
      data: {'status': status, 'delete_review': deleteReview, 'resolution_note': ?note},
    );
    return AdminReport.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<List<CachedTitleRow>> cachedTitles() async {
    final data = await _api.get('/admin/titles', forceRefresh: true);
    return ((data as Map)['items'] as List)
        .map((e) => CachedTitleRow.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> refreshTitle(String imdbId) async {
    _api.invalidate('/titles/$imdbId');
    await _api.post('/admin/titles/$imdbId/refresh');
  }

  Future<void> evictTitle(String imdbId) async {
    _api.invalidate('/titles/$imdbId');
    _api.invalidate('/admin');
    await _api.delete('/admin/titles/$imdbId');
  }

  Future<AdminStats> stats() async {
    final data = await _api.get('/admin/stats', forceRefresh: true);
    return AdminStats.fromJson(Map<String, dynamic>.from(data as Map));
  }
}
