import 'package:dio/dio.dart';
import 'package:filmbin/core/network/api_client.dart';
import 'package:filmbin/core/storage/token_store.dart';
import 'package:filmbin/data/models/models.dart';
import 'package:filmbin/data/repositories/auth_repository.dart';
import 'package:filmbin/data/repositories/lists_repository.dart';
import 'package:filmbin/data/repositories/titles_repository.dart';
import 'package:filmbin/data/repositories/tracking_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'fixtures.dart';

class MockDio extends Mock implements Dio {}

class FakeTokenStore implements TokenStore {
  String? access;
  String? refresh;

  @override
  Future<void> clear() async {
    access = null;
    refresh = null;
  }

  @override
  Future<String?> readAccessToken() async => access;

  @override
  Future<String?> readRefreshToken() async => refresh;

  @override
  Future<void> save({required String accessToken, required String refreshToken}) async {
    access = accessToken;
    refresh = refreshToken;
  }
}

Response<dynamic> _ok(dynamic data, {int status = 200}) => Response(
      requestOptions: RequestOptions(path: '/'),
      statusCode: status,
      data: data,
    );

void main() {
  late MockDio dio;
  late ApiClient api;
  late FakeTokenStore store;

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: '/'));
    registerFallbackValue(Options());
  });

  setUp(() {
    dio = MockDio();
    api = ApiClient.withDio(dio);
    store = FakeTokenStore();
  });

  group('AuthRepository', () {
    test('login stores both tokens and returns the profile', () async {
      when(() => dio.post<dynamic>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => _ok(kTokensJson));

      final repo = AuthRepository(api, store);
      final tokens = await repo.login(email: 'arian@example.com', password: 'Str0ngPass!');

      expect(tokens.user.username, 'arian');
      expect(store.access, 'access-token');
      expect(store.refresh, 'refresh-token');

      final captured = verify(() => dio.post<dynamic>('/auth/login', data: captureAny(named: 'data')))
          .captured
          .single as Map<String, dynamic>;
      expect(captured['email'], 'arian@example.com');
      expect(captured['remember_me'], isTrue);
    });

    test('a one-day session is requested when remember-me is off', () async {
      when(() => dio.post<dynamic>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => _ok(kTokensJson));

      await AuthRepository(api, store)
          .login(email: 'a@b.com', password: 'Str0ngPass!', rememberMe: false);

      final captured = verify(() => dio.post<dynamic>('/auth/login', data: captureAny(named: 'data')))
          .captured
          .single as Map<String, dynamic>;
      expect(captured['remember_me'], isFalse);
    });

    test('register sends the whole form', () async {
      when(() => dio.post<dynamic>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => _ok(kTokensJson, status: 201));

      await AuthRepository(api, store).register(
        fullName: 'آرین اکبری',
        username: 'arian',
        email: 'arian@example.com',
        password: 'Str0ngPass!',
        bio: 'دانشجو',
      );

      final captured = verify(() => dio.post<dynamic>('/auth/register', data: captureAny(named: 'data')))
          .captured
          .single as Map<String, dynamic>;
      expect(captured['username'], 'arian');
      expect(captured['bio'], 'دانشجو');
    });

    test('logout clears local tokens even if the call fails', () async {
      await store.save(accessToken: 'a', refreshToken: 'r');
      when(() => dio.post<dynamic>(any(), data: any(named: 'data')))
          .thenThrow(DioException(requestOptions: RequestOptions(path: '/auth/logout')));

      await AuthRepository(api, store).logout();

      expect(store.access, isNull);
      expect(store.refresh, isNull);
    });

    test('restoreSession returns null when nothing is stored', () async {
      final user = await AuthRepository(api, store).restoreSession();
      expect(user, isNull);
      verifyNever(() => dio.get<dynamic>(any()));
    });

    test('restoreSession fetches the profile when a token exists', () async {
      await store.save(accessToken: 'a', refreshToken: 'r');
      when(() => dio.get<dynamic>(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _ok(kUserJson));

      final user = await AuthRepository(api, store).restoreSession();
      expect(user!.username, 'arian');
    });
  });

  group('TitlesRepository', () {
    test('search passes every filter through to the backend', () async {
      when(() => dio.get<dynamic>(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _ok({
                'items': [kMovieJson],
                'total': 1,
                'next_cursor': 'cursor-2',
                'stale': false,
              }));

      final page = await TitlesRepository(api).search(
        query: 'matrix',
        kind: 'movie',
        genres: ['Action'],
        yearFrom: 1990,
        yearTo: 2000,
        person: 'keanu',
      );

      expect(page.items.single.title, 'The Matrix');
      expect(page.nextCursor, 'cursor-2');
      expect(page.stale, isFalse);

      final query = verify(() => dio.get<dynamic>('/titles/search',
              queryParameters: captureAny(named: 'queryParameters')))
          .captured
          .single as Map<String, dynamic>;
      expect(query['q'], 'matrix');
      expect(query['kind'], 'movie');
      expect(query['genre'], ['Action']);
      expect(query['year_from'], 1990);
      expect(query['person'], 'keanu');
    });

    test('detail parses the full payload', () async {
      when(() => dio.get<dynamic>(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _ok(kSeriesDetailJson));

      final detail = await TitlesRepository(api).detail('tt0903747');
      expect(detail.summary.title, 'Breaking Bad');
      expect(detail.seasons.length, 2);
    });

    test('episodes parse into rows with a watched flag', () async {
      when(() => dio.get<dynamic>(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _ok([kEpisodeJson]));

      final episodes = await TitlesRepository(api).episodes('tt0903747', 1);
      expect(episodes.single.isWatched, isTrue);
    });

    test('discover returns the named rails', () async {
      when(() => dio.get<dynamic>(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _ok({
                'sections': [
                  {
                    'key': 'popular_movies',
                    'title': 'فیلم‌های محبوب',
                    'items': [kMovieJson],
                  }
                ]
              }));

      final sections = await TitlesRepository(api).discover();
      expect(sections.single.key, 'popular_movies');
      expect(sections.single.title, 'فیلم‌های محبوب');
      expect(sections.single.items.single.imdbId, 'tt0133093');
    });
  });

  group('TrackingRepository', () {
    test('setStatus posts the API value of the enum', () async {
      when(() => dio.put<dynamic>(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => _ok({'imdb_id': 'tt1', 'status': 'watching', 'is_favorite': false}),
      );

      await TrackingRepository(api).setStatus('tt1', WatchStatus.watching);

      final captured = verify(() => dio.put<dynamic>('/titles/tt1/status', data: captureAny(named: 'data')))
          .captured
          .single as Map<String, dynamic>;
      expect(captured['status'], 'watching');
    });

    test('markEpisode returns the refreshed progress', () async {
      when(() => dio.put<dynamic>(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => _ok({
          'total_episodes': 10,
          'watched_episodes': 5,
          'remaining_episodes': 5,
          'percent': 50,
          'color': 'yellow',
          'is_ongoing': false,
        }),
      );

      final progress = await TrackingRepository(api).markEpisode('tt1', 'tt2');
      expect(progress.percent, 50);
      expect(progress.color, ProgressColor.yellow);
    });

    test('watchlist parses items and their counts', () async {
      when(() => dio.get<dynamic>(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _ok({
                'items': [kMovieJson],
                'counts': {'watching': 1},
                'total': 1,
              }));

      final result = await TrackingRepository(api).watchlist(status: WatchStatus.watching);
      expect(result.items.single.imdbId, 'tt0133093');
      expect(result.counts[WatchStatus.watching], 1);
    });
  });

  group('ListsRepository', () {
    test('creates a list', () async {
      when(() => dio.post<dynamic>(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => _ok({
          'id': 3,
          'name': 'بهترین‌های اکشن',
          'description': null,
          'is_public': true,
          'item_count': 0,
          'owner_username': 'arian',
          'created_at': '2026-07-01T10:00:00Z',
          'updated_at': '2026-07-01T10:00:00Z',
        }, status: 201),
      );

      final created = await ListsRepository(api).create(name: 'بهترین‌های اکشن');
      expect(created.id, 3);
      expect(created.itemCount, 0);
    });

    test('adds a title to a list', () async {
      when(() => dio.post<dynamic>(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => _ok({
          'id': 3,
          'name': 'x',
          'description': null,
          'is_public': true,
          'item_count': 1,
          'owner_username': 'arian',
          'created_at': '2026-07-01T10:00:00Z',
          'updated_at': '2026-07-01T10:00:00Z',
          'items': [kMovieJson],
        }, status: 201),
      );

      final detail = await ListsRepository(api).addItem(3, 'tt0133093');
      expect(detail.items.single.title, 'The Matrix');
    });
  });
}
