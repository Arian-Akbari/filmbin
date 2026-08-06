import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/models.dart';
import 'auth_provider.dart';
import 'core_providers.dart';

/// Section 5.18 — the home rails. Cached rails are shown first so the screen
/// has content before the network answers (section 8.1: under three seconds).
final discoverProvider = FutureProvider.autoDispose<List<DiscoverSection>>((ref) async {
  ref.watch(authControllerProvider.select((s) => s.user?.id));
  final repository = ref.watch(titlesRepositoryProvider);
  try {
    return await repository.discover();
  } on ApiException {
    final cached = await repository.cachedSections();
    if (cached.isNotEmpty) return cached;
    rethrow;
  }
});

final recommendedProvider = FutureProvider.autoDispose<SearchPage>((ref) async {
  final auth = ref.watch(authControllerProvider);
  if (!auth.isAuthenticated) return const SearchPage(items: [], total: 0);
  return ref.watch(titlesRepositoryProvider).recommended();
});

final titleDetailProvider = FutureProvider.autoDispose.family<TitleDetail, String>((
  ref,
  imdbId,
) async {
  ref.watch(authControllerProvider.select((s) => s.user?.id));
  return ref.watch(titlesRepositoryProvider).detail(imdbId);
});

final seasonEpisodesProvider = FutureProvider.autoDispose
    .family<List<Episode>, ({String imdbId, int season})>((ref, key) async {
      ref.watch(authControllerProvider.select((s) => s.user?.id));
      return ref.watch(titlesRepositoryProvider).episodes(key.imdbId, key.season);
    });

final titleProgressProvider = FutureProvider.autoDispose.family<WatchProgress?, String>((
  ref,
  imdbId,
) async {
  if (!ref.watch(authControllerProvider).isAuthenticated) return null;
  return ref.watch(trackingRepositoryProvider).progress(imdbId);
});

final reviewsProvider = FutureProvider.autoDispose.family<ReviewPage, String>((
  ref,
  imdbId,
) async {
  return ref.watch(reviewsRepositoryProvider).reviews(imdbId);
});

/// Section 5.12 — the watch list, filtered by status.
final watchlistProvider = FutureProvider.autoDispose.family<WatchlistResult, WatchStatus?>((
  ref,
  status,
) async {
  if (!ref.watch(authControllerProvider).isAuthenticated) {
    return const WatchlistResult(items: [], counts: {}, total: 0);
  }
  return ref.watch(trackingRepositoryProvider).watchlist(status: status);
});

final favoritesProvider = FutureProvider.autoDispose<WatchlistResult>((ref) async {
  if (!ref.watch(authControllerProvider).isAuthenticated) {
    return const WatchlistResult(items: [], counts: {}, total: 0);
  }
  return ref.watch(trackingRepositoryProvider).favorites();
});

final myListsProvider = FutureProvider.autoDispose<List<CustomList>>((ref) async {
  if (!ref.watch(authControllerProvider).isAuthenticated) return const [];
  return ref.watch(listsRepositoryProvider).myLists();
});

final listDetailProvider = FutureProvider.autoDispose.family<CustomList, int>((
  ref,
  listId,
) async {
  return ref.watch(listsRepositoryProvider).detail(listId);
});

/// Section 5.19 — the activity dashboard.
final userStatsProvider = FutureProvider.autoDispose<UserStats>((ref) async {
  return ref.watch(userRepositoryProvider).stats();
});

final feedProvider = FutureProvider.autoDispose<List<FeedItem>>((ref) async {
  if (!ref.watch(authControllerProvider).isAuthenticated) return const [];
  return ref.watch(userRepositoryProvider).feed();
});

final publicProfileProvider = FutureProvider.autoDispose.family<AppUser, String>((
  ref,
  username,
) async {
  return ref.watch(userRepositoryProvider).profile(username);
});

/// Refresh everything that depends on one title after a write.
void invalidateTitle(WidgetRef ref, String imdbId) {
  ref.invalidate(titleDetailProvider(imdbId));
  ref.invalidate(titleProgressProvider(imdbId));
  ref.invalidate(reviewsProvider(imdbId));
  for (final status in [null, ...WatchStatus.values]) {
    ref.invalidate(watchlistProvider(status));
  }
  ref.invalidate(favoritesProvider);
  ref.invalidate(userStatsProvider);
}
