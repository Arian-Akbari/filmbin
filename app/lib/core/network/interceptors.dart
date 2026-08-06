import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../storage/token_store.dart';

/// Adds the bearer token and, when it has expired, refreshes it once and
/// replays the request (section 7.6 on the server, deck 07 on the client).
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required this.tokens,
    required this.refreshClient,
    required this.onSessionExpired,
  });

  final TokenStore tokens;

  /// A bare Dio without this interceptor — refreshing must not recurse.
  final Dio refreshClient;
  final Future<void> Function() onSessionExpired;

  static const _skipHeader = 'x-skip-auth';

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.headers.remove(_skipHeader) == null) {
      final token = await tokens.readAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final isAuthCall = err.requestOptions.path.startsWith('/auth/');
    if (err.response?.statusCode != 401 || isAuthCall) {
      return handler.next(err);
    }

    final refreshToken = await tokens.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await onSessionExpired();
      return handler.next(err);
    }

    try {
      final response = await refreshClient.post<dynamic>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      await tokens.save(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
      );

      final retried = err.requestOptions
        ..headers['Authorization'] = 'Bearer ${data['access_token']}';
      final result = await refreshClient.fetch<dynamic>(retried);
      return handler.resolve(result);
    } on DioException catch (_) {
      await onSessionExpired();
      return handler.next(err);
    }
  }
}

/// Retries transient failures with a growing delay (section 8.4).
///
/// Only safe methods are retried — replaying a POST could create a second
/// review or a second rating, which section 8.4 explicitly forbids.
class RetryInterceptor extends Interceptor {
  RetryInterceptor({this.maxAttempts = 2, this.baseDelay = const Duration(milliseconds: 400)});

  final int maxAttempts;
  final Duration baseDelay;

  static const _attemptKey = 'retry-attempt';

  bool _isTransient(DioException error) =>
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout ||
      error.type == DioExceptionType.connectionError ||
      (error.response?.statusCode ?? 0) >= 500;

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final method = options.method.toUpperCase();
    final attempt = (options.extra[_attemptKey] as int?) ?? 0;

    if (method != 'GET' || !_isTransient(err) || attempt >= maxAttempts) {
      return handler.next(err);
    }

    await Future<void>.delayed(baseDelay * (attempt + 1));
    options.extra[_attemptKey] = attempt + 1;

    try {
      final response = await Dio(BaseOptions(baseUrl: options.baseUrl)).fetch<dynamic>(options);
      return handler.resolve(response);
    } on DioException catch (retryError) {
      return handler.next(retryError);
    }
  }
}

/// A small GET cache.
///
/// Two jobs: stop the app from asking the same question twice in a row
/// (sections 8.1 and 8.8), and keep the last good answer around so a screen can
/// still render when the network drops (section 8.4).
class CacheInterceptor extends Interceptor {
  CacheInterceptor({this.ttl = const Duration(minutes: 10), this.maxEntries = 120});

  final Duration ttl;
  final int maxEntries;
  final Map<String, _CacheEntry> _entries = {};

  static const noCacheHeader = 'x-no-cache';

  String _key(RequestOptions options) =>
      '${options.method}:${options.uri}:${options.headers['Authorization'] ?? ''}';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.method.toUpperCase() != 'GET') return handler.next(options);
    if (options.headers.remove(noCacheHeader) != null) return handler.next(options);

    final entry = _entries[_key(options)];
    if (entry != null && !entry.isStale(ttl)) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: entry.data,
          extra: {'from_cache': true},
        ),
      );
    }
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    if (response.requestOptions.method.toUpperCase() == 'GET' &&
        response.statusCode == 200 &&
        response.extra['from_cache'] != true) {
      if (_entries.length >= maxEntries) {
        final oldest = _entries.entries.reduce(
          (a, b) => a.value.storedAt.isBefore(b.value.storedAt) ? a : b,
        );
        _entries.remove(oldest.key);
      }
      _entries[_key(response.requestOptions)] = _CacheEntry(response.data, DateTime.now());
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final entry = _entries[_key(err.requestOptions)];
    final offline =
        err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout;

    if (entry != null && offline) {
      debugPrint('serving cached response for ${err.requestOptions.uri}');
      return handler.resolve(
        Response(
          requestOptions: err.requestOptions,
          statusCode: 200,
          data: entry.data,
          extra: {'from_cache': true, 'stale': true},
        ),
      );
    }
    handler.next(err);
  }

  void clear() => _entries.clear();

  void invalidateWhere(bool Function(String key) predicate) =>
      _entries.removeWhere((key, _) => predicate(key));
}

class _CacheEntry {
  _CacheEntry(this.data, this.storedAt);

  final dynamic data;
  final DateTime storedAt;

  bool isStale(Duration ttl) => DateTime.now().difference(storedAt) > ttl;
}
