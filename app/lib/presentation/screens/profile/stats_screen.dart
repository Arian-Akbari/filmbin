import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/catalog_providers.dart';
import '../../widgets/state_views.dart';

/// Section 5.19 — the activity dashboard: how much was watched, of what, and
/// where the user's taste actually sits.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    if (!auth.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('آمار فعالیت')),
        body: const EmptyView(
          icon: Icons.insights_outlined,
          message: 'برای دیدن آمار باید وارد شده باشی.',
        ),
      );
    }

    final stats = ref.watch(userStatsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('آمار فعالیت من')),
      body: stats.when(
        loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
        error: (error, _) =>
            ErrorView(error: error, onRetry: () => ref.invalidate(userStatsProvider)),
        data: (data) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(userStatsProvider);
            await ref.read(userStatsProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
            children: [
              _HeadlineCard(stats: data),
              const SizedBox(height: 16),
              _CountersGrid(stats: data),
              const SizedBox(height: 22),
              if (data.statusBreakdown.isNotEmpty) ...[
                Text('وضعیت آثار من', style: context.text.titleLarge),
                const SizedBox(height: 12),
                _StatusPie(breakdown: data.statusBreakdown),
                const SizedBox(height: 22),
              ],
              if (data.favoriteGenres.isNotEmpty) ...[
                Text('ژانرهای محبوب من', style: context.text.titleLarge),
                const SizedBox(height: 12),
                _GenreBars(genres: data.favoriteGenres),
              ],
              if (data.statusBreakdown.isEmpty && data.favoriteGenres.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: EmptyView(
                    icon: Icons.bar_chart_rounded,
                    message: 'هنوز داده‌ای برای نمودار نداریم.',
                    hint: 'چند اثر را دنبال کن و امتیاز بده تا اینجا پر شود.',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeadlineCard extends StatelessWidget {
  const _HeadlineCard({required this.stats});

  final UserStats stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.outline),
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [context.scheme.primary.withValues(alpha: 0.20), context.colors.elevated],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('زمان کل تماشا', style: context.text.labelMedium),
          const SizedBox(height: 6),
          Text(stats.watchTimeLabel, style: context.text.displaySmall),
          const SizedBox(height: 6),
          Text(
            'برابر با ${Formatters.count(stats.totalWatchMinutes)} دقیقه'
            '${stats.topGenre == null ? '' : ' — بیشتر از همه ${stats.topGenre}'}',
            style: context.text.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _CountersGrid extends StatelessWidget {
  const _CountersGrid({required this.stats});

  final UserStats stats;

  @override
  Widget build(BuildContext context) {
    final tiles = <(IconData, String, String)>[
      (Icons.movie_outlined, 'فیلم دیده‌شده', Formatters.count(stats.watchedMovies)),
      (Icons.live_tv_rounded, 'سریال کامل‌شده', Formatters.count(stats.watchedSeries)),
      (
        Icons.playlist_add_check_rounded,
        'قسمت دیده‌شده',
        Formatters.count(stats.watchedEpisodes),
      ),
      (Icons.star_rounded, 'امتیاز ثبت‌شده', Formatters.count(stats.ratingsCount)),
      (Icons.rate_review_outlined, 'نظر نوشته‌شده', Formatters.count(stats.reviewsCount)),
      (Icons.favorite_rounded, 'موردعلاقه', Formatters.count(stats.favoritesCount)),
      (Icons.playlist_play_rounded, 'فهرست ساخته‌شده', Formatters.count(stats.listsCount)),
      (Icons.equalizer_rounded, 'میانگین امتیاز من', Formatters.rating(stats.averageRating)),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 190,
        childAspectRatio: 2.05,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: tiles.length,
      itemBuilder: (context, index) {
        final tile = tiles[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: context.colors.elevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colors.outline),
          ),
          child: Row(
            children: [
              Icon(tile.$1, size: 20, color: context.scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(tile.$3, style: context.text.titleLarge),
                    Text(
                      tile.$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusPie extends StatelessWidget {
  const _StatusPie({required this.breakdown});

  final Map<String, int> breakdown;

  @override
  Widget build(BuildContext context) {
    final entries = breakdown.entries
        .map((entry) => (WatchStatus.fromApi(entry.key), entry.value))
        .where((pair) => pair.$1 != null && pair.$2 > 0)
        .toList();

    if (entries.isEmpty) return const SizedBox.shrink();
    final total = entries.fold<int>(0, (sum, pair) => sum + pair.$2);

    return Row(
      children: [
        SizedBox(
          width: 150,
          height: 150,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 38,
              sections: entries.map((pair) {
                final share = pair.$2 / total * 100;
                return PieChartSectionData(
                  value: pair.$2.toDouble(),
                  color: AppTheme.statusColor(pair.$1),
                  radius: 34,
                  title: share < 8 ? '' : Formatters.percent(share.round()),
                  titleStyle: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: entries.map((pair) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppTheme.statusColor(pair.$1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(pair.$1!.label, style: context.text.labelMedium)),
                    Text(Formatters.count(pair.$2), style: context.text.labelMedium),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _GenreBars extends StatelessWidget {
  const _GenreBars({required this.genres});

  final List<GenreCount> genres;

  @override
  Widget build(BuildContext context) {
    final top = genres.take(6).toList();
    final max = top.first.count.toDouble();

    return SizedBox(
      height: 210,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: max * 1.25,
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 46,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= top.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      top[index].genre,
                      textAlign: TextAlign.center,
                      style: context.text.labelSmall,
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < top.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: top[i].count.toDouble(),
                    width: 22,
                    borderRadius: BorderRadius.circular(6),
                    color: context.scheme.primary,
                  ),
                ],
                showingTooltipIndicators: const [],
              ),
          ],
        ),
      ),
    );
  }
}
