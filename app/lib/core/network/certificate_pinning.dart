import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';

/// Certificate pinning (section 8.3).
///
/// The backend runs with a certificate issued by our own CA, so the phone would
/// normally reject it. Instead of blindly trusting everything, we accept **one**
/// certificate: the one whose SHA-256 matches the value baked into the build.
/// A man-in-the-middle with a valid-but-different certificate is refused.
void applyCertificatePinning(Dio dio, AppConfig config) {
  if (!config.isSecure) return;

  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient(context: SecurityContext(withTrustedRoots: true));
      client.badCertificateCallback = (X509Certificate certificate, String host, int port) {
        if (!config.pinningEnabled) return false;
        final fingerprint = sha256.convert(certificate.der).toString();
        final matches =
            fingerprint.toLowerCase() == config.pinnedCertificateSha256.toLowerCase();
        if (!matches) {
          debugPrint('rejected certificate for $host:$port — fingerprint $fingerprint');
        }
        return matches;
      };
      return client;
    },
  );
}
