import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/models.dart';
import 'core_providers.dart';

enum AuthStatus { unknown, guest, authenticated }

/// Section 4.1 vs 4.2 — the app is fully usable as a guest; signing in only
/// unlocks the parts that write something down.
class AuthState {
  const AuthState({this.status = AuthStatus.unknown, this.user, this.busy = false});

  final AuthStatus status;
  final AppUser? user;
  final bool busy;

  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;
  bool get isAdmin => user?.isAdmin ?? false;

  AuthState copyWith({AuthStatus? status, AppUser? user, bool? busy, bool clearUser = false}) =>
      AuthState(
        status: status ?? this.status,
        user: clearUser ? null : (user ?? this.user),
        busy: busy ?? this.busy,
      );
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._ref) : super(const AuthState());

  final Ref _ref;

  /// Called once on startup: a stored session means no login screen for a month
  /// (section 5.2).
  Future<void> restore() async {
    try {
      final user = await _ref.read(authRepositoryProvider).restoreSession();
      state = user == null
          ? const AuthState(status: AuthStatus.guest)
          : AuthState(status: AuthStatus.authenticated, user: user);
      await _remember(user);
    } on ApiException {
      // Offline at startup. The token is still valid and the mirror still has
      // the user's own data — demoting them to a guest would hide their own
      // watch list behind a login screen they cannot pass (section 8.4).
      final cached = _ref.read(preferencesProvider).cachedProfile;
      state = cached == null
          ? const AuthState(status: AuthStatus.guest)
          : AuthState(status: AuthStatus.authenticated, user: cached);
    }
  }

  Future<void> _remember(AppUser? user) =>
      _ref.read(preferencesProvider).cacheProfile(user);

  Future<void> login({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    state = state.copyWith(busy: true);
    try {
      final tokens = await _ref
          .read(authRepositoryProvider)
          .login(email: email.trim(), password: password, rememberMe: rememberMe);
      state = AuthState(status: AuthStatus.authenticated, user: tokens.user);
      await _remember(tokens.user);
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<void> register({
    required String fullName,
    required String username,
    required String email,
    required String password,
    String? bio,
  }) async {
    state = state.copyWith(busy: true);
    try {
      final tokens = await _ref
          .read(authRepositoryProvider)
          .register(
            fullName: fullName.trim(),
            username: username.trim(),
            email: email.trim(),
            password: password,
            bio: bio?.trim(),
          );
      state = AuthState(status: AuthStatus.authenticated, user: tokens.user);
      await _remember(tokens.user);
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<void> logout() async {
    await _ref.read(authRepositoryProvider).logout();
    await _ref.read(localDatabaseProvider).clearUserData();
    await _remember(null);
    state = const AuthState(status: AuthStatus.guest);
  }

  /// The refresh token stopped working while the app was open.
  Future<void> handleSessionExpired() async {
    if (state.status != AuthStatus.authenticated) return;
    state = const AuthState(status: AuthStatus.guest);
  }

  void continueAsGuest() => state = const AuthState(status: AuthStatus.guest);

  Future<void> refreshProfile() async {
    if (!state.isAuthenticated) return;
    try {
      final user = await _ref.read(userRepositoryProvider).me(forceRefresh: true);
      state = state.copyWith(user: user);
      await _remember(user);
    } on ApiException {
      // A stale profile header is better than an error dialog.
    }
  }

  void updateUser(AppUser user) => state = state.copyWith(user: user);
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(ref),
);

/// Convenience for widgets that only care whether someone is signed in.
final currentUserProvider = Provider<AppUser?>((ref) => ref.watch(authControllerProvider).user);
