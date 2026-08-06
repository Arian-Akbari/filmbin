import 'package:dio/dio.dart';

/// Every network failure the UI can see, already translated (section 5.20).
///
/// The backend answers errors in one shape, so parsing happens once, here, and
/// screens only deal with `message`, `code` and `fields`.
class ApiException implements Exception {
  const ApiException({
    required this.message,
    required this.code,
    this.statusCode,
    this.detail,
    this.fields = const {},
  });

  final String message;
  final String code;
  final int? statusCode;
  final dynamic detail;
  final Map<String, String> fields;

  bool get isOffline => code == 'NO_CONNECTION';
  bool get isTimeout => code == 'TIMEOUT';
  bool get isAuthError => statusCode == 401 || code == 'TOKEN_EXPIRED';
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isValidation => code == 'VALIDATION_ERROR' || statusCode == 422;
  bool get isRateLimited => code == 'RATE_LIMITED';
  bool get isServiceDown =>
      code == 'UPSTREAM_UNAVAILABLE' || code == 'UPSTREAM_ERROR' || statusCode == 503;

  /// True when retrying later has a real chance of working.
  bool get isRetryable => isOffline || isTimeout || isServiceDown || isRateLimited;

  factory ApiException.fromDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(
          message: 'پاسخ سرور بیش از حد طول کشید. دوباره تلاش کنید.',
          code: 'TIMEOUT',
        );
      case DioExceptionType.connectionError:
        return const ApiException(message: 'اتصال اینترنت برقرار نیست.', code: 'NO_CONNECTION');
      case DioExceptionType.badCertificate:
        return const ApiException(
          message: 'ارتباط با سرور امن نیست و برقرار نشد.',
          code: 'INSECURE_CONNECTION',
        );
      case DioExceptionType.cancel:
        return const ApiException(message: 'درخواست لغو شد.', code: 'CANCELLED');
      default:
        return ApiException.fromResponse(error.response, fallback: error.message);
    }
  }

  factory ApiException.fromResponse(Response<dynamic>? response, {String? fallback}) {
    final status = response?.statusCode;
    final data = response?.data;

    if (data is Map && data['error'] is Map) {
      final error = Map<String, dynamic>.from(data['error'] as Map);
      final rawFields = error['fields'];
      return ApiException(
        message: error['message'] as String? ?? _messageFor(status),
        code: error['code'] as String? ?? 'UNKNOWN',
        statusCode: (error['status'] as num?)?.toInt() ?? status,
        detail: error['detail'],
        fields: rawFields is Map
            ? rawFields.map((key, value) => MapEntry('$key', '$value'))
            : const {},
      );
    }

    return ApiException(
      message: _messageFor(status, fallback: fallback),
      code: status == null ? 'NETWORK_ERROR' : 'HTTP_$status',
      statusCode: status,
    );
  }

  static String _messageFor(int? status, {String? fallback}) {
    switch (status) {
      case 400:
        return 'درخواست نامعتبر بود.';
      case 401:
        return 'برای این کار باید وارد حساب کاربری شوید.';
      case 403:
        return 'به این بخش دسترسی ندارید.';
      case 404:
        return 'موردی که دنبالش بودید پیدا نشد.';
      case 409:
        return 'این مورد از قبل وجود دارد.';
      case 422:
        return 'اطلاعات واردشده معتبر نیست.';
      case 429:
        return 'تعداد درخواست‌ها زیاد است. کمی بعد دوباره تلاش کنید.';
      case 500:
        return 'خطایی در سرور رخ داد.';
      case 502:
      case 503:
        return 'سرویس اطلاعاتی در دسترس نیست.';
      default:
        return fallback?.isNotEmpty == true
            ? 'ارتباط با سرور برقرار نشد.'
            : 'خطای ناشناخته‌ای رخ داد.';
    }
  }

  @override
  String toString() => 'ApiException($code, $statusCode): $message';
}
