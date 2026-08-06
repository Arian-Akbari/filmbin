import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/catalog_providers.dart';
import '../../providers/core_providers.dart';
import '../../providers/settings_provider.dart';
import '../../router.dart';
import '../../widgets/app_image.dart';
import '../../widgets/bidi_text.dart';
import '../../widgets/progress_bar.dart';
import '../../widgets/rating_widgets.dart';
import '../../widgets/state_views.dart';

/// Sections 5.7–5.17 in one page: everything known about one title and
/// everything the signed-in user can record about it.
class TitleDetailScreen extends ConsumerWidget {
  const TitleDetailScreen({super.key, required this.imdbId});

  final String imdbId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(titleDetailProvider(imdbId));

    return Scaffold(
      body: detail.when(
        loading: () => const _DetailSkeleton(),
        error: (error, _) => Scaffold(
          appBar: AppBar(),
          body: ErrorView(
            error: error,
            onRetry: () => ref.invalidate(titleDetailProvider(imdbId)),
          ),
        ),
        data: (data) => _Body(detail: data),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.detail});

  final TitleDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = detail.summary;

    return RefreshIndicator(
      onRefresh: () async {
        invalidateTitle(ref, detail.imdbId);
        await ref.read(titleDetailProvider(detail.imdbId).future);
      },
      child: CustomScrollView(
        slivers: [
          _PosterHeader(detail: detail),
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MetaLine(detail: detail),
                    const SizedBox(height: 14),
                    _ActionBar(detail: detail),
                    if (detail.isSeries) ...[
                      const SizedBox(height: 18),
                      _ProgressCard(detail: detail),
                    ],
                    if (summary.plot != null && summary.plot!.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const _SectionTitle('خلاصهٔ داستان'),
                      BidiText(summary.plot!, style: context.text.bodyMedium),
                    ],
                    const SizedBox(height: 18),
                    _FactsGrid(detail: detail),
                  ],
                ),
              ),
              if (detail.cast.isNotEmpty) _CastRail(cast: detail.cast),
              if (detail.isSeries && detail.seasons.isNotEmpty) _SeasonsSection(detail: detail),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
                child: _RatingSection(detail: detail),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
                child: _ReviewSection(detail: detail),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _PosterHeader extends ConsumerWidget {
  const _PosterHeader({required this.detail});

  final TitleDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = detail.summary;

    return SliverAppBar(
      expandedHeight: 320,
      pinned: true,
      actions: [
        IconButton(
          tooltip: 'گفت‌وگو دربارهٔ این اثر',
          icon: const Icon(Icons.forum_outlined),
          onPressed: () => context.push('/title/${detail.imdbId}/chat', extra: summary.title),
        ),
        IconButton(
          tooltip: 'هم‌رسانی',
          icon: const Icon(Icons.ios_share_rounded),
          onPressed: () => _share(detail),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsetsDirectional.only(start: 56, end: 56, bottom: 14),
        title: Text(
          summary.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            AppImage(url: summary.posterUrl ?? summary.posterThumbUrl, radius: 0),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.28),
                    Colors.transparent,
                    Theme.of(context).scaffoldBackgroundColor,
                  ],
                  stops: const [0, 0.42, 1],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section 13 — a plain text share, so it works with every app on the phone.
void _share(TitleDetail detail) {
  final summary = detail.summary;
  final lines = [
    '${summary.title}${summary.yearLabel == null ? '' : ' (${summary.yearLabel})'}',
    if (summary.imdbRating != null) 'امتیاز IMDb: ${Formatters.rating(summary.imdbRating)}',
    if (summary.genres.isNotEmpty) summary.genres.join('، '),
    '',
    'https://www.imdb.com/title/${detail.imdbId}/',
    '— هم‌رسانی از فیلم‌بین',
  ];
  Share.share(lines.join('\n'), subject: summary.title);
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.detail});

  final TitleDetail detail;

  @override
  Widget build(BuildContext context) {
    final summary = detail.summary;
    final bits = <String>[
      summary.kindLabel,
      if (summary.yearLabel != null) summary.yearLabel!,
      if (summary.runtimeLabel != null) summary.runtimeLabel!,
      if (detail.statusLabel != null) detail.statusLabel!,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(summary.title, style: context.text.headlineSmall),
        if (summary.originalTitle != null && summary.originalTitle != summary.title) ...[
          const SizedBox(height: 2),
          Text(
            summary.originalTitle!,
            textDirection: TextDirection.ltr,
            style: context.text.bodySmall,
          ),
        ],
        const SizedBox(height: 8),
        Text(bits.join(' · '), style: context.text.labelMedium),
        if (summary.genres.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: summary.genres
                .map(
                  (genre) => Chip(
                    label: Text(genre),
                    padding: EdgeInsets.zero,
                    labelStyle: context.text.labelSmall,
                    visualDensity: VisualDensity.compact,
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            _ScorePill(
              icon: Icons.star_rounded,
              label: 'IMDb',
              value: Formatters.rating(summary.imdbRating),
              hint: summary.imdbVotes == null
                  ? null
                  : '${Formatters.compact(summary.imdbVotes!)} رأی',
            ),
            const SizedBox(width: 10),
            _ScorePill(
              icon: Icons.people_alt_rounded,
              label: 'کاربران فیلم‌بین',
              value: Formatters.rating(summary.userRatingAverage),
              hint: '${Formatters.count(summary.userRatingCount)} رأی',
            ),
          ],
        ),
      ],
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.icon, required this.label, required this.value, this.hint});

  final IconData icon;
  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.colors.elevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.outline),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: context.scheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: context.text.titleLarge),
                  Text(label, style: context.text.labelSmall),
                  if (hint != null) Text(hint!, style: context.text.labelSmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sections 5.9 and 5.16 — status, favourite and lists, all in one row.
class _ActionBar extends ConsumerStatefulWidget {
  const _ActionBar({required this.detail});

  final TitleDetail detail;

  @override
  ConsumerState<_ActionBar> createState() => _ActionBarState();
}

class _ActionBarState extends ConsumerState<_ActionBar> {
  bool _busy = false;

  TitleSummary get _summary => widget.detail.summary;

  Future<void> _guard(Future<void> Function() action) async {
    if (!ref.read(authControllerProvider).isAuthenticated) {
      await promptSignIn(context);
      return;
    }
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) invalidateTitle(ref, widget.detail.imdbId);
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickStatus() async {
    if (!ref.read(authControllerProvider).isAuthenticated) {
      await promptSignIn(context);
      return;
    }
    final chosen = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('وضعیت تماشا', style: context.text.titleLarge),
            ),
            for (final status in WatchStatus.values)
              ListTile(
                leading: Icon(Icons.circle, size: 14, color: AppTheme.statusColor(status)),
                title: Text(status.label),
                trailing: _summary.myStatus == status
                    ? Icon(Icons.check_rounded, color: context.scheme.primary)
                    : null,
                onTap: () => Navigator.of(context).pop(status),
              ),
            if (_summary.myStatus != null)
              ListTile(
                leading: const Icon(Icons.remove_circle_outline_rounded),
                title: const Text('برداشتن از فهرست'),
                onTap: () => Navigator.of(context).pop('clear'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (chosen == null) return;
    final tracking = ref.read(trackingRepositoryProvider);
    await _guard(() async {
      if (chosen == 'clear') {
        await tracking.clearStatus(widget.detail.imdbId);
      } else {
        await tracking.setStatus(widget.detail.imdbId, chosen as WatchStatus);
      }
    });
  }

  Future<void> _toggleFavorite() => _guard(() async {
    await ref
        .read(trackingRepositoryProvider)
        .setFavorite(widget.detail.imdbId, !_summary.isFavorite);
  });

  Future<void> _addToList() async {
    if (!ref.read(authControllerProvider).isAuthenticated) {
      await promptSignIn(context);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => AddToListSheet(imdbId: widget.detail.imdbId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _summary.myStatus;

    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _busy ? null : _pickStatus,
            icon: Icon(status == null ? Icons.add_rounded : Icons.bookmark_rounded, size: 18),
            label: Text(status?.label ?? 'افزودن به فهرست من'),
            style: FilledButton.styleFrom(
              backgroundColor: status == null ? null : AppTheme.statusColor(status),
              foregroundColor: status == null ? null : Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: 'موردعلاقه',
          onPressed: _busy ? null : _toggleFavorite,
          icon: Icon(
            _summary.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: _summary.isFavorite ? context.scheme.error : null,
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: 'افزودن به فهرست دلخواه',
          onPressed: _busy ? null : _addToList,
          icon: const Icon(Icons.playlist_add_rounded),
        ),
      ],
    );
  }
}

/// Section 5.11 — how far through the series the user is, in width and colour.
class _ProgressCard extends ConsumerWidget {
  const _ProgressCard({required this.detail});

  final TitleDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = detail.progress;
    if (progress == null || progress.totalEpisodes == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.elevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.outline),
      ),
      child: WatchProgressBar(progress: progress, height: 8, showLabel: true),
    );
  }
}

class _FactsGrid extends StatelessWidget {
  const _FactsGrid({required this.detail});

