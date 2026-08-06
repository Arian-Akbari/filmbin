import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/catalog_providers.dart';
import '../../providers/core_providers.dart';
import '../../router.dart';
import '../../widgets/app_image.dart';
import '../../widgets/bidi_text.dart';
import '../../widgets/state_views.dart';

/// Sections 5.8 and 5.10 — the episodes of one season, each with a tick, plus
/// «تمام فصل» for the common case of catching up in one go.
class SeasonScreen extends ConsumerWidget {
  const SeasonScreen({
    super.key,
    required this.imdbId,
    required this.season,
    this.seriesTitle = '',
  });

  final String imdbId;
  final int season;
  final String seriesTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (imdbId: imdbId, season: season);
    final episodes = ref.watch(seasonEpisodesProvider(key));
    final progress = ref.watch(titleProgressProvider(imdbId));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('فصل ${Formatters.digits('$season')}'),
            if (seriesTitle.isNotEmpty)
              Text(
                seriesTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall,
              ),
          ],
        ),
      ),
      body: episodes.when(
        loading: () => const ListSkeleton(),
        error: (error, _) =>
            ErrorView(error: error, onRetry: () => ref.invalidate(seasonEpisodesProvider(key))),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyView(
              icon: Icons.tv_off_rounded,
              message: 'قسمتی برای این فصل ثبت نشده است.',
            );
          }

          final watched = items.where((e) => e.isWatched).length;
          final allWatched = watched == items.length;

          return Column(
            children: [
              _SeasonHeader(
                total: items.length,
                watched: watched,
                progress: progress.valueOrNull,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _SeasonAction(imdbId: imdbId, season: season, allWatched: allWatched),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(seasonEpisodesProvider(key));
                    await ref.read(seasonEpisodesProvider(key).future);
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        EpisodeTile(episode: items[index], seriesId: imdbId, season: season),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SeasonHeader extends StatelessWidget {
  const _SeasonHeader({required this.total, required this.watched, required this.progress});

  final int total;
  final int watched;
  final WatchProgress? progress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '${Formatters.digits('$watched')} از ${Formatters.digits('$total')} قسمت این فصل',
                style: context.text.titleMedium,
              ),
              const Spacer(),
              if (progress != null)
                Text(
                  'کل سریال: ${Formatters.percent(progress!.percent)}',
                  style: context.text.labelSmall,
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : watched / total,
              minHeight: 6,
              backgroundColor: context.colors.elevated,
              valueColor: AlwaysStoppedAnimation(
                progress == null
                    ? context.scheme.primary
                    : AppTheme.progressColor(progress!.color, Theme.of(context).brightness),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeasonAction extends ConsumerStatefulWidget {
  const _SeasonAction({required this.imdbId, required this.season, required this.allWatched});

  final String imdbId;
  final int season;
  final bool allWatched;

  @override
  ConsumerState<_SeasonAction> createState() => _SeasonActionState();
}

class _SeasonActionState extends ConsumerState<_SeasonAction> {
  bool _busy = false;

  Future<void> _toggle() async {
    if (!ref.read(authControllerProvider).isAuthenticated) {
      await promptSignIn(context);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(trackingRepositoryProvider)
          .markSeason(widget.imdbId, widget.season, watched: !widget.allWatched);
      if (!mounted) return;
      ref.invalidate(seasonEpisodesProvider((imdbId: widget.imdbId, season: widget.season)));
      invalidateTitle(ref, widget.imdbId);
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _busy ? null : _toggle,
      icon: Icon(
        widget.allWatched ? Icons.remove_done_rounded : Icons.done_all_rounded,
        size: 18,
      ),
      label: Text(widget.allWatched ? 'برداشتن نشان تمام فصل' : 'کل فصل را دیده‌ام'),
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
    );
  }
}

/// One episode row — number, name, air date, runtime, rating and the tick.
class EpisodeTile extends ConsumerStatefulWidget {
  const EpisodeTile({
    super.key,
    required this.episode,
    required this.seriesId,
    required this.season,
  });

  final Episode episode;
  final String seriesId;
  final int season;

  @override
  ConsumerState<EpisodeTile> createState() => _EpisodeTileState();
}

class _EpisodeTileState extends ConsumerState<EpisodeTile> {
  bool _busy = false;
  bool _expanded = false;

  Future<void> _toggleWatched() async {
    if (!ref.read(authControllerProvider).isAuthenticated) {
      await promptSignIn(context);
      return;
    }
    setState(() => _busy = true);
    final tracking = ref.read(trackingRepositoryProvider);
    try {
      if (widget.episode.isWatched) {
        await tracking.unmarkEpisode(widget.seriesId, widget.episode.imdbId);
      } else {
        await tracking.markEpisode(widget.seriesId, widget.episode.imdbId);
      }
      if (!mounted) return;
      ref.invalidate(seasonEpisodesProvider((imdbId: widget.seriesId, season: widget.season)));
      invalidateTitle(ref, widget.seriesId);
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final episode = widget.episode;
    final meta = <String>[
      if (episode.airDateLabel != null) episode.airDateLabel!,
      if (episode.runtimeLabel != null) episode.runtimeLabel!,
    ];

    return Container(
      decoration: BoxDecoration(
        color: context.colors.elevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: episode.isWatched
              ? context.scheme.primary.withValues(alpha: 0.45)
              : context.colors.outline,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: episode.plot == null || episode.plot!.isEmpty
                ? null
                : () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppImage(
                    url: episode.stillUrl,
                    width: 104,
                    height: 60,
                    radius: 10,
                    icon: Icons.tv_rounded,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          episode.code,
                          textDirection: TextDirection.ltr,
                          style: context.text.labelSmall,
                        ),
                        const SizedBox(height: 2),
                        BidiText(
                          episode.title ??
                              'قسمت ${Formatters.digits('${episode.episodeNumber}')}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (episode.imdbRating != null) ...[
                              Icon(Icons.star_rounded, size: 13, color: context.scheme.primary),
                              const SizedBox(width: 3),
                              Text(
                                Formatters.rating(episode.imdbRating),
                                style: context.text.labelSmall,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                meta.join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.labelSmall,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  _busy
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          ),
                        )
                      : IconButton(
                          tooltip: episode.isWatched ? 'دیده‌نشده کن' : 'دیدم',
                          onPressed: _toggleWatched,
                          icon: Icon(
                            episode.isWatched
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: episode.isWatched
                                ? context.scheme.primary
                                : context.colors.muted,
                          ),
                        ),
                ],
              ),
            ),
          ),
          if (_expanded && episode.plot != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: BidiText(episode.plot!, style: context.text.bodySmall),
            ),
        ],
      ),
    );
  }
}
