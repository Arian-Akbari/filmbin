import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/auth_provider.dart';
import 'screens/admin/admin_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/feed_screen.dart';
import 'screens/home_screen.dart';
import 'screens/lists/list_detail_screen.dart';
import 'screens/lists/lists_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/profile/public_profile_screen.dart';
import 'screens/profile/settings_screen.dart';
import 'screens/profile/stats_screen.dart';
import 'screens/search_screen.dart';
import 'screens/shell.dart';
import 'screens/splash_screen.dart';
import 'screens/title/season_screen.dart';
import 'screens/title/title_detail_screen.dart';
import 'screens/watchlist_screen.dart';

final _rootKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();

/// Section 4.1 — browsing is open to everyone; only the routes that write
/// something require an account, and each screen asks for it in place.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/forgot', builder: (_, _) => const ForgotPasswordScreen()),
      ShellRoute(
        navigatorKey: _shellKey,
        builder: (_, _, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
          GoRoute(path: '/search', builder: (_, _) => const SearchScreen()),
          GoRoute(path: '/watchlist', builder: (_, _) => const WatchlistScreen()),
          GoRoute(path: '/lists', builder: (_, _) => const ListsScreen()),
          GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
        ],
      ),
      GoRoute(
        path: '/title/:id',
        builder: (_, state) => TitleDetailScreen(imdbId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'season/:season',
            builder: (_, state) => SeasonScreen(
              imdbId: state.pathParameters['id']!,
              season: int.parse(state.pathParameters['season']!),
              seriesTitle: state.extra as String? ?? '',
            ),
          ),
          GoRoute(
            path: 'chat',
            builder: (_, state) => ChatScreen(
              imdbId: state.pathParameters['id']!,
              titleName: state.extra as String? ?? '',
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/list/:id',
        builder: (_, state) => ListDetailScreen(listId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(path: '/profile/edit', builder: (_, _) => const EditProfileScreen()),
      GoRoute(path: '/stats', builder: (_, _) => const StatsScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(path: '/feed', builder: (_, _) => const FeedScreen()),
      GoRoute(
        path: '/user/:username',
        builder: (_, state) => PublicProfileScreen(username: state.pathParameters['username']!),
      ),
      GoRoute(path: '/admin', builder: (_, _) => const AdminScreen()),
    ],
    redirect: (context, state) {
      final status = ref.read(authControllerProvider).status;
      final atSplash = state.matchedLocation == '/';
      if (status == AuthStatus.unknown) return atSplash ? null : '/';
      if (atSplash) return '/home';
      return null;
    },
    refreshListenable: _AuthListenable(ref),
  );
});

/// Bridges the auth state into go_router's refresh mechanism.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(authControllerProvider, (previous, next) {
      if (previous?.status != next.status) notifyListeners();
    });
  }
}

/// Sends the user to the sign-in screen and comes back to where they were.
Future<void> promptSignIn(BuildContext context) async {
  await context.push('/login');
}