  final TitleDetail detail;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      if (detail.directors.isNotEmpty) ('کارگردان', detail.directors.join('، ')),
      if (detail.creators.isNotEmpty) ('سازنده', detail.creators.join('، ')),
      if (detail.countries.isNotEmpty) ('کشور سازنده', detail.countries.join('، ')),
      if (detail.seasonCount != null) ('تعداد فصل', Formatters.digits('${detail.seasonCount}')),
      if (detail.episodeCount != null)
        ('تعداد قسمت', Formatters.digits('${detail.episodeCount}')),
    ];

    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('مشخصات'),
        ...rows.map(
          (row) => Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 96, child: Text(row.$1, style: context.text.labelMedium)),
                Expanded(child: BidiText(row.$2, style: context.text.bodyMedium)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Section 5.7 — the cast, with the character each one plays.
class _CastRail extends StatelessWidget {
  const _CastRail({required this.cast});

  final List<CastMember> cast;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 20, 18, 0),
          child: _SectionTitle('بازیگران'),
        ),
        SizedBox(
          height: 156,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            itemCount: cast.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final member = cast[index];
              return SizedBox(
                width: 86,
                child: Column(
                  children: [
                    AppAvatar(
                      url: member.image,
                      initial: member.name.substring(0, 1),
                      size: 72,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      member.name,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelMedium,
                    ),
                    if (member.roleLabel != null)
                      Text(
                        member.roleLabel!,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.labelSmall,
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Section 5.8 — the season list; each row opens its episodes.
class _SeasonsSection extends ConsumerWidget {
  const _SeasonsSection({required this.detail});

  final TitleDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('فصل‌ها'),
          ...detail.seasons.map((season) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: context.scheme.primary.withValues(alpha: 0.16),
                  child: Text(
                    Formatters.digits('${season.number}'),
                    style: TextStyle(
                      color: context.scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                title: Text('فصل ${Formatters.digits('${season.number}')}'),
                subtitle: Text(
                  '${Formatters.digits('${season.episodeCount}')} قسمت',
                  style: context.text.labelSmall,
                ),
                trailing: const Icon(
                  Icons.chevron_left_rounded,
                  textDirection: TextDirection.ltr,
                ),
                onTap: () => context.push(
                  '/title/${detail.imdbId}/season/${season.number}',
                  extra: detail.summary.title,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Section 5.13 — my stars, the average and the distribution.
class _RatingSection extends ConsumerStatefulWidget {
  const _RatingSection({required this.detail});

  final TitleDetail detail;

  @override
  ConsumerState<_RatingSection> createState() => _RatingSectionState();
}

class _RatingSectionState extends ConsumerState<_RatingSection> {
  bool _busy = false;

  Future<void> _rate(int score) async {
    if (!ref.read(authControllerProvider).isAuthenticated) {
      await promptSignIn(context);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(reviewsRepositoryProvider).rate(widget.detail.imdbId, score);
      if (mounted) invalidateTitle(ref, widget.detail.imdbId);
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeRating() async {
    setState(() => _busy = true);
    try {
      await ref.read(reviewsRepositoryProvider).removeRating(widget.detail.imdbId);
      if (mounted) invalidateTitle(ref, widget.detail.imdbId);
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.detail.summary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        const _SectionTitle('امتیاز کاربران'),
        RatingDistributionChart(
          buckets: widget.detail.ratingDistribution,
          average: summary.userRatingAverage,
          count: summary.userRatingCount,
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.colors.elevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colors.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                summary.myRating == null ? 'امتیاز شما' : 'امتیاز شما ثبت شد',
                style: context.text.titleMedium,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  StarRating(value: summary.myRating, onChanged: _busy ? null : _rate),
                  const Spacer(),
                  if (summary.myRating != null)
                    TextButton(
                      onPressed: _busy ? null : _removeRating,
                      child: const Text('حذف امتیاز'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Sections 5.14 and 5.15 — reviews, with spoilers folded away by default.
class _ReviewSection extends ConsumerWidget {
  const _ReviewSection({required this.detail});

  final TitleDetail detail;

  Future<void> _write(BuildContext context, WidgetRef ref) async {
    if (!ref.read(authControllerProvider).isAuthenticated) {
      await promptSignIn(context);
      return;
    }
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ReviewComposer(imdbId: detail.imdbId, existing: detail.myReview),
    );
    if (saved == true && context.mounted) invalidateTitle(ref, detail.imdbId);
  }

  Future<void> _report(BuildContext context, WidgetRef ref, Review review) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => const _ReportDialog(),
    );
    if (reason == null || reason.trim().isEmpty) return;
    try {
      await ref.read(reviewsRepositoryProvider).report(review.id, reason.trim());
      if (context.mounted) showMessage(context, 'گزارش شما برای بررسی ثبت شد.');
    } on ApiException catch (error) {
      if (context.mounted) showMessage(context, error.message, isError: true);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Review review) async {
    try {
      await ref.read(reviewsRepositoryProvider).deleteReview(review.id, imdbId: detail.imdbId);
      if (context.mounted) {
        invalidateTitle(ref, detail.imdbId);
        showMessage(context, 'نظر شما حذف شد.');
      }
    } on ApiException catch (error) {
      if (context.mounted) showMessage(context, error.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(reviewsProvider(detail.imdbId));
    final hideSpoilers = ref.watch(settingsControllerProvider).hideSpoilers;
    final me = ref.watch(currentUserProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(child: _SectionTitle('نظرها')),
            TextButton.icon(
              onPressed: () => _write(context, ref),
              icon: Icon(
                detail.myReview == null ? Icons.rate_review_outlined : Icons.edit_outlined,
                size: 18,
              ),
              label: Text(detail.myReview == null ? 'نظر بنویس' : 'ویرایش نظر من'),
            ),
          ],
        ),
        reviews.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
          ),
          error: (error, _) => ErrorView(
            error: error,
            compact: true,
            onRetry: () => ref.invalidate(reviewsProvider(detail.imdbId)),
          ),
          data: (page) {
            if (page.items.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  'هنوز نظری ثبت نشده — اولین نفر باش.',
                  style: context.text.bodySmall,
                ),
              );
            }
            return Column(
              children: [
                for (final review in page.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ReviewTile(
                      review: review,
                      hideSpoilerByDefault: hideSpoilers,
                      isMine: me != null && me.id == review.user.id,
                      onDelete: me != null && me.id == review.user.id
                          ? () => _delete(context, ref, review)
                          : null,
                      onReport: me != null && me.id != review.user.id
                          ? () => _report(context, ref, review)
                          : null,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Section 5.14 — writing or editing one review; the spoiler switch is part of
/// the form, not an afterthought.
class ReviewComposer extends ConsumerStatefulWidget {
  const ReviewComposer({super.key, required this.imdbId, this.existing});

  final String imdbId;
  final Review? existing;

  @override
  ConsumerState<ReviewComposer> createState() => _ReviewComposerState();
}

class _ReviewComposerState extends ConsumerState<ReviewComposer> {
  late final TextEditingController _text = TextEditingController(
    text: widget.existing?.text ?? '',
  );
  late bool _hasSpoiler = widget.existing?.hasSpoiler ?? false;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final problem = Validators.reviewText(_text.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(reviewsRepositoryProvider)
          .writeReview(widget.imdbId, text: _text.text.trim(), hasSpoiler: _hasSpoiler);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.existing == null ? 'نظر تازه' : 'ویرایش نظر',
            style: context.text.titleLarge,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _text,
            maxLines: 6,
            maxLength: 4000,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'نظرت دربارهٔ این اثر چیست؟',
              errorText: _error,
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _hasSpoiler,
            onChanged: (value) => setState(() => _hasSpoiler = value),
            title: const Text('این نظر داستان را لو می‌دهد'),
            subtitle: Text(
              'با روشن بودن این گزینه، متن تا وقتی کسی نخواهد پنهان می‌ماند.',
              style: context.text.labelSmall,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Text('ثبت نظر'),
          ),
        ],
      ),
    );
  }
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog();

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final _controller = TextEditingController();
  static const _presets = [
    'توهین و بی‌احترامی',
    'اسپویل بدون هشدار',
    'تبلیغ یا هرزنامه',
    'محتوای نامناسب',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('گزارش نظر'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: _presets
                .map(
                  (preset) => ActionChip(
                    label: Text(preset),
                    onPressed: () => setState(() => _controller.text = preset),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLength: 300,
            decoration: const InputDecoration(labelText: 'دلیل گزارش'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('انصراف')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('ارسال گزارش'),
        ),
      ],
    );
  }
}

/// Section 5.17 — drop the title into one of the user's own lists.
class AddToListSheet extends ConsumerStatefulWidget {
  const AddToListSheet({super.key, required this.imdbId});

  final String imdbId;

  @override
  ConsumerState<AddToListSheet> createState() => _AddToListSheetState();
}

class _AddToListSheetState extends ConsumerState<AddToListSheet> {
  bool _busy = false;

  Future<void> _add(int listId) async {
    setState(() => _busy = true);
    try {
      await ref.read(listsRepositoryProvider).addItem(listId, widget.imdbId);
      ref.invalidate(myListsProvider);
      if (mounted) {
        Navigator.of(context).pop();
        showMessage(context, 'به فهرست اضافه شد.');
      }
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createAndAdd() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const NewListDialog(),
    );
    if (name == null || name.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final list = await ref.read(listsRepositoryProvider).create(name: name.trim());
      await ref.read(listsRepositoryProvider).addItem(list.id, widget.imdbId);
      ref.invalidate(myListsProvider);
      if (mounted) {
        Navigator.of(context).pop();
        showMessage(context, 'فهرست «${list.name}» ساخته شد و اثر به آن اضافه شد.');
      }
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lists = ref.watch(myListsProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('افزودن به فهرست', style: context.text.titleLarge),
            const SizedBox(height: 10),
            lists.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 26),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
              ),
              error: (error, _) => ErrorView(error: error, compact: true),
              data: (items) => items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text('هنوز فهرستی نساخته‌ای.', style: context.text.bodySmall),
                    )
                  : ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: ListView(
                        shrinkWrap: true,
                        children: items
                            .map(
                              (list) => ListTile(
                                leading: Icon(
                                  list.isPublic
                                      ? Icons.public_rounded
                                      : Icons.lock_outline_rounded,
                                  size: 20,
                                ),
                                title: Text(list.name),
                                subtitle: Text(
                                  '${Formatters.digits('${list.itemCount}')} اثر',
                                  style: context.text.labelSmall,
                                ),
                                onTap: _busy ? null : () => _add(list.id),
                              ),
                            )
                            .toList(),
                      ),
                    ),
            ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: _busy ? null : _createAndAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('ساخت فهرست تازه'),
            ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}

class NewListDialog extends StatefulWidget {
  const NewListDialog({super.key, this.initialName});

  final String? initialName;

  @override
  State<NewListDialog> createState() => _NewListDialogState();
}

class _NewListDialogState extends State<NewListDialog> {
  late final _controller = TextEditingController(text: widget.initialName ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('فهرست تازه'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 80,
        decoration: const InputDecoration(
          labelText: 'نام فهرست',
          hintText: 'مثلاً بهترین فیلم‌های اکشن',
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('انصراف')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('بساز'),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, style: context.text.titleLarge),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: const [
        ShimmerBox(height: 320, radius: 0),
        Padding(
          padding: EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerBox(height: 22, width: 220),
              SizedBox(height: 12),
              ShimmerBox(height: 14, width: 160),
              SizedBox(height: 22),
              ShimmerBox(height: 46),
              SizedBox(height: 22),
              ShimmerBox(height: 13),
              SizedBox(height: 8),
              ShimmerBox(height: 13),
              SizedBox(height: 8),
              ShimmerBox(height: 13, width: 200),
            ],
          ),
        ),
      ],
    );
  }
}
