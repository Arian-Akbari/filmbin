import 'package:dio/dio.dart';
import 'package:filmbin/core/network/api_exception.dart';
import 'package:filmbin/core/utils/formatters.dart';
import 'package:filmbin/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

RequestOptions _options() => RequestOptions(path: '/titles/tt1');

void main() {
  group('ApiException', () {
    test('reads the error envelope the backend sends', () {
      final failure = ApiException.fromDioError(
        DioException(
          requestOptions: _options(),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: _options(),
            statusCode: 404,
            data: kErrorEnvelope,
          ),
        ),
      );

      expect(failure.code, 'TITLE_NOT_FOUND');
      expect(failure.statusCode, 404);
      expect(failure.message, 'فیلم یا سریال موردنظر پیدا نشد.');
      expect(failure.isNotFound, isTrue);
      expect(failure.isAuthError, isFalse);
    });

    test('field errors come back for form validation', () {
      final failure = ApiException.fromDioError(
        DioException(
          requestOptions: _options(),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: _options(),
            statusCode: 422,
            data: {
              'error': {
                'status': 422,
                'code': 'VALIDATION_ERROR',
                'message': 'اطلاعات ارسال‌شده معتبر نیست.',
                'fields': {'email': 'ایمیل: قالب درست نیست'},
              },
            },
          ),
        ),
      );

      expect(failure.fields['email'], contains('ایمیل'));
      expect(failure.isValidation, isTrue);
    });

    test('no connection produces the offline message (section 5.20)', () {
      final failure = ApiException.fromDioError(
        DioException(requestOptions: _options(), type: DioExceptionType.connectionError),
      );

      expect(failure.code, 'NO_CONNECTION');
      expect(failure.message, 'اتصال اینترنت برقرار نیست.');
      expect(failure.isOffline, isTrue);
    });

    test('timeouts say so explicitly', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.sendTimeout,
      ]) {
        final failure = ApiException.fromDioError(
          DioException(requestOptions: _options(), type: type),
        );
        expect(failure.code, 'TIMEOUT');
        expect(failure.message, contains('طول کشید'));
      }
    });

    test('a 503 from the backend is reported as service unavailable', () {
      final failure = ApiException.fromDioError(
        DioException(
          requestOptions: _options(),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: _options(),
            statusCode: 503,
            data: {
              'error': {
                'status': 503,
                'code': 'UPSTREAM_UNAVAILABLE',
                'message': 'سرویس اطلاعاتی در دسترس نیست.',
              },
            },
          ),
        ),
      );
      expect(failure.code, 'UPSTREAM_UNAVAILABLE');
      expect(failure.isServiceDown, isTrue);
    });

    test('an unparseable body still yields a readable message', () {
      final failure = ApiException.fromDioError(
        DioException(
          requestOptions: _options(),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: _options(),
            statusCode: 500,
            data: '<html>boom</html>',
          ),
        ),
      );
      expect(failure.message, isNotEmpty);
      expect(failure.statusCode, 500);
    });

    test('a pinning failure is surfaced as a security error', () {
      final failure = ApiException.fromDioError(
        DioException(
          requestOptions: _options(),
          type: DioExceptionType.badCertificate,
        ),
      );
      expect(failure.code, 'INSECURE_CONNECTION');
      expect(failure.message, contains('امن'));
    });
  });

  group('Validators', () {
    test('email', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('not-an-email'), isNotNull);
      expect(Validators.email('arian@example.com'), isNull);
    });

    test('password needs eight characters', () {
      expect(Validators.password('123'), isNotNull);
      expect(Validators.password('Str0ngPass!'), isNull);
    });

    test('username matches the backend rule', () {
      expect(Validators.username('a'), isNotNull);
      expect(Validators.username('has space'), isNotNull);
      expect(Validators.username('arian_2'), isNull);
    });

    test('required and confirmation', () {
      expect(Validators.required(''), isNotNull);
      expect(Validators.required('  '), isNotNull);
      expect(Validators.required('x'), isNull);
      expect(Validators.confirm('a', 'b'), isNotNull);
      expect(Validators.confirm('a', 'a'), isNull);
    });
  });

  group('Formatters', () {
    test('converts digits to Persian', () {
      expect(Formatters.digits('2008'), '۲۰۰۸');
      expect(Formatters.digits('S01E02'), 'S۰۱E۰۲');
    });

    test('thousands separator', () {
      expect(Formatters.count(2600000), '۲٬۶۰۰٬۰۰۰');
      expect(Formatters.count(950), '۹۵۰');
    });

    test('compact vote counts for the poster badge', () {
      expect(Formatters.compact(2600000), '۲.۶M');
      expect(Formatters.compact(15400), '۱۵.۴K');
      expect(Formatters.compact(420), '۴۲۰');
    });

    test('rating shows one decimal', () {
      expect(Formatters.rating(8.7), '۸.۷');
      expect(Formatters.rating(9), '۹.۰');
      expect(Formatters.rating(null), '—');
    });

    test('durations', () {
      expect(Formatters.duration(136), '۲ ساعت و ۱۶ دقیقه');
      expect(Formatters.duration(60), '۱ ساعت');
      expect(Formatters.duration(59), '۵۹ دقیقه');
      expect(Formatters.duration(0), isNull);
    });

    test('relative dates in Persian', () {
      final now = DateTime.now();
      expect(Formatters.relativeDate(now.subtract(const Duration(minutes: 2))), 'چند لحظه پیش');
      expect(Formatters.relativeDate(now.subtract(const Duration(hours: 3))), '۳ ساعت پیش');
      expect(Formatters.relativeDate(now.subtract(const Duration(days: 2))), '۲ روز پیش');
    });

    test('air dates render as Persian-digit ISO dates', () {
      expect(Formatters.airDate('2008-01-20'), '۲۰۰۸/۰۱/۲۰');
      expect(Formatters.airDate(null), isNull);
    });
  });
}
