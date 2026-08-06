import 'package:filmbin/core/network/api_exception.dart';
import 'package:filmbin/core/storage/preferences.dart';
import 'package:filmbin/core/theme/app_theme.dart';
import 'package:filmbin/data/models/models.dart';
import 'package:filmbin/data/repositories/auth_repository.dart';
import 'package:filmbin/data/repositories/lists_repository.dart';
import 'package:filmbin/data/repositories/reviews_repository.dart';
import 'package:filmbin/data/repositories/titles_repository.dart';
import 'package:filmbin/data/repositories/tracking_repository.dart';
import 'package:filmbin/data/repositories/user_repository.dart';
import 'package:filmbin/presentation/providers/auth_provider.dart';
import 'package:filmbin/presentation/providers/core_providers.dart';
import 'package:filmbin/presentation/screens/admin/admin_screen.dart';
import 'package:filmbin/presentation/screens/feed_screen.dart';
import 'package:filmbin/presentation/screens/home_screen.dart';
import 'package:filmbin/presentation/screens/profile/profile_screen.dart';
import 'package:filmbin/presentation/screens/profile/stats_screen.dart';
import 'package:filmbin/presentation/screens/search_screen.dart';
import 'package:filmbin/presentation/screens/title/title_detail_screen.dart';
import 'package:filmbin/presentation/screens/watchlist_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures.dart';

/// Screen-level checks: every page is driven by overridden repositories, so the
/// tests describe what the user sees, not how the data was fetched.

class MockTitles extends Mock implements TitlesRepository {}

class MockTracking extends Mock implements TrackingRepository {}

class MockReviews extends Mock implements ReviewsRepository {}

class MockLists extends Mock implements ListsRepository {}

class MockUsers extends Mock implements UserRepository {}

class MockAuth extends Mock implements AuthRepository {}

/// Lets a test start on a known auth state without touching the network.
class TestAuthController extends AuthController {
  TestAuthController(super.ref, AppUser? user) {
    state = user == null
        ? const AuthState(status: AuthStatus.guest)
        : AuthState(status: AuthStatus.authenticated, user: user);
  }

  @override
  Future<void> restore() async {}
}

final kUser = AppUser.fromJson(Map<String, dynamic>.from(kUserJson));
final kAdmin = AppUser.fromJson({...kUserJson, 'role': 'admin'});
final kMovie = TitleSummary.fromJson(Map<String, dynamic>.from(kMovieJson));
final kSeries = TitleDetail.fromJson(Map<String, dynamic>.from(kSeriesDetailJson));

late Preferences preferences;

