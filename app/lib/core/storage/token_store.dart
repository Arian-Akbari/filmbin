import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the session lives (section 8.3 — «توکن کاربر باید به صورت امن نگهداری شود»).
abstract class TokenStore {
  Future<String?> readAccessToken();
  Future<String?> readRefreshToken();
  Future<void> save({required String accessToken, required String refreshToken});
  Future<void> clear();
}

/// Keychain on iOS, EncryptedSharedPreferences on Android — never plain files.
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
          );

  final FlutterSecureStorage _storage;

  static const _accessKey = 'filmbin.access_token';
  static const _refreshKey = 'filmbin.refresh_token';

  String? _cachedAccess;

  @override
  Future<String?> readAccessToken() async =>
      _cachedAccess ??= await _storage.read(key: _accessKey);

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  @override
  Future<void> save({required String accessToken, required String refreshToken}) async {
    _cachedAccess = accessToken;
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  @override
  Future<void> clear() async {
    _cachedAccess = null;
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}

/// Fallback used by widget tests and the emulator when the platform channel is
/// unavailable; never holds anything past the process lifetime.
class InMemoryTokenStore implements TokenStore {
  String? _access;
  String? _refresh;

  @override
  Future<void> clear() async {
    _access = null;
    _refresh = null;
  }

  @override
  Future<String?> readAccessToken() async => _access;

  @override
  Future<String?> readRefreshToken() async => _refresh;

  @override
  Future<void> save({required String accessToken, required String refreshToken}) async {
    _access = accessToken;
    _refresh = refreshToken;
  }
}
