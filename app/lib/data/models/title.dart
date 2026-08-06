import '../../core/utils/formatters.dart';
import 'review.dart';

/// Section 5.9 — the states a title can be in for one user.
enum WatchStatus {
  planToWatch('plan_to_watch', 'قصد دارم تماشا کنم'),
  watching('watching', 'در حال تماشا'),
  watched('watched', 'مشاهده شده'),
  paused('paused', 'متوقف شده'),
  dropped('dropped', 'رهاشده');

  const WatchStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static WatchStatus? fromApi(String? value) {
    for (final status in WatchStatus.values) {
      if (status.apiValue == value) return status;
    }
    return null;
  }
}

/// Section 5.11 — the colour of the progress bar, decided by the server.
enum ProgressColor {
  none('none'),
  yellow('yellow'),
  green('green'),
  purple('purple'),
  red('red');

  const ProgressColor(this.apiValue);

  final String apiValue;

  static ProgressColor fromApi(String? value) {
    for (final color in ProgressColor.values) {
      if (color.apiValue == value) return color;
    }
    return ProgressColor.none;
  }
}

class WatchProgress {
  const WatchProgress({
    required this.totalEpisodes,
    required this.watchedEpisodes,
    required this.remainingEpisodes,
    required this.percent,
    required this.color,
    required this.isOngoing,
  });

  final int totalEpisodes;
  final int watchedEpisodes;
  final int remainingEpisodes;
  final int percent;
  final ProgressColor color;
  final bool isOngoing;

  double get fraction => (percent / 100).clamp(0, 1).toDouble();

  String get label =>
      '${Formatters.digits('$watchedEpisodes')} از ${Formatters.digits('$totalEpisodes')} قسمت';

  factory WatchProgress.fromJson(Map<String, dynamic> json) => WatchProgress(
    totalEpisodes: (json['total_episodes'] as num?)?.toInt() ?? 0,
    watchedEpisodes: (json['watched_episodes'] as num?)?.toInt() ?? 0,
    remainingEpisodes: (json['remaining_episodes'] as num?)?.toInt() ?? 0,
    percent: (json['percent'] as num?)?.toInt() ?? 0,
    color: ProgressColor.fromApi(json['color'] as String?),
    isOngoing: json['is_ongoing'] as bool? ?? false,
  );
}

class TitleSummary {
  const TitleSummary({
    required this.imdbId,
    required this.kind,
    required this.title,
    this.originalTitle,
    this.year,
    this.endYear,
    this.posterUrl,
    this.posterThumbUrl,
    this.plot,
    this.genres = const [],
    this.runtimeMinutes,
    this.imdbRating,
    this.imdbVotes,
    this.userRatingAverage,
    this.userRatingCount = 0,
    this.myStatus,
    this.myRating,
    this.isFavorite = false,
  });

  final String imdbId;
  final String kind;
  final String title;
  final String? originalTitle;
  final int? year;
  final int? endYear;
  final String? posterUrl;
  final String? posterThumbUrl;
  final String? plot;
  final List<String> genres;
  final int? runtimeMinutes;
  final double? imdbRating;
  final int? imdbVotes;
  final double? userRatingAverage;
  final int userRatingCount;
  final WatchStatus? myStatus;
  final int? myRating;
  final bool isFavorite;

  bool get isSeries => kind == 'series';

  String? get runtimeLabel => Formatters.duration(runtimeMinutes);

  String? get yearLabel {
    if (year == null) return null;
    if (isSeries && endYear != null && endYear != year) {
      return '${Formatters.digits('$year')}–${Formatters.digits('$endYear')}';
    }
    return Formatters.digits('$year');
  }

  String get kindLabel => isSeries ? 'سریال' : 'فیلم';

