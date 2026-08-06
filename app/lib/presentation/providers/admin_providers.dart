import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/models.dart';
import 'core_providers.dart';

/// Section 4.3 — the admin console. Every provider here hits an endpoint the
/// backend already restricts, so a normal user simply sees the error.
final adminStatsProvider = FutureProvider.autoDispose<AdminStats>(
  (ref) => ref.watch(adminRepositoryProvider).stats(),
);

final adminUsersProvider = FutureProvider.autoDispose.family<List<AdminUserRow>, String?>(
  (ref, query) => ref.watch(adminRepositoryProvider).users(query: query),
);

final adminReviewsProvider = FutureProvider.autoDispose<List<AdminReviewRow>>(
  (ref) => ref.watch(adminRepositoryProvider).reviews(),
);

final adminReportsProvider = FutureProvider.autoDispose<List<AdminReport>>(
  (ref) => ref.watch(adminRepositoryProvider).reports(),
);

final adminTitlesProvider = FutureProvider.autoDispose<List<CachedTitleRow>>(
  (ref) => ref.watch(adminRepositoryProvider).cachedTitles(),
);
