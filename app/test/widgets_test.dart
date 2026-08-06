import 'package:filmbin/core/theme/app_theme.dart';
import 'package:filmbin/data/models/models.dart';
import 'package:filmbin/presentation/widgets/bidi_text.dart';
import 'package:filmbin/presentation/widgets/poster_card.dart';
import 'package:filmbin/presentation/widgets/progress_bar.dart';
import 'package:filmbin/presentation/widgets/rating_widgets.dart';
import 'package:filmbin/presentation/widgets/state_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

/// Widget-level checks for the pieces the specification names explicitly:
/// the progress bar colours (5.11), the star rating (5.13) and the spoiler
/// shield (5.15).

Widget wrap(Widget child, {ThemeData? theme}) => MaterialApp(
      theme: theme ?? AppTheme.dark(),
      locale: const Locale('fa'),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: child),
      ),
    );

WatchProgress progress({
  required int percent,
  required ProgressColor color,
  int total = 62,
  bool isOngoing = false,
}) {
  final watched = (total * percent / 100).round();
  return WatchProgress(
    totalEpisodes: total,
    watchedEpisodes: watched,
    remainingEpisodes: total - watched,
    percent: percent,
    color: color,
    isOngoing: isOngoing,
  );
}

void main() {
  group('WatchProgressBar (section 5.11)', () {
    testWidgets('fills exactly the watched fraction', (tester) async {
      await tester.pumpWidget(
        wrap(WatchProgressBar(progress: progress(percent: 50, color: ProgressColor.yellow))),
      );

      final box = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(box.widthFactor, closeTo(0.5, 0.001));
    });

    testWidgets('a started-but-zero-percent series still shows a sliver',
        (tester) async {
      await tester.pumpWidget(
        wrap(WatchProgressBar(progress: progress(percent: 0, color: ProgressColor.red))),
      );

      final box = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      // Nothing watched but the state is not «none» — the bar must be visible.
      expect(box.widthFactor, greaterThan(0));
    });

    testWidgets('nothing watched at all draws no fill', (tester) async {
      await tester.pumpWidget(
        wrap(WatchProgressBar(progress: progress(percent: 0, color: ProgressColor.none))),
      );

      final box = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(box.widthFactor, 0);
    });

    testWidgets('the label spells out the counts and the legend', (tester) async {
      await tester.pumpWidget(
        wrap(
          WatchProgressBar(
            progress: progress(percent: 50, color: ProgressColor.yellow),
            showLabel: true,
          ),
        ),
      );

      expect(find.text('۵۰٪'), findsOneWidget);
      expect(find.text('۳۱ از ۶۲ قسمت'), findsOneWidget);
      expect(find.text('قسمت دیده‌نشده دارید'), findsOneWidget);
      expect(find.text('۳۱ قسمت مانده'), findsOneWidget);
    });

    test('every colour has its own hue and its own sentence', () {
      final colors = ProgressColor.values
          .map((color) => AppTheme.progressColor(color, Brightness.dark))
          .toSet();
      final legends =
          ProgressColor.values.map(AppTheme.progressLegend).toSet();

      expect(colors.length, ProgressColor.values.length);
      expect(legends.length, ProgressColor.values.length);
    });

    testWidgets('the legend lists all five states', (tester) async {
      await tester.pumpWidget(wrap(const ProgressLegend()));
      for (final color in ProgressColor.values) {
        expect(find.text(AppTheme.progressLegend(color)), findsOneWidget);
      }
    });
  });

  group('StarRating (section 5.13)', () {
    testWidgets('draws five stars and fills up to the score', (tester) async {
      await tester.pumpWidget(wrap(const StarRating(value: 3)));

      expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
      expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(2));
    });

    testWidgets('an unrated title shows five empty stars', (tester) async {
      await tester.pumpWidget(wrap(const StarRating(value: null)));
      expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(5));
    });

    testWidgets('tapping the fourth star reports four', (tester) async {
      int? chosen;
      await tester.pumpWidget(
        wrap(StarRating(value: 2, onChanged: (value) => chosen = value)),
      );

      await tester.tap(find.byType(GestureDetector).at(3));
      expect(chosen, 4);
    });

    testWidgets('without a callback the stars are read-only', (tester) async {
      await tester.pumpWidget(wrap(const StarRating(value: 2)));
      await tester.tap(find.byType(GestureDetector).at(4));
      await tester.pump();
      // Nothing to assert beyond "it did not throw" — a read-only rating must
      // not try to write.
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(2));
    });
  });

  group('RatingDistributionChart (section 5.13)', () {
    testWidgets('shows the average, the vote count and one bar per score',
        (tester) async {
      final detail = TitleDetail.fromJson(Map<String, dynamic>.from(kSeriesDetailJson));

      await tester.pumpWidget(
        wrap(
          RatingDistributionChart(
            buckets: detail.ratingDistribution,
            average: 4.25,
            count: 4,
          ),
        ),
      );

      expect(find.text('۴.۳'), findsOneWidget); // one decimal, Persian digits
      expect(find.text('۴ رأی'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNWidgets(5));
      expect(find.text('۵۰٪'), findsOneWidget);
    });

    testWidgets('with no votes it says so instead of drawing an empty chart',
        (tester) async {
      await tester.pumpWidget(
        wrap(const RatingDistributionChart(buckets: [], average: null, count: 0)),
      );

      expect(find.text('هنوز کسی به این اثر امتیاز نداده است.'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });

  group('ReviewTile (sections 5.14 and 5.15)', () {
    Review review({bool spoiler = true}) => Review.fromJson({
          ...kReviewJson,
          'has_spoiler': spoiler,
        });

    testWidgets('a spoiler review hides its text behind a shield', (tester) async {
      await tester.pumpWidget(wrap(ReviewTile(review: review())));

      expect(find.text('این نظر داستان را لو می‌دهد'), findsOneWidget);
      expect(find.text(kReviewJson['text']! as String), findsNothing);
    });

    testWidgets('tapping the shield reveals the text', (tester) async {
      await tester.pumpWidget(wrap(ReviewTile(review: review())));

      await tester.tap(find.text('برای دیدن، لمس کنید'));
      await tester.pump();

      expect(find.text(kReviewJson['text']! as String), findsOneWidget);
      expect(find.text('دارای اسپویل'), findsOneWidget);
    });

    testWidgets('the reader can turn the shield off in settings', (tester) async {
      await tester.pumpWidget(
        wrap(ReviewTile(review: review(), hideSpoilerByDefault: false)),
      );

      expect(find.text(kReviewJson['text']! as String), findsOneWidget);
    });

    testWidgets('a review with no spoiler is shown straight away', (tester) async {
      await tester.pumpWidget(wrap(ReviewTile(review: review(spoiler: false))));

      expect(find.text(kReviewJson['text']! as String), findsOneWidget);
      expect(find.text('دارای اسپویل'), findsNothing);
    });

    testWidgets('my own review offers delete, not report', (tester) async {
      await tester.pumpWidget(
        wrap(
          ReviewTile(
            review: review(spoiler: false),
            isMine: true,
            onDelete: () {},
            onReport: () {},
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();

      expect(find.text('حذف نظر من'), findsOneWidget);
      expect(find.text('گزارش نظر'), findsNothing);
    });
  });

  group('PosterCard', () {
    TitleSummary movie() => TitleSummary.fromJson(Map<String, dynamic>.from(kMovieJson));

    testWidgets('shows the name, the year, the rating and the status band',
        (tester) async {
      await tester.pumpWidget(wrap(Center(child: PosterCard(title: movie()))));

      expect(find.text('The Matrix'), findsOneWidget);
      expect(find.text('۱۹۹۹ · فیلم'), findsOneWidget);
      expect(find.text('۸.۷'), findsOneWidget);
      expect(find.text('در حال تماشا'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    });

    testWidgets('a series that has ended shows both years', (tester) async {
      final series =
          TitleSummary.fromJson(Map<String, dynamic>.from(kSeriesDetailJson));
      await tester.pumpWidget(wrap(Center(child: PosterCard(title: series))));

      expect(find.text('۲۰۰۸–۲۰۱۳ · سریال'), findsOneWidget);
    });

    testWidgets('TitleRow lists the genres and the runtime', (tester) async {
      await tester.pumpWidget(wrap(TitleRow(title: movie())));

      expect(find.text('فیلم · ۱۹۹۹ · ۲ ساعت و ۱۶ دقیقه'), findsOneWidget);
      expect(find.text('Action، Sci-Fi'), findsOneWidget);
    });
  });

  group('State views (section 5.20)', () {
    testWidgets('an empty view can carry a call to action', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        wrap(
          EmptyView(
            message: 'چیزی نیست',
            hint: 'بعداً سر بزن',
            action: FilledButton(
              onPressed: () => tapped = true,
              child: const Text('برو'),
            ),
          ),
        ),
      );

      expect(find.text('چیزی نیست'), findsOneWidget);
      expect(find.text('بعداً سر بزن'), findsOneWidget);
      await tester.tap(find.text('برو'));
      expect(tapped, isTrue);
    });

    testWidgets('the offline banner explains where the data came from',
        (tester) async {
      await tester.pumpWidget(wrap(const OfflineBanner()));
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    });
  });

  group('BidiText (section 8.2)', () {
    test('an English sentence is laid out left to right', () {
      expect(
        BidiText.directionOf("A chemistry teacher turns to crime."),
        TextDirection.ltr,
      );
    });

    test('a Persian sentence stays right to left', () {
      expect(BidiText.directionOf('پایان‌بندی‌اش غافلگیرکننده بود.'), TextDirection.rtl);
    });

    test('a mixed line follows the first letter, not the majority', () {
      expect(BidiText.directionOf('فصل ۱ — Pilot'), TextDirection.rtl);
      expect(BidiText.directionOf('Breaking Bad — فصل ۱'), TextDirection.ltr);
    });

    test('digits and punctuation alone do not decide the direction', () {
      expect(BidiText.directionOf('2008 — 2013'), TextDirection.rtl);
    });

    testWidgets('renders the English plot with an ltr direction', (tester) async {
      await tester.pumpWidget(wrap(const BidiText('The Odyssey is a long trip.')));
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.textDirection, TextDirection.ltr);
      expect(text.textAlign, TextAlign.left);
    });
  });
}