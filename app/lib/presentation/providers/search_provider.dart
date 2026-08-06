import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/models.dart';
import 'core_providers.dart';

/// Section 5.5 — search filters kept as one immutable value.
class SearchFilters {
  const SearchFilters({
    this.query = '',
    this.person = '',
    this.kind,
    this.genres = const [],
    this.yearFrom,
    this.yearTo,
    this.sort = 'popularity',
  });

  final String query;
  final String person;
  final String? kind;
  final List<String> genres;
  final int? yearFrom;
  final int? yearTo;
  final String sort;

  bool get isEmpty =>
      query.trim().isEmpty &&
      person.trim().isEmpty &&
      kind == null &&
      genres.isEmpty &&
      yearFrom == null &&
      yearTo == null;

  int get activeFilterCount =>
      (kind != null ? 1 : 0) +
      genres.length +
      (yearFrom != null || yearTo != null ? 1 : 0) +
      (person.trim().isEmpty ? 0 : 1) +
      (sort == 'popularity' ? 0 : 1);

  SearchFilters copyWith({
    String? query,
    String? person,
    String? kind,
    bool clearKind = false,
    List<String>? genres,
    int? yearFrom,
    int? yearTo,
    bool clearYears = false,
    String? sort,
  }) => SearchFilters(
    query: query ?? this.query,
    person: person ?? this.person,
    kind: clearKind ? null : (kind ?? this.kind),
    genres: genres ?? this.genres,
    yearFrom: clearYears ? null : (yearFrom ?? this.yearFrom),
    yearTo: clearYears ? null : (yearTo ?? this.yearTo),
    sort: sort ?? this.sort,
  );
}

class SearchState {
  const SearchState({
    this.filters = const SearchFilters(),
    this.results = const [],
    this.total = 0,
    this.loading = false,
    this.loadingMore = false,
    this.stale = false,
    this.error,
    this.cursor,
    this.hasSearched = false,
  });

  final SearchFilters filters;
  final List<TitleSummary> results;
  final int total;
  final bool loading;
  final bool loadingMore;
  final bool stale;
  final ApiException? error;
  final String? cursor;
  final bool hasSearched;

  bool get hasMore => cursor != null;
  bool get isEmpty => hasSearched && !loading && results.isEmpty && error == null;

  SearchState copyWith({
    SearchFilters? filters,
    List<TitleSummary>? results,
    int? total,
    bool? loading,
    bool? loadingMore,
    bool? stale,
    ApiException? error,
    bool clearError = false,
    String? cursor,
    bool clearCursor = false,
    bool? hasSearched,
  }) => SearchState(
    filters: filters ?? this.filters,
    results: results ?? this.results,
    total: total ?? this.total,
    loading: loading ?? this.loading,
    loadingMore: loadingMore ?? this.loadingMore,
    stale: stale ?? this.stale,
    error: clearError ? null : (error ?? this.error),
    cursor: clearCursor ? null : (cursor ?? this.cursor),
    hasSearched: hasSearched ?? this.hasSearched,
  );
}

class SearchController extends StateNotifier<SearchState> {
  SearchController(this._ref) : super(const SearchState());

  final Ref _ref;
  Timer? _debounce;
  int _requestId = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// Typing must not fire a request per keystroke (sections 8.1 and 8.8).
  void onQueryChanged(String value) {
    state = state.copyWith(filters: state.filters.copyWith(query: value));
    _debounce?.cancel();
    if (value.trim().isEmpty && state.filters.isEmpty) {
      state = state.copyWith(results: const [], hasSearched: false, clearError: true);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), search);
  }

  void applyFilters(SearchFilters filters) {
    state = state.copyWith(filters: filters);
    search();
  }

  void clear() {
    _debounce?.cancel();
    state = const SearchState();
  }

  Future<void> search() async {
    if (state.filters.isEmpty) return;
    final requestId = ++_requestId;
    state = state.copyWith(loading: true, clearError: true, hasSearched: true);

    try {
      final page = await _run(cursor: null);
      if (requestId != _requestId) return; // a newer search already started
      state = state.copyWith(
        results: page.items,
        total: page.total,
        cursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
        stale: page.stale,
        loading: false,
      );
    } on ApiException catch (error) {
      if (requestId != _requestId) return;
      state = state.copyWith(loading: false, error: error, results: const []);
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.loadingMore || state.loading) return;
    state = state.copyWith(loadingMore: true);
    try {
      final page = await _run(cursor: state.cursor);
      state = state.copyWith(
        results: [...state.results, ...page.items],
        cursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
        loadingMore: false,
      );
    } on ApiException catch (error) {
      state = state.copyWith(loadingMore: false, error: error);
    }
  }

  Future<SearchPage> _run({String? cursor}) {
    final filters = state.filters;
    return _ref
        .read(titlesRepositoryProvider)
        .search(
          query: filters.query.trim().isEmpty ? null : filters.query.trim(),
          person: filters.person.trim().isEmpty ? null : filters.person.trim(),
          kind: filters.kind,
          genres: filters.genres.isEmpty ? null : filters.genres,
          yearFrom: filters.yearFrom,
          yearTo: filters.yearTo,
          sort: filters.sort,
          cursor: cursor,
        );
  }
}

final searchControllerProvider = StateNotifierProvider<SearchController, SearchState>(
  (ref) => SearchController(ref),
);

/// The genre chips offered in the filter sheet — IMDb's own genre ids.
const kGenres = <String, String>{
  'Action': 'اکشن',
  'Adventure': 'ماجراجویی',
  'Animation': 'انیمیشن',
  'Biography': 'زندگی‌نامه',
  'Comedy': 'کمدی',
  'Crime': 'جنایی',
  'Documentary': 'مستند',
  'Drama': 'درام',
  'Family': 'خانوادگی',
  'Fantasy': 'فانتزی',
  'History': 'تاریخی',
  'Horror': 'ترسناک',
  'Music': 'موسیقی',
  'Mystery': 'معمایی',
  'Romance': 'عاشقانه',
  'Sci-Fi': 'علمی-تخیلی',
  'Sport': 'ورزشی',
  'Thriller': 'هیجان‌انگیز',
  'War': 'جنگی',
  'Western': 'وسترن',
};

String genreLabel(String id) => kGenres[id] ?? id;
