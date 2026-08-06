import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../storage/token_store.dart';
import 'api_exception.dart';
import 'certificate_pinning.dart';
import 'interceptors.dart';

/// The one place the app talks to the network.
///
/// Repositories get decoded JSON and typed [ApiException]s; everything else —
/// tokens, retries, caching, TLS pinning — is handled by the interceptors
/// wired up here.
class ApiClient {
  ApiClient._(this._dio, this._cache);

  final Dio _dio;
  final CacheInterceptor? _cache;

  Dio get dio => _dio;

  /// Test seam: hand in a mock and skip the whole interceptor stack.
  factory ApiClient.withDio(Dio dio) => ApiClient._(dio, null);

  factory ApiClient.create({
    required AppConfig config,
    required TokenStore tokens,
    required Future<void> Function() onSessionExpired,
  }) {
    final options = BaseOptions(
      baseUrl: config.baseUrl,
      connectTimeout: config.connectTimeout,
      receiveTimeout: config.receiveTimeout,
      headers: {'Accept': 'application/json'},
      responseType: ResponseType.json,
    );

    final dio = Dio(options);
    final refreshClient = Dio(options);
    applyCertificatePinning(dio, config);
    applyCertificatePinning(refreshClient, config);

    final cache = CacheInterceptor(ttl: config.cacheTtl);
    dio.interceptors.addAll([
      AuthInterceptor(
        tokens: tokens,
        refreshClient: refreshClient,
        onSessionExpired: onSessionExpired,
      ),
      cache,
      RetryInterceptor(),
      if (kDebugMode)
        LogInterceptor(requestBody: false, responseBody: false, requestHeader: false),
    ]);

    return ApiClient._(dio, cache);
  }

  void clearCache() => _cache?.clear();

  /// Drops cached GETs whose URL contains [fragment] — used after a write so
  /// the next read reflects it.
  void invalidate(String fragment) => _cache?.invalidateWhere((key) => key.contains(fragment));

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    bool forceRefresh = false,
  }) async {
    return _guard(() async {
      final response = forceRefresh
          ? await _dio.get<dynamic>(
              path,
              queryParameters: _clean(query),
              options: Options(headers: {CacheInterceptor.noCacheHeader: true}),
            )
          : await _dio.get<dynamic>(path, queryParameters: _clean(query));
      return response.data;
    });
  }

  Future<dynamic> post(String path, {Object? data}) =>
      _guard(() async => (await _dio.post<dynamic>(path, data: data)).data);

  Future<dynamic> put(String path, {Object? data}) =>
      _guard(() async => (await _dio.put<dynamic>(path, data: data)).data);

  Future<dynamic> patch(String path, {Object? data}) =>
      _guard(() async => (await _dio.patch<dynamic>(path, data: data)).data);

  Future<dynamic> delete(String path, {Object? data}) =>
      _guard(() async => (await _dio.delete<dynamic>(path, data: data)).data);

  Future<dynamic> upload(String path, FormData form) =>
      _guard(() async => (await _dio.post<dynamic>(path, data: form)).data);

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (error) {
      throw ApiException.fromDioError(error);
    }
  }

  static Map<String, dynamic>? _clean(Map<String, dynamic>? query) {
    if (query == null) return null;
    final cleaned = <String, dynamic>{};
    query.forEach((key, value) {
      if (value == null) return;
      if (value is Iterable && value.isEmpty) return;
      if (value is String && value.isEmpty) return;
      cleaned[key] = value;
    });
    return cleaned.isEmpty ? null : cleaned;
  }
}
