import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/token_store.dart';
import '../models/models.dart';

/// Sections 5.1–5.3 — the account lifecycle.
class AuthRepository {
  AuthRepository(this._api, this._tokens);

  final ApiClient _api;
  final TokenStore _tokens;

  Future<AuthTokens> register({
    required String fullName,
    required String username,
    required String email,
    required String password,
    String? bio,
  }) async {
    final data = await _api.post(
      '/auth/register',
      data: {
        'full_name': fullName,
        'username': username,
        'email': email,
        'password': password,
        if (bio != null && bio.isNotEmpty) 'bio': bio,
      },
    );
    return _store(data);
  }

  Future<AuthTokens> login({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    final data = await _api.post(
      '/auth/login',
      data: {'email': email, 'password': password, 'remember_me': rememberMe},
    );
    return _store(data);
  }

  /// Signing out must succeed locally even when the server cannot be reached,
  /// otherwise the user is stuck signed in on a broken connection.
  Future<void> logout() async {
    try {
      final refresh = await _tokens.readRefreshToken();
      if (refresh != null) {
        await _api.post('/auth/logout', data: {'refresh_token': refresh});
      }
    } catch (_) {
      // ignored on purpose — see above
    } finally {
      await _tokens.clear();
      _api.clearCache();
    }
  }

  /// Section 5.2 — a stored session means no login screen for a month.
  Future<AppUser?> restoreSession() async {
    final token = await _tokens.readAccessToken();
    if (token == null || token.isEmpty) return null;
    try {
      final data = await _api.get('/users/me');
      return AppUser.fromJson(Map<String, dynamic>.from(data as Map));
    } on ApiException catch (error) {
      if (error.isAuthError || error.isForbidden) {
        await _tokens.clear();
        return null;
      }
      rethrow;
    }
  }

  /// Section 5.3. In development the backend hands the token straight back so
  /// the flow can be finished without a mail server.
  Future<String?> requestPasswordReset(String email) async {
    final data = await _api.post('/auth/password/forgot', data: {'email': email});
    return (data as Map)['reset_token'] as String?;
  }

  Future<void> resetPassword({required String token, required String password}) =>
      _api.post('/auth/password/reset', data: {'token': token, 'password': password});

  Future<AuthTokens> _store(dynamic data) async {
    final tokens = AuthTokens.fromJson(Map<String, dynamic>.from(data as Map));
    await _tokens.save(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken);
    _api.clearCache();
    return tokens;
  }
}
