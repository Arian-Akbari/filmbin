import '../../core/utils/formatters.dart';

/// The three counters every profile carries (section 5.1).
class UserSummary {
  const UserSummary({this.watchedMovies = 0, this.followedSeries = 0, this.favorites = 0});

  final int watchedMovies;
  final int followedSeries;
  final int favorites;

  factory UserSummary.fromJson(Map<String, dynamic>? json) => UserSummary(
    watchedMovies: (json?['watched_movies'] as num?)?.toInt() ?? 0,
    followedSeries: (json?['followed_series'] as num?)?.toInt() ?? 0,
    favorites: (json?['favorites'] as num?)?.toInt() ?? 0,
  );
}

class AppUser {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.username,
    required this.email,
    required this.role,
    required this.createdAt,
    this.avatarUrl,
    this.bio,
    this.isActive = true,
    this.summary = const UserSummary(),
    this.followers = 0,
    this.following = 0,
    this.isFollowing = false,
  });

  final int id;
  final String fullName;
  final String username;
  final String email;
  final String role;
  final DateTime createdAt;
  final String? avatarUrl;
  final String? bio;
  final bool isActive;
  final UserSummary summary;
  final int followers;
  final int following;
  final bool isFollowing;

  bool get isAdmin => role == 'admin';

  /// First letter, used by the avatar placeholder.
  String get initial {
    final source = fullName.trim().isNotEmpty ? fullName.trim() : username;
    return source.isEmpty ? '؟' : source.substring(0, 1);
  }

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: (json['id'] as num).toInt(),
    fullName: json['full_name'] as String? ?? '',
    username: json['username'] as String? ?? '',
    email: json['email'] as String? ?? '',
    role: json['role'] as String? ?? 'user',
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    avatarUrl: json['avatar_url'] as String?,
    bio: json['bio'] as String?,
    isActive: json['is_active'] as bool? ?? true,
    summary: UserSummary.fromJson(json['summary'] as Map<String, dynamic>?),
    followers: (json['followers'] as num?)?.toInt() ?? 0,
    following: (json['following'] as num?)?.toInt() ?? 0,
    isFollowing: json['is_following'] as bool? ?? false,
  );

  /// Cached verbatim so the app can still say who you are with no network
  /// (section 8.4). Mirrors [fromJson] exactly.
  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'username': username,
        'email': email,
        'role': role,
        'created_at': createdAt.toIso8601String(),
        'avatar_url': avatarUrl,
        'bio': bio,
        'is_active': isActive,
        'summary': {
          'watched_movies': summary.watchedMovies,
          'followed_series': summary.followedSeries,
          'favorites': summary.favorites,
        },
        'followers': followers,
        'following': following,
        'is_following': isFollowing,
      };

  AppUser copyWith({String? fullName, String? username, String? bio, String? avatarUrl}) =>
      AppUser(
        id: id,
        fullName: fullName ?? this.fullName,
        username: username ?? this.username,
        email: email,
        role: role,
        createdAt: createdAt,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        bio: bio ?? this.bio,
        isActive: isActive,
        summary: summary,
        followers: followers,
        following: following,
        isFollowing: isFollowing,
      );
}

class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.refreshExpiresIn,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final int refreshExpiresIn;
  final AppUser user;

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
    accessToken: json['access_token'] as String,
    refreshToken: json['refresh_token'] as String,
    expiresIn: (json['expires_in'] as num?)?.toInt() ?? 0,
    refreshExpiresIn: (json['refresh_expires_in'] as num?)?.toInt() ?? 0,
    user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
  );
}

class GenreCount {
  const GenreCount(this.genre, this.count);

  final String genre;
  final int count;

  factory GenreCount.fromJson(Map<String, dynamic> json) =>
      GenreCount(json['genre'] as String? ?? '', (json['count'] as num?)?.toInt() ?? 0);
}

/// Section 5.19 — the activity dashboard.
class UserStats {
  const UserStats({
    required this.watchedMovies,
    required this.watchedSeries,
    required this.watchedEpisodes,
    required this.totalWatchMinutes,
    required this.totalWatchHours,
    required this.favoriteGenres,
    required this.ratingsCount,
    required this.reviewsCount,
    required this.favoritesCount,
    required this.listsCount,
    required this.statusBreakdown,
    this.topGenre,
    this.averageRating,
  });

  final int watchedMovies;
  final int watchedSeries;
  final int watchedEpisodes;
  final int totalWatchMinutes;
  final double totalWatchHours;
  final List<GenreCount> favoriteGenres;
  final int ratingsCount;
  final int reviewsCount;
  final int favoritesCount;
  final int listsCount;
  final Map<String, int> statusBreakdown;
  final String? topGenre;
  final double? averageRating;

  String get watchTimeLabel => Formatters.hours(totalWatchHours);

  factory UserStats.fromJson(Map<String, dynamic> json) => UserStats(
    watchedMovies: (json['watched_movies'] as num?)?.toInt() ?? 0,
    watchedSeries: (json['watched_series'] as num?)?.toInt() ?? 0,
    watchedEpisodes: (json['watched_episodes'] as num?)?.toInt() ?? 0,
    totalWatchMinutes: (json['total_watch_minutes'] as num?)?.toInt() ?? 0,
    totalWatchHours: (json['total_watch_hours'] as num?)?.toDouble() ?? 0,
    favoriteGenres: ((json['favorite_genres'] as List?) ?? const [])
        .map((e) => GenreCount.fromJson(e as Map<String, dynamic>))
        .toList(),
    ratingsCount: (json['ratings_count'] as num?)?.toInt() ?? 0,
    reviewsCount: (json['reviews_count'] as num?)?.toInt() ?? 0,
    favoritesCount: (json['favorites_count'] as num?)?.toInt() ?? 0,
    listsCount: (json['lists_count'] as num?)?.toInt() ?? 0,
    statusBreakdown: ((json['status_breakdown'] as Map?) ?? const {}).map(
      (key, value) => MapEntry(key as String, (value as num).toInt()),
    ),
    topGenre: json['top_genre'] as String?,
    averageRating: (json['average_rating'] as num?)?.toDouble(),
  );
}
