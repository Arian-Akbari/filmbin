import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/local_database.dart';
import '../../core/storage/preferences.dart';
import '../../core/storage/token_store.dart';
import '../../data/repositories/admin_repository.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/lists_repository.dart';
import '../../data/repositories/reviews_repository.dart';
import '../../data/repositories/titles_repository.dart';
import '../../data/repositories/tracking_repository.dart';
import '../../data/repositories/user_repository.dart';
import 'auth_provider.dart';

/// Wiring. Everything below is a single object with a single owner, so a test
/// can swap any layer by overriding one provider.

final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.fromEnvironment);

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

/// Overridden in `main()` with the database opened at startup.
final localDatabaseProvider = Provider<LocalDatabase>(
  (ref) => throw UnimplementedError('localDatabaseProvider must be overridden'),
);

/// Overridden in `main()` once SharedPreferences has loaded.
final preferencesProvider = Provider<Preferences>(
  (ref) => throw UnimplementedError('preferencesProvider must be overridden'),
);

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient.create(
    config: ref.watch(appConfigProvider),
    tokens: ref.watch(tokenStoreProvider),
    // A refresh token that no longer works means the session is over; the
    // controller drops the user back to guest mode instead of leaving the UI
    // stuck on endless 401s.
    onSessionExpired: () async =>
        ref.read(authControllerProvider.notifier).handleSessionExpired(),
  );
});

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider), ref.watch(tokenStoreProvider)),
);

final titlesRepositoryProvider = Provider<TitlesRepository>(
  (ref) => TitlesRepository(ref.watch(apiClientProvider), ref.watch(localDatabaseProvider)),
);

final trackingRepositoryProvider = Provider<TrackingRepository>(
  (ref) => TrackingRepository(ref.watch(apiClientProvider), ref.watch(localDatabaseProvider)),
);

final reviewsRepositoryProvider = Provider<ReviewsRepository>(
  (ref) => ReviewsRepository(ref.watch(apiClientProvider)),
);

final listsRepositoryProvider = Provider<ListsRepository>(
  (ref) => ListsRepository(ref.watch(apiClientProvider)),
);

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(ref.watch(apiClientProvider)),
);

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(ref.watch(apiClientProvider)),
);
