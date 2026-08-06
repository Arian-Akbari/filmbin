import 'review.dart';

/// Section 4.3 — what the admin console shows.
class AdminUserRow {
  const AdminUserRow({
    required this.id,
    required this.fullName,
    required this.username,
    required this.email,
    required this.role,
    required this.isActive,
    required this.createdAt,
    this.reviews = 0,
    this.ratings = 0,
  });

  final int id;
  final String fullName;
  final String username;
  final String email;
  final String role;
  final bool isActive;
  final DateTime createdAt;
  final int reviews;
  final int ratings;

  bool get isAdmin => role == 'admin';

  factory AdminUserRow.fromJson(Map<String, dynamic> json) => AdminUserRow(
    id: (json['id'] as num).toInt(),
    fullName: json['full_name'] as String? ?? '',
    username: json['username'] as String? ?? '',
    email: json['email'] as String? ?? '',
    role: json['role'] as String? ?? 'user',
    isActive: json['is_active'] as bool? ?? true,
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    reviews: (json['reviews'] as num?)?.toInt() ?? 0,
    ratings: (json['ratings'] as num?)?.toInt() ?? 0,
  );
}

class AdminReport {
  const AdminReport({
    required this.id,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.reporterUsername,
    this.review,
    this.resolutionNote,
  });

  final int id;
  final String reason;
  final String status;
  final DateTime createdAt;
  final String? reporterUsername;
  final Review? review;
  final String? resolutionNote;

  bool get isPending => status == 'pending';

  factory AdminReport.fromJson(Map<String, dynamic> json) => AdminReport(
    id: (json['id'] as num).toInt(),
    reason: json['reason'] as String? ?? '',
    status: json['status'] as String? ?? 'pending',
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    reporterUsername: json['reporter_username'] as String?,
    review: json['review'] == null
        ? null
        : Review.fromJson(Map<String, dynamic>.from(json['review'] as Map)),
    resolutionNote: json['resolution_note'] as String?,
  );
}

class AdminReviewRow {
  const AdminReviewRow({required this.review, required this.isHidden, this.titleName});

  final Review review;
  final bool isHidden;
  final String? titleName;

  factory AdminReviewRow.fromJson(Map<String, dynamic> json) => AdminReviewRow(
    review: Review.fromJson(json),
    isHidden: json['is_hidden'] as bool? ?? false,
    titleName: json['title_name'] as String?,
  );
}

class AdminStats {
  const AdminStats({
    required this.users,
    required this.activeUsers,
    required this.admins,
    required this.cachedTitles,
    required this.cachedEpisodes,
    required this.ratings,
    required this.reviews,
    required this.hiddenReviews,
    required this.lists,
    required this.pendingReports,
    required this.watchEntries,
    required this.episodeMarks,
    required this.activeSessions,
    required this.imdbCircuitOpen,
    required this.mostTracked,
  });

  final int users;
  final int activeUsers;
  final int admins;
  final int cachedTitles;
  final int cachedEpisodes;
  final int ratings;
  final int reviews;
  final int hiddenReviews;
  final int lists;
  final int pendingReports;
  final int watchEntries;
  final int episodeMarks;
  final int activeSessions;
  final bool imdbCircuitOpen;
  final List<TrackedTitle> mostTracked;

  factory AdminStats.fromJson(Map<String, dynamic> json) => AdminStats(
    users: (json['users'] as num?)?.toInt() ?? 0,
    activeUsers: (json['active_users'] as num?)?.toInt() ?? 0,
    admins: (json['admins'] as num?)?.toInt() ?? 0,
    cachedTitles: (json['cached_titles'] as num?)?.toInt() ?? 0,
    cachedEpisodes: (json['cached_episodes'] as num?)?.toInt() ?? 0,
    ratings: (json['ratings'] as num?)?.toInt() ?? 0,
    reviews: (json['reviews'] as num?)?.toInt() ?? 0,
    hiddenReviews: (json['hidden_reviews'] as num?)?.toInt() ?? 0,
    lists: (json['lists'] as num?)?.toInt() ?? 0,
    pendingReports: (json['pending_reports'] as num?)?.toInt() ?? 0,
    watchEntries: (json['watch_entries'] as num?)?.toInt() ?? 0,
    episodeMarks: (json['episode_marks'] as num?)?.toInt() ?? 0,
    activeSessions: (json['active_sessions'] as num?)?.toInt() ?? 0,
    imdbCircuitOpen: json['imdb_circuit_open'] as bool? ?? false,
    mostTracked: ((json['most_tracked'] as List?) ?? const [])
        .map((e) => TrackedTitle.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );
}

class TrackedTitle {
  const TrackedTitle({required this.imdbId, required this.title, required this.count});

  final String imdbId;
  final String title;
  final int count;

  factory TrackedTitle.fromJson(Map<String, dynamic> json) => TrackedTitle(
    imdbId: json['imdb_id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    count: (json['count'] as num?)?.toInt() ?? 0,
  );
}

class CachedTitleRow {
  const CachedTitleRow({
    required this.imdbId,
    required this.kind,
    required this.title,
    required this.hasDetails,
    required this.fetchedAt,
    this.year,
    this.trackedBy = 0,
  });

  final String imdbId;
  final String kind;
  final String title;
  final bool hasDetails;
  final DateTime fetchedAt;
  final int? year;
  final int trackedBy;

  factory CachedTitleRow.fromJson(Map<String, dynamic> json) => CachedTitleRow(
    imdbId: json['imdb_id'] as String,
    kind: json['kind'] as String? ?? 'movie',
    title: json['title'] as String? ?? '',
    hasDetails: json['has_details'] as bool? ?? false,
    fetchedAt: DateTime.tryParse(json['fetched_at'] as String? ?? '') ?? DateTime.now(),
    year: (json['year'] as num?)?.toInt(),
    trackedBy: (json['tracked_by'] as num?)?.toInt() ?? 0,
  );
}
