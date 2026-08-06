import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';

/// Section 5.11 — the progress bar under a poster.
///
/// Width shows how much of the series is watched; colour says what kind of
/// "not finished" it is. The server decides the colour so every screen and every
/// client agree.
class WatchProgressBar extends StatelessWidget {
  const WatchProgressBar({
    super.key,
    required this.progress,
    this.height = 6,
    this.showLabel = false,
    this.radius = 4,
  });

  final WatchProgress progress;
  final double height;
  final bool showLabel;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.progressColor(progress.color, Theme.of(context).brightness);
    final track = context.colors.elevated;

    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        children: [
          Container(height: height, color: track),
          FractionallySizedBox(
            widthFactor: progress.fraction == 0 && progress.color != ProgressColor.none
                ? 0.04
                : progress.fraction,
            child: Container(height: height, color: color),
          ),
        ],
      ),
    );

    if (!showLabel) return bar;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              Formatters.percent(progress.percent),
              style: context.text.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Flexible(
              child: Text(
                progress.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        bar,
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                AppTheme.progressLegend(progress.color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall,
              ),
            ),
            if (progress.remainingEpisodes > 0) ...[
              const SizedBox(width: 8),
              Text(
                '${Formatters.digits('${progress.remainingEpisodes}')} قسمت مانده',
                style: context.text.labelSmall,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// The colour key, shown once on the watch-list screen so the rule is learnable.
class ProgressLegend extends StatelessWidget {
  const ProgressLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: ProgressColor.values.map((color) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: AppTheme.progressColor(color, Theme.of(context).brightness),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 6),
            Text(AppTheme.progressLegend(color), style: context.text.labelSmall),
          ],
        );
      }).toList(),
    );
  }
}
