import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import 'bidi_text.dart';

/// Section 5.13 — one to five stars, tappable.
class StarRating extends StatelessWidget {
  const StarRating({
    super.key,
    required this.value,
    this.onChanged,
    this.size = 34,
    this.spacing = 4,
  });

  final int? value;
  final ValueChanged<int>? onChanged;
  final double size;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final score = index + 1;
        final filled = value != null && score <= value!;
        return Padding(
          padding: EdgeInsetsDirectional.only(end: spacing),
          child: GestureDetector(
            onTap: onChanged == null ? null : () => onChanged!(score),
            behavior: HitTestBehavior.opaque,
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: filled ? context.scheme.primary : context.colors.muted,
            ),
          ),
        );
      }),
    );
  }
}

/// Section 5.13 — the share of each star level, 0 to 100.
class RatingDistributionChart extends StatelessWidget {
  const RatingDistributionChart({
    super.key,
    required this.buckets,
    required this.average,
    required this.count,
  });

  final List<RatingBucket> buckets;
  final double? average;
  final int count;

  @override
  Widget build(BuildContext context) {
    if (buckets.isEmpty || count == 0) {
      return Row(
        children: [
          Icon(Icons.people_outline_rounded, size: 18, color: context.colors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text('هنوز کسی به این اثر امتیاز نداده است.', style: context.text.bodySmall),
          ),
        ],
      );
    }

    final ordered = [...buckets]..sort((a, b) => b.score.compareTo(a.score));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          children: [
            Text(
              Formatters.rating(average),
              style: context.text.displaySmall?.copyWith(color: context.scheme.primary),
            ),
            Text('از ۵', style: context.text.labelSmall),
            const SizedBox(height: 4),
            Text('${Formatters.count(count)} رأی', style: context.text.labelSmall),
          ],
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            children: ordered.map((bucket) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.5),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      child: Text(
                        Formatters.digits('${bucket.score}'),
                        style: context.text.labelSmall,
                      ),
                    ),
                    Icon(Icons.star_rounded, size: 12, color: context.scheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: bucket.percent / 100,
                          minHeight: 7,
                          backgroundColor: context.colors.elevated,
                          valueColor: AlwaysStoppedAnimation(context.scheme.primary),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 42,
                      child: Text(
                        Formatters.percent(bucket.percent),
                        textAlign: TextAlign.end,
                        style: context.text.labelSmall,
                      ),
                    ),
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

/// Section 5.14 / 5.15 — a review, with spoilers folded away until asked for.
class ReviewTile extends StatefulWidget {
  const ReviewTile({
    super.key,
    required this.review,
    this.hideSpoilerByDefault = true,
    this.onReport,
    this.onDelete,
    this.isMine = false,
  });

  final Review review;
  final bool hideSpoilerByDefault;
  final VoidCallback? onReport;
  final VoidCallback? onDelete;
  final bool isMine;

  @override
  State<ReviewTile> createState() => _ReviewTileState();
}

class _ReviewTileState extends State<ReviewTile> {
  late bool _revealed = !(widget.review.hasSpoiler && widget.hideSpoilerByDefault);

  @override
  Widget build(BuildContext context) {
    final review = widget.review;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.elevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: context.scheme.primary.withValues(alpha: 0.18),
                backgroundImage: review.user.avatarUrl == null
                    ? null
                    : NetworkImage(review.user.avatarUrl!),
                child: review.user.avatarUrl != null
                    ? null
                    : Text(
                        review.user.initial,
                        style: TextStyle(
                          color: context.scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.user.fullName.isEmpty
                          ? review.user.username
                          : review.user.fullName,
                      style: context.text.titleMedium,
                    ),
                    Text(review.dateLabel, style: context.text.labelSmall),
                  ],
                ),
              ),
              if (widget.onDelete != null || widget.onReport != null)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_horiz_rounded, color: context.colors.muted),
                  onSelected: (value) {
                    if (value == 'delete') widget.onDelete?.call();
                    if (value == 'report') widget.onReport?.call();
                  },
                  itemBuilder: (context) => [
                    if (widget.isMine && widget.onDelete != null)
                      const PopupMenuItem(value: 'delete', child: Text('حذف نظر من')),
                    if (!widget.isMine && widget.onReport != null)
                      const PopupMenuItem(value: 'report', child: Text('گزارش نظر')),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (review.hasSpoiler && !_revealed)
            InkWell(
              onTap: () => setState(() => _revealed = true),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                decoration: BoxDecoration(
                  color: context.scheme.error.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.scheme.error.withValues(alpha: 0.35)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.visibility_off_rounded,
                          size: 16,
                          color: context.scheme.error,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'این نظر داستان را لو می‌دهد',
                            style: context.text.labelMedium?.copyWith(
                              color: context.scheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('برای دیدن، لمس کنید', style: context.text.labelSmall),
                  ],
                ),
              ),
            )
          else ...[
            if (review.hasSpoiler)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 14, color: context.scheme.error),
                    const SizedBox(width: 5),
                    Text(
                      'دارای اسپویل',
                      style: context.text.labelSmall?.copyWith(color: context.scheme.error),
                    ),
                  ],
                ),
              ),
            BidiText(review.text, style: context.text.bodyMedium),
          ],
        ],
      ),
    );
  }
}
