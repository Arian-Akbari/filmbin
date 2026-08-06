import '../../core/utils/formatters.dart';

/// Section 5.8 — one row of the episode list.
class Episode {
  const Episode({
    required this.imdbId,
    required this.seriesId,
    required this.seasonNumber,
    required this.episodeNumber,
    this.title,
    this.plot,
    this.airDate,
    this.runtimeMinutes,
    this.imdbRating,
    this.stillUrl,
    this.isWatched = false,
  });

  final String imdbId;
  final String seriesId;
  final int seasonNumber;
  final int episodeNumber;
  final String? title;
  final String? plot;
  final String? airDate;
  final int? runtimeMinutes;
  final double? imdbRating;
  final String? stillUrl;
  final bool isWatched;

  /// `S01E02` — kept in Latin digits on purpose, it is a code, not a number.
  String get code =>
      'S${seasonNumber.toString().padLeft(2, '0')}E${episodeNumber.toString().padLeft(2, '0')}';

  String? get runtimeLabel => Formatters.duration(runtimeMinutes);
  String? get airDateLabel => Formatters.airDate(airDate);

  factory Episode.fromJson(Map<String, dynamic> json) => Episode(
    imdbId: json['imdb_id'] as String,
    seriesId: json['series_id'] as String? ?? '',
    seasonNumber: (json['season_number'] as num?)?.toInt() ?? 0,
    episodeNumber: (json['episode_number'] as num?)?.toInt() ?? 0,
    title: json['title'] as String?,
    plot: json['plot'] as String?,
    airDate: json['air_date'] as String?,
    runtimeMinutes: (json['runtime_minutes'] as num?)?.toInt(),
    imdbRating: (json['imdb_rating'] as num?)?.toDouble(),
    stillUrl: json['still_url'] as String?,
    isWatched: json['is_watched'] as bool? ?? false,
  );

  Episode copyWith({bool? isWatched}) => Episode(
    imdbId: imdbId,
    seriesId: seriesId,
    seasonNumber: seasonNumber,
    episodeNumber: episodeNumber,
    title: title,
    plot: plot,
    airDate: airDate,
    runtimeMinutes: runtimeMinutes,
    imdbRating: imdbRating,
    stillUrl: stillUrl,
    isWatched: isWatched ?? this.isWatched,
  );
}
