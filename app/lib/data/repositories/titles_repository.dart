import '../../core/network/api_client.dart';
import '../../core/storage/local_database.dart';
import '../models/models.dart';

/// Sections 5.5–5.8 and 5.18 — reading the catalogue.
///
/// The local database is written through on every successful read so the home
/// screen and the watch list still have something to show with no connection
/// (section 8.4).
class TitlesRepository {
  TitlesRepository(this._api, [this._local]);

  final ApiClient _api;
  final LocalDatabase? _local;

  Future<SearchPage> search({
    String? query,
    String? kind,
    List<String>? genres,
    int? yearFrom,
    int? yearTo,
    String? person,
    String sort = 'popularity',
    int limit = 20,
    String? cursor,
  }) async {
    final data = await _api.get(
      '/titles/search',
      query: {
        'q': query,
        'kind': kind,
        'genre': genres,
        'year_from': yearFrom,
        'year_to': yearTo,
        'person': person,
        'sort': sort,
        'limit': limit,
        'cursor': cursor,
      },
    );
    final page = SearchPage.fromJson(Map<String, dynamic>.from(data as Map));
    await _local?.cacheTitles(page.items);
    return page;
  }

  Future<List<PersonSuggestion>> people(String query) async {
    final data = await _api.get('/titles/people', query: {'q': query});
    return (data as List)
        .map((e) => PersonSuggestion.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<DiscoverSection>> discover({bool forceRefresh = false}) async {
    final data = await _api.get('/titles/discover', forceRefresh: forceRefresh);
    final sections = ((data as Map)['sections'] as List)
        .map((e) => DiscoverSection.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    await _local?.saveSections(sections);
    return sections;
  }

  /// Whatever the home screen showed last time, straight from disk.
  Future<List<DiscoverSection>> cachedSections() async =>
      await _local?.readSections() ?? const [];

  Future<SearchPage> recommended() async {
    final data = await _api.get('/titles/recommended');
    final map = Map<String, dynamic>.from(data as Map);
    return SearchPage.fromJson({...map, 'total': (map['items'] as List).length});
  }

  Future<TitleDetail> detail(String imdbId, {bool forceRefresh = false}) async {
    final data = await _api.get('/titles/$imdbId', forceRefresh: forceRefresh);
    final detail = TitleDetail.fromJson(Map<String, dynamic>.from(data as Map));
    await _local?.cacheTitles([detail.summary]);
    return detail;
  }

  Future<List<SeasonInfo>> seasons(String imdbId) async {
    final data = await _api.get('/titles/$imdbId/seasons');
    return (data as List)
        .map((e) => SeasonInfo.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<Episode>> episodes(String imdbId, int season, {bool forceRefresh = false}) async {
    final data = await _api.get(
      '/titles/$imdbId/seasons/$season/episodes',
      forceRefresh: forceRefresh,
    );
    return (data as List)
        .map((e) => Episode.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