  factory TitleSummary.fromJson(Map<String, dynamic> json) => TitleSummary(
    imdbId: json['imdb_id'] as String,
    kind: json['kind'] as String? ?? 'movie',
    title: json['title'] as String? ?? '',
    originalTitle: json['original_title'] as String?,
    year: (json['year'] as num?)?.toInt(),
    endYear: (json['end_year'] as num?)?.toInt(),
    posterUrl: json['poster_url'] as String?,
    posterThumbUrl: json['poster_thumb_url'] as String?,
    plot: json['plot'] as String?,
    genres: ((json['genres'] as List?) ?? const []).map((e) => '$e').toList(),
    runtimeMinutes: (json['runtime_minutes'] as num?)?.toInt(),
    imdbRating: (json['imdb_rating'] as num?)?.toDouble(),
    imdbVotes: (json['imdb_votes'] as num?)?.toInt(),
    userRatingAverage: (json['user_rating_average'] as num?)?.toDouble(),
    userRatingCount: (json['user_rating_count'] as num?)?.toInt() ?? 0,
    myStatus: WatchStatus.fromApi(json['my_status'] as String?),
    myRating: (json['my_rating'] as num?)?.toInt(),
    isFavorite: json['is_favorite'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'imdb_id': imdbId,
    'kind': kind,
    'title': title,
    'original_title': originalTitle,
    'year': year,
    'end_year': endYear,
    'poster_url': posterUrl,
    'poster_thumb_url': posterThumbUrl,
    'plot': plot,
    'genres': genres,
    'runtime_minutes': runtimeMinutes,
    'imdb_rating': imdbRating,
    'imdb_votes': imdbVotes,
    'user_rating_average': userRatingAverage,
    'user_rating_count': userRatingCount,
    'my_status': myStatus?.apiValue,
    'my_rating': myRating,
    'is_favorite': isFavorite,
  };

  TitleSummary copyWith({
    WatchStatus? myStatus,
    bool clearStatus = false,
    int? myRating,
    bool clearRating = false,
    bool? isFavorite,
  }) => TitleSummary(
    imdbId: imdbId,
    kind: kind,
    title: title,
    originalTitle: originalTitle,
    year: year,
    endYear: endYear,
    posterUrl: posterUrl,
    posterThumbUrl: posterThumbUrl,
    plot: plot,
    genres: genres,
    runtimeMinutes: runtimeMinutes,
    imdbRating: imdbRating,
    imdbVotes: imdbVotes,
    userRatingAverage: userRatingAverage,
    userRatingCount: userRatingCount,
    myStatus: clearStatus ? null : (myStatus ?? this.myStatus),
    myRating: clearRating ? null : (myRating ?? this.myRating),
    isFavorite: isFavorite ?? this.isFavorite,
  );
}

class CastMember {
  const CastMember({required this.name, this.id, this.characters = const [], this.image});

  final String name;
  final String? id;
  final List<String> characters;
  final String? image;

  String? get roleLabel => characters.isEmpty ? null : characters.join('، ');

  factory CastMember.fromJson(Map<String, dynamic> json) => CastMember(
    name: json['name'] as String? ?? '',
    id: json['id'] as String?,
    characters: ((json['characters'] as List?) ?? const []).map((e) => '$e').toList(),
    image: json['image'] as String?,
  );
}

class SeasonInfo {
  const SeasonInfo({required this.number, required this.episodeCount});

  final int number;
  final int episodeCount;

  factory SeasonInfo.fromJson(Map<String, dynamic> json) => SeasonInfo(
    number: (json['number'] as num).toInt(),
    episodeCount: (json['episode_count'] as num?)?.toInt() ?? 0,
  );
}

/// One bar of the star histogram (section 5.13).
class RatingBucket {
  const RatingBucket({required this.score, required this.count, required this.percent});

  final int score;
  final int count;
  final int percent;

  factory RatingBucket.fromJson(Map<String, dynamic> json) => RatingBucket(
    score: (json['score'] as num).toInt(),
    count: (json['count'] as num?)?.toInt() ?? 0,
    percent: (json['percent'] as num?)?.toInt() ?? 0,
  );
}

class TitleDetail {
  const TitleDetail({
    required this.summary,
    this.countries = const [],
    this.directors = const [],
    this.creators = const [],
    this.cast = const [],
    this.seasons = const [],
    this.ratingDistribution = const [],
    this.seasonCount,
    this.episodeCount,
    this.isOngoing,
    this.statusLabel,
    this.myReview,
    this.progress,
  });

  final TitleSummary summary;
  final List<String> countries;
  final List<String> directors;
  final List<String> creators;
  final List<CastMember> cast;
  final List<SeasonInfo> seasons;
  final List<RatingBucket> ratingDistribution;
  final int? seasonCount;
  final int? episodeCount;
  final bool? isOngoing;
  final String? statusLabel;
  final Review? myReview;
  final WatchProgress? progress;

  String get imdbId => summary.imdbId;
  bool get isSeries => summary.isSeries;