/// A tall, narrow viewport so a whole screen is laid out at once — the default
/// 800×600 test window cuts lazy lists off and hides widgets that really are
/// built on a phone.
Future<Widget> harness(
  WidgetTester tester,
  Widget screen, {
  AppUser? user,
  MockTitles? titles,
  MockTracking? tracking,
  MockReviews? reviews,
  MockLists? lists,
  MockUsers? users,
}) async {
  tester.view.physicalSize = const Size(1080, 3600);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  return ProviderScope(
    overrides: [
      preferencesProvider.overrideWithValue(preferences),
      authControllerProvider.overrideWith((ref) => TestAuthController(ref, user)),
      if (titles != null) titlesRepositoryProvider.overrideWithValue(titles),
      if (tracking != null) trackingRepositoryProvider.overrideWithValue(tracking),
      if (reviews != null) reviewsRepositoryProvider.overrideWithValue(reviews),
      if (lists != null) listsRepositoryProvider.overrideWithValue(lists),
      if (users != null) userRepositoryProvider.overrideWithValue(users),
    ],
    child: MaterialApp(
      theme: AppTheme.dark(),
      locale: const Locale('fa'),
      home: Directionality(textDirection: TextDirection.rtl, child: screen),
    ),
  );
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await Preferences.load();
  });

  group('HomeScreen (section 5.18)', () {
    testWidgets('draws one rail per section the backend sent', (tester) async {
      final titles = MockTitles();
      when(() => titles.discover()).thenAnswer(
        (_) async => [
          DiscoverSection(key: 'popular_movies', title: 'فیلم‌های محبوب', items: [kMovie]),
          DiscoverSection(
            key: 'top_rated',
            title: 'برترین‌ها',
            items: [kSeries.summary],
          ),
        ],
      );

      await tester.pumpWidget(await harness(tester, const HomeScreen(), titles: titles));
      await tester.pump();

      expect(find.text('فیلم‌های محبوب'), findsOneWidget);
      expect(find.text('برترین‌ها'), findsOneWidget);
      expect(find.text('The Matrix'), findsOneWidget);
      expect(find.text('Breaking Bad'), findsOneWidget);
    });

    testWidgets('a guest is invited to sign in, not blocked', (tester) async {
      final titles = MockTitles();
      when(() => titles.discover()).thenAnswer((_) async => []);

      await tester.pumpWidget(await harness(tester, const HomeScreen(), titles: titles));
      await tester.pump();

      expect(find.text('خوش آمدید'), findsOneWidget);
      expect(find.text('ورود'), findsOneWidget);
    });

    testWidgets('a signed-in user gets recommendations and a resume rail',
        (tester) async {
      final titles = MockTitles();
      final tracking = MockTracking();
      when(() => titles.discover()).thenAnswer((_) async => []);
      when(() => titles.recommended()).thenAnswer(
        (_) async => SearchPage(
          items: [kMovie],
          total: 1,
          personalized: true,
          basedOn: const ['Drama'],
        ),
      );
      when(() => tracking.watchlist(status: WatchStatus.watching)).thenAnswer(
        (_) async => WatchlistResult(items: [kSeries.summary], counts: const {}, total: 1),
      );

      await tester.pumpWidget(await harness(tester, 
        const HomeScreen(),
        user: kUser,
        titles: titles,
        tracking: tracking,
      ));
      await tester.pump();

      expect(find.textContaining('سلام'), findsOneWidget);
      expect(find.text('پیشنهاد برای شما'), findsOneWidget);
      expect(find.text('بر پایهٔ علاقهٔ تو به Drama'), findsOneWidget);
      expect(find.text('ادامهٔ تماشا'), findsOneWidget);
    });

    testWidgets('a brand-new account gets no recommendation shelf', (tester) async {
      final titles = MockTitles();
      final tracking = MockTracking();
      when(() => titles.discover()).thenAnswer(
        (_) async => [
          DiscoverSection(key: 'popular_movies', title: 'فیلم‌های محبوب', items: [kMovie]),
        ],
      );
      // Cold start: the backend answers with the popular rail and says so.
      when(() => titles.recommended()).thenAnswer(
        (_) async => SearchPage(items: [kMovie], total: 1),
      );
      when(() => tracking.watchlist(status: WatchStatus.watching)).thenAnswer(
        (_) async => const WatchlistResult(items: [], counts: {}, total: 0),
      );

      await tester.pumpWidget(await harness(tester, 
        const HomeScreen(),
        user: kUser,
        titles: titles,
        tracking: tracking,
      ));
      await tester.pump();

      expect(find.text('پیشنهاد برای شما'), findsNothing);
      expect(find.text('فیلم‌های محبوب'), findsOneWidget);
    });

    testWidgets('falls back to the local mirror when the network is down',
        (tester) async {
      final titles = MockTitles();
      when(() => titles.discover()).thenThrow(
        const ApiException(message: 'اتصال برقرار نشد.', code: 'NO_CONNECTION'),
      );
      when(() => titles.cachedSections()).thenAnswer(
        (_) async => [
          DiscoverSection(key: 'popular_movies', title: 'آخرین‌بار دیدی', items: [kMovie]),
        ],
      );

      await tester.pumpWidget(await harness(tester, const HomeScreen(), titles: titles));
      await tester.pump();

      expect(find.text('آخرین‌بار دیدی'), findsOneWidget);
      verify(() => titles.cachedSections()).called(1);
    });

    testWidgets('with no cache either, it explains the failure and offers retry',
        (tester) async {
      final titles = MockTitles();
      when(() => titles.discover()).thenThrow(
        const ApiException(message: 'اتصال برقرار نشد.', code: 'NO_CONNECTION'),
      );
      when(() => titles.cachedSections()).thenAnswer((_) async => []);

      await tester.pumpWidget(await harness(tester, const HomeScreen(), titles: titles));
      await tester.pump();

      expect(find.text('اتصال برقرار نشد.'), findsOneWidget);
      expect(find.text('تلاش دوباره'), findsOneWidget);
    });
  });

  group('SearchScreen (sections 5.5 and 5.6)', () {
    testWidgets('starts with a prompt rather than an empty list', (tester) async {
      await tester.pumpWidget(await harness(tester, const SearchScreen()));
      await tester.pump();

      expect(find.text('دنبال چه می‌گردی؟'), findsOneWidget);
    });

    testWidgets('typing runs one debounced search and lists the hits',
        (tester) async {
      final titles = MockTitles();
      when(() => titles.search(
            query: any(named: 'query'),
            person: any(named: 'person'),
            kind: any(named: 'kind'),
            genres: any(named: 'genres'),
            yearFrom: any(named: 'yearFrom'),
            yearTo: any(named: 'yearTo'),
            sort: any(named: 'sort'),
            cursor: any(named: 'cursor'),
          )).thenAnswer((_) async => SearchPage(items: [kMovie], total: 1));

      await tester.pumpWidget(await harness(tester, const SearchScreen(), titles: titles));
      await tester.enterText(find.byType(TextField).first, 'matrix');
      await tester.enterText(find.byType(TextField).first, 'matrix r');
      // Both keystrokes fall inside one debounce window.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.text('The Matrix'), findsOneWidget);
      expect(find.text('۱ نتیجه'), findsOneWidget);
      verify(() => titles.search(
            query: any(named: 'query'),
            person: any(named: 'person'),
            kind: any(named: 'kind'),
            genres: any(named: 'genres'),
            yearFrom: any(named: 'yearFrom'),
            yearTo: any(named: 'yearTo'),
            sort: any(named: 'sort'),
            cursor: any(named: 'cursor'),
          )).called(1);
    });

    testWidgets('no hits reads as an answer, not as an error', (tester) async {
      final titles = MockTitles();
      when(() => titles.search(
            query: any(named: 'query'),
            person: any(named: 'person'),
            kind: any(named: 'kind'),
            genres: any(named: 'genres'),
            yearFrom: any(named: 'yearFrom'),
            yearTo: any(named: 'yearTo'),
            sort: any(named: 'sort'),
            cursor: any(named: 'cursor'),
          )).thenAnswer((_) async => const SearchPage(items: [], total: 0));

      await tester.pumpWidget(await harness(tester, const SearchScreen(), titles: titles));
      await tester.enterText(find.byType(TextField).first, 'zzzzzz');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.text('چیزی پیدا نشد.'), findsOneWidget);
    });

    testWidgets('the filter sheet offers kinds, genres and sorting',
        (tester) async {
      await tester.pumpWidget(await harness(tester, const SearchScreen()));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();

      expect(find.text('پالایش نتیجه‌ها'), findsOneWidget);
      expect(find.text('سریال'), findsOneWidget);
      expect(find.text('علمی-تخیلی'), findsOneWidget);
      expect(find.text('اعمال پالایه‌ها'), findsOneWidget);

      await tester.dragUntilVisible(
        find.text('بیشترین امتیاز'),
        find.byType(ListView),
        const Offset(0, -220),
      );
      expect(find.text('بیشترین امتیاز'), findsOneWidget);
    });
  });

  group('TitleDetailScreen (sections 5.7–5.14)', () {
    Future<void> pumpDetail(WidgetTester tester, {AppUser? user}) async {
      final titles = MockTitles();
      final reviews = MockReviews();
      when(() => titles.detail(kSeries.imdbId)).thenAnswer((_) async => kSeries);
      when(() => reviews.reviews(kSeries.imdbId)).thenAnswer(
        (_) async => ReviewPage(
          items: [Review.fromJson({...kReviewJson, 'title_id': kSeries.imdbId})],
          total: 1,
        ),
      );

      await tester.pumpWidget(await harness(tester, 
        TitleDetailScreen(imdbId: kSeries.imdbId),
        user: user,
        titles: titles,
        reviews: reviews,
      ));
      await tester.pump();
    }

    testWidgets('shows the facts the specification asks for', (tester) async {
      await pumpDetail(tester);

      // The collapsed app bar repeats the name, so one or more is correct.
      expect(find.text('Breaking Bad'), findsWidgets);
      expect(find.text('سریال · ۲۰۰۸–۲۰۱۳ · ۴۸ دقیقه · پایان‌یافته'), findsOneWidget);
      expect(find.text('A chemistry teacher turns to crime.'), findsOneWidget);
      expect(find.text('Vince Gilligan'), findsNWidgets(2)); // director + creator
      expect(find.text('United States'), findsOneWidget);
      expect(find.text('Bryan Cranston'), findsOneWidget);
      expect(find.text('Walter White'), findsOneWidget);
      expect(find.text('۹.۵'), findsOneWidget);
    });

    testWidgets('lists the seasons with their episode counts', (tester) async {
      await pumpDetail(tester);
      await tester.dragUntilVisible(
        find.text('فصل ۱'),
        find.byType(CustomScrollView),
        const Offset(0, -260),
      );

      expect(find.text('فصل ۱'), findsOneWidget);
      expect(find.text('فصل ۲'), findsOneWidget);
      expect(find.text('۷ قسمت'), findsOneWidget);
      expect(find.text('۱۳ قسمت'), findsOneWidget);
    });

    testWidgets('the progress card reports the server-side colour and share',
        (tester) async {
      await pumpDetail(tester, user: kUser);

      expect(find.text('۵۰٪'), findsOneWidget);
      expect(find.text('۳۱ از ۶۲ قسمت'), findsOneWidget);
      expect(find.text('قسمت دیده‌نشده دارید'), findsOneWidget);
    });

    testWidgets('an untracked title invites the user to add it', (tester) async {
      await pumpDetail(tester, user: kUser);
      expect(find.text('افزودن به فهرست من'), findsOneWidget);
    });

    testWidgets('the spoiler review stays folded until asked for', (tester) async {
      await pumpDetail(tester);
      await tester.dragUntilVisible(
        find.text('نظرها'),
        find.byType(CustomScrollView),
        const Offset(0, -260),
      );

      expect(find.text('این نظر داستان را لو می‌دهد'), findsOneWidget);
      expect(find.text(kReviewJson['text']! as String), findsNothing);
    });

    testWidgets('a failed load shows the message and a retry', (tester) async {
      final titles = MockTitles();
      when(() => titles.detail(any())).thenThrow(
        const ApiException(
          message: 'فیلم یا سریال موردنظر پیدا نشد.',
          code: 'TITLE_NOT_FOUND',
          statusCode: 404,
        ),
      );

      await tester.pumpWidget(await harness(tester, 
        const TitleDetailScreen(imdbId: 'tt0000000'),
        titles: titles,
      ));
      await tester.pump();

      expect(find.text('فیلم یا سریال موردنظر پیدا نشد.'), findsOneWidget);
      expect(find.text('تلاش دوباره'), findsOneWidget);
    });
  });

  group('WatchlistScreen (section 5.12)', () {
    testWidgets('a guest is asked to sign in', (tester) async {
      await tester.pumpWidget(await harness(tester, const WatchlistScreen()));
      await tester.pump();

      expect(find.text('برای داشتن فهرست شخصی وارد شو.'), findsOneWidget);
    });

    testWidgets('tabs carry the per-status counts', (tester) async {
      final tracking = MockTracking();
      when(() => tracking.watchlist(status: any(named: 'status'))).thenAnswer(
        (invocation) async {
          final status = invocation.namedArguments[#status] as WatchStatus?;
          return WatchlistResult(
            items: status == null || status == WatchStatus.watching ? [kMovie] : const [],
            counts: const {WatchStatus.watching: 1, WatchStatus.watched: 4},
            total: 5,
          );
        },
      );
      when(() => tracking.favorites()).thenAnswer(
        (_) async => WatchlistResult(items: [kMovie], counts: const {}, total: 1),
      );

      await tester.pumpWidget(
        await harness(tester, const WatchlistScreen(), user: kUser, tracking: tracking),
      );
      await tester.pump();

      expect(find.text('همه (۵)'), findsOneWidget);
      expect(find.text('در حال تماشا (۱)'), findsOneWidget);
      expect(find.text('مشاهده شده (۴)'), findsOneWidget);
      expect(find.text('موردعلاقه'), findsOneWidget);
      expect(find.text('The Matrix'), findsOneWidget);
    });
  });

  group('ProfileScreen (section 5.4)', () {
    testWidgets('shows the three counters the profile promises', (tester) async {
      await tester.pumpWidget(await harness(tester, const ProfileScreen(), user: kUser));
      await tester.pump();

      expect(find.text('آرین اکبری'), findsOneWidget);
      expect(find.text('@arian'), findsOneWidget);
      expect(find.text('۳'), findsOneWidget); // watched movies
      expect(find.text('۲'), findsOneWidget); // followed series
      expect(find.text('۵'), findsOneWidget); // favourites
      expect(find.text('پنل مدیریت'), findsNothing);
    });

    testWidgets('an admin gets the extra door', (tester) async {
      await tester.pumpWidget(await harness(tester, const ProfileScreen(), user: kAdmin));
      await tester.pump();

      expect(find.text('پنل مدیریت'), findsOneWidget);
      expect(find.text('مدیر سامانه'), findsOneWidget);
    });

    testWidgets('a guest sees the invitation instead of an empty profile',
        (tester) async {
      await tester.pumpWidget(await harness(tester, const ProfileScreen()));
      await tester.pump();

      expect(find.text('به‌عنوان مهمان می‌گردی.'), findsOneWidget);
    });
  });

  group('StatsScreen (section 5.19)', () {
    testWidgets('renders the dashboard numbers and both charts', (tester) async {
      final users = MockUsers();
      when(() => users.stats(forceRefresh: any(named: 'forceRefresh'))).thenAnswer(
        (_) async => UserStats.fromJson(Map<String, dynamic>.from(kStatsJson)),
      );

      await tester.pumpWidget(
        await harness(tester, const StatsScreen(), user: kUser, users: users),
      );
      await tester.pump();

      expect(find.text('۱۵۰ ساعت'), findsOneWidget);
      expect(find.textContaining('۹٬۰۰۰ دقیقه'), findsOneWidget);
      expect(find.text('وضعیت آثار من'), findsOneWidget);
      expect(find.text('ژانرهای محبوب من'), findsOneWidget);
      expect(find.text('Drama'), findsOneWidget);
    });
  });

  group('FeedScreen and AdminScreen', () {
    testWidgets('an empty feed explains how to fill it', (tester) async {
      final users = MockUsers();
      when(() => users.feed()).thenAnswer((_) async => []);

      await tester.pumpWidget(
        await harness(tester, const FeedScreen(), user: kUser, users: users),
      );
      await tester.pump();

      expect(find.text('هنوز فعالیتی نیست.'), findsOneWidget);
    });

    testWidgets('the admin console is closed to a normal user', (tester) async {
      await tester.pumpWidget(await harness(tester, const AdminScreen(), user: kUser));
      await tester.pump();

      expect(find.text('این بخش فقط برای مدیران است.'), findsOneWidget);
    });
  });

  group('Offline start-up (section 8.4)', () {
    test('a confirmed profile survives a round trip through preferences',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await Preferences.load();

      expect(prefs.cachedProfile, isNull);
      await prefs.cacheProfile(kUser);

      final restored = (await Preferences.load()).cachedProfile;
      expect(restored, isNotNull);
      expect(restored!.username, kUser.username);
      expect(restored.fullName, kUser.fullName);
      expect(restored.summary.watchedMovies, kUser.summary.watchedMovies);

      await prefs.cacheProfile(null);
      expect((await Preferences.load()).cachedProfile, isNull);
    });

    test('a start-up with no connection keeps the user signed in', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await Preferences.load();
      await prefs.cacheProfile(kUser);

      final auth = MockAuth();
      when(auth.restoreSession).thenThrow(
        const ApiException(message: 'اتصال اینترنت برقرار نیست.', code: 'NO_CONNECTION'),
      );

      final container = ProviderContainer(
        overrides: [
          preferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(auth),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.notifier).restore();

      final state = container.read(authControllerProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.user?.username, kUser.username);
    });

    test('with nothing cached, an offline start-up falls back to guest',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await Preferences.load();

      final auth = MockAuth();
      when(auth.restoreSession).thenThrow(
        const ApiException(message: 'اتصال اینترنت برقرار نیست.', code: 'NO_CONNECTION'),
      );

      final container = ProviderContainer(
        overrides: [
          preferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(auth),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.notifier).restore();
      expect(container.read(authControllerProvider).status, AuthStatus.guest);
    });
  });
}