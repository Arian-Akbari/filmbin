import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import 'app_image.dart';
import 'progress_bar.dart';

/// The poster tile used by every list in the app.
class PosterCard extends StatelessWidget {
  const PosterCard({
    super.key,
    required this.title,
    this.width = 132,
    this.onTap,
    this.progress,
    this.showStatus = true,
  });

  final TitleSummary title;
  final double width;
  final VoidCallback? onTap;
  final WatchProgress? progress;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 2 / 3,
                  child: AppImage(url: title.posterThumbUrl ?? title.posterUrl, width: width),
                ),
                if (title.imdbRating != null)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: _Badge(
                      icon: Icons.star_rounded,
                      label: Formatters.rating(title.imdbRating),
                    ),
                  ),
                if (title.isFavorite)
                  const Positioned(
                    top: 6,
                    left: 6,
                    child: _Badge(icon: Icons.favorite_rounded, label: null),
                  ),
                if (showStatus && title.myStatus != null)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      color: AppTheme.statusColor(title.myStatus).withValues(alpha: 0.92),
                      child: Text(
                        title.myStatus!.label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (progress != null) ...[
              const SizedBox(height: 5),
              WatchProgressBar(progress: progress!, height: 4),
            ],
            const SizedBox(height: 7),
            Text(
              title.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.titleMedium?.copyWith(height: 1.35),
            ),
            const SizedBox(height: 2),
            Text(
              [title.yearLabel, title.kindLabel].whereType<String>().join(' · '),
              style: context.text.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label});

  final IconData icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: label == null ? 5 : 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: context.scheme.primary),
          if (label != null) ...[
            const SizedBox(width: 3),
            Text(
              label!,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The wide row used in search results and list screens.
class TitleRow extends StatelessWidget {
  const TitleRow({super.key, required this.title, this.onTap, this.trailing});

  final TitleSummary title;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppImage(
              url: title.posterThumbUrl ?? title.posterUrl,
              width: 66,
              height: 99,
              radius: 12,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleLarge,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      title.kindLabel,
                      title.yearLabel,
                      title.runtimeLabel,
                    ].whereType<String>().join(' · '),
                    style: context.text.labelSmall,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (title.imdbRating != null) ...[
                        Icon(Icons.star_rounded, size: 15, color: context.scheme.primary),
                        const SizedBox(width: 3),
                        Text(
                          Formatters.rating(title.imdbRating),
                          style: context.text.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: context.scheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      if (title.genres.isNotEmpty)
                        Expanded(
                          child: Text(
                            title.genres.take(3).join('، '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.labelSmall,
                          ),
                        ),
                    ],
                  ),
                  if (title.myStatus != null) ...[
                    const SizedBox(height: 7),
                    _StatusChip(status: title.myStatus!),
                  ],
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final WatchStatus status;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status.label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
