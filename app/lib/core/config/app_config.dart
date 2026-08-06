/// Build-time configuration.
///
/// Override without touching code:
/// ```
/// flutter run --dart-define=API_BASE_URL=https://10.0.2.2:8443/api/v1
/// ```
/// `10.0.2.2` is the host machine as seen from the Android emulator.
library;

class AppConfig {
  const AppConfig({
    required this.baseUrl,
    required this.pinnedCertificateSha256,
    this.connectTimeout = const Duration(seconds: 10),
    this.receiveTimeout = const Duration(seconds: 15),
    this.cacheTtl = const Duration(minutes: 10),
  });

  final String baseUrl;

  /// SHA-256 of `backend/certs/server.crt`, printed by
  /// `backend/scripts/generate_certs.sh`. Empty disables pinning, which is only
  /// acceptable over plain HTTP during development (section 8.3).
  final String pinnedCertificateSha256;

  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Duration cacheTtl;

  bool get isSecure => baseUrl.startsWith('https');
  bool get pinningEnabled => isSecure && pinnedCertificateSha256.isNotEmpty;

  String get origin {
    final uri = Uri.parse(baseUrl);
    return '${uri.scheme}://${uri.authority}';
  }

  /// WebSocket origin for the live chat room.
  String get socketOrigin => origin.replaceFirst(RegExp('^http'), 'ws');

  static const AppConfig fromEnvironment = AppConfig(
    baseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:8000/api/v1',
    ),
    pinnedCertificateSha256: String.fromEnvironment(
      'PINNED_CERT_SHA256',
      defaultValue: 'e2ac83c6c0c4e22c43be87bd2646302fe14a5a3a8cacd46dd314aa735d422a1b',
    ),
  );
}