  factory TitleDetail.fromJson(Map<String, dynamic> json) => TitleDetail(
    summary: TitleSummary.fromJson(json),
    countries: ((json['countries'] as List?) ?? const []).map((e) => '$e').toList(),
    directors: ((json['directors'] as List?) ?? const []).map((e) => '$e').toList(),
    creators: ((json['creators'] as List?) ?? const []).map((e) => '$e').toList(),
    cast: ((json['cast'] as List?) ?? const [])
        .map((e) => CastMember.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    seasons: ((json['seasons'] as List?) ?? const [])
        .map((e) => SeasonInfo.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    ratingDistribution: ((json['rating_distribution'] as List?) ?? const [])
        .map((e) => RatingBucket.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    seasonCount: (json['season_count'] as num?)?.toInt(),
    episodeCount: (json['episode_count'] as num?)?.toInt(),
    isOngoing: json['is_ongoing'] as bool?,
    statusLabel: json['status_label'] as String?,
    myReview: json['my_review'] == null
        ? null
        : Review.fromJson(Map<String, dynamic>.from(json['my_review'] as Map)),
    progress: json['progress'] == null
        ? null
        : WatchProgress.fromJson(Map<String, dynamic>.from(json['progress'] as Map)),
  );

  TitleDetail copyWith({
    TitleSummary? summary,
    WatchProgress? progress,
    Review? myReview,
    bool clearReview = false,
    List<RatingBucket>? ratingDistribution,
  }) => TitleDetail(
    summary: summary ?? this.summary,
    countries: countries,
    directors: directors,
    creators: creators,
    cast: cast,
    seasons: seasons,
    ratingDistribution: ratingDistribution ?? this.ratingDistribution,
    seasonCount: seasonCount,
    episodeCount: episodeCount,
    isOngoing: isOngoing,
    statusLabel: statusLabel,
    myReview: clearReview ? null : (myReview ?? this.myReview),
    progress: progress ?? this.progress,
  );
}

class SearchPage {
  const SearchPage({
    required this.items,
    required this.total,
    this.nextCursor,
    this.stale = false,
    this.personalized = false,
    this.basedOn = const [],
  });

  final List<TitleSummary> items;
  final int total;
  final String? nextCursor;
  final bool stale;

  /// Only meaningful for the recommendation shelf: false means the picks are
  /// just what is popular, so the shelf has nothing personal to say yet.
  final bool personalized;
  final List<String> basedOn;

  bool get hasMore => nextCursor != null;

  factory SearchPage.fromJson(Map<String, dynamic> json) => SearchPage(
    items: ((json['items'] as List?) ?? const [])
        .map((e) => TitleSummary.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    total: (json['total'] as num?)?.toInt() ?? 0,
    nextCursor: json['next_cursor'] as String?,
    stale: json['stale'] as bool? ?? false,
    personalized: json['personalized'] as bool? ?? false,
    basedOn: ((json['based_on'] as List?) ?? const []).map((e) => '$e').toList(),
  );
}

class DiscoverSection {
  const DiscoverSection({required this.key, required this.title, required this.items});

  final String key;
  final String title;
  final List<TitleSummary> items;

  factory DiscoverSection.fromJson(Map<String, dynamic> json) => DiscoverSection(
    key: json['key'] as String,
    title: json['title'] as String? ?? '',
    items: ((json['items'] as List?) ?? const [])
        .map((e) => TitleSummary.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );
}

class PersonSuggestion {
  const PersonSuggestion({
    required this.id,
    required this.name,
    this.image,
    this.professions = const [],
  });

  final String id;
  final String name;
  final String? image;
  final List<String> professions;

  factory PersonSuggestion.fromJson(Map<String, dynamic> json) => PersonSuggestion(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    image: json['image'] as String?,
    professions: ((json['professions'] as List?) ?? const []).map((e) => '$e').toList(),
  );
}

class WatchlistResult {
  const WatchlistResult({required this.items, required this.counts, required this.total});

  final List<TitleSummary> items;
  final Map<WatchStatus, int> counts;
  final int total;

  factory WatchlistResult.fromJson(Map<String, dynamic> json) {
    final counts = <WatchStatus, int>{};
    ((json['counts'] as Map?) ?? const {}).forEach((key, value) {
      final status = WatchStatus.fromApi(key as String);
      if (status != null) counts[status] = (value as num).toInt();
    });
    return WatchlistResult(
      items: ((json['items'] as List?) ?? const [])
          .map((e) => TitleSummary.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      counts: counts,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}
