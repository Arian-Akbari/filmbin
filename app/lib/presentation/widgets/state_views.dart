import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';

/// Section 5.20 and 8.2 — one honest, readable screen for every failure, and a
/// loading state that never leaves the user staring at a blank page.

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry, this.compact = false});

  final Object error;
  final VoidCallback? onRetry;
  final bool compact;

  ApiException? get _api => error is ApiException ? error as ApiException : null;

  IconData get _icon {
    final api = _api;
    if (api == null) return Icons.error_outline_rounded;
    if (api.isOffline) return Icons.wifi_off_rounded;
    if (api.isTimeout) return Icons.hourglass_empty_rounded;
    if (api.isServiceDown) return Icons.cloud_off_rounded;
    if (api.isNotFound) return Icons.search_off_rounded;
    if (api.isForbidden) return Icons.lock_outline_rounded;
    return Icons.error_outline_rounded;
  }

  String get _message => _api?.message ?? 'خطای پیش‌بینی‌نشده‌ای رخ داد. دوباره تلاش کنید.';

  String? get _hint {
    final api = _api;
    if (api == null) return null;
    if (api.isOffline) {
      return 'اتصال دستگاه را بررسی کنید؛ اطلاعات ذخیره‌شده همچنان در دسترس است.';
    }
    if (api.isServiceDown) {
      return 'سرویس اطلاعاتی موقتاً پاسخ نمی‌دهد. کمی بعد دوباره امتحان کنید.';
    }
    if (api.isRateLimited) return 'کمی صبر کنید و دوباره تلاش کنید.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_icon, size: compact ? 30 : 44, color: context.colors.muted),
        SizedBox(height: compact ? 8 : 14),
        Text(
          _message,
          textAlign: TextAlign.center,
          style: compact ? context.text.bodyMedium : context.text.titleLarge,
        ),
        if (_hint != null && !compact) ...[
          const SizedBox(height: 6),
          Text(_hint!, textAlign: TextAlign.center, style: context.text.bodySmall),
        ],
        if (onRetry != null) ...[
          SizedBox(height: compact ? 8 : 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('تلاش دوباره'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(150, 42)),
          ),
        ],
      ],
    );

    return Center(
      child: Padding(padding: const EdgeInsets.all(24), child: content),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.message,
    this.icon = Icons.inbox_rounded,
    this.hint,
    this.action,
  });

  final String message;
  final IconData icon;
  final String? hint;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: context.colors.muted),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center, style: context.text.titleLarge),
            if (hint != null) ...[
              const SizedBox(height: 6),
              Text(hint!, textAlign: TextAlign.center, style: context.text.bodySmall),
            ],
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

/// Skeleton placeholders — the page keeps its shape while data arrives.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({super.key, this.width, this.height = 16, this.radius = 8});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final base = context.colors.elevated;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: Color.lerp(base, context.colors.muted, 0.25)!,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(radius)),
      ),
    );
  }
}

class PosterRailSkeleton extends StatelessWidget {
  const PosterRailSkeleton({super.key, this.itemCount = 4});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 292,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, _) => const SizedBox(
          width: 132,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ShimmerBox(height: 198, radius: 14),
              SizedBox(height: 8),
              ShimmerBox(height: 13),
              SizedBox(height: 6),
              ShimmerBox(height: 11, width: 60),
            ],
          ),
        ),
      ),
    );
  }
}

class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (_, _) => const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(width: 66, height: 99, radius: 12),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(height: 15, width: 170),
                SizedBox(height: 8),
                ShimmerBox(height: 12, width: 110),
                SizedBox(height: 8),
                ShimmerBox(height: 12, width: 140),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when the data on screen came from the local mirror.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({
    super.key,
    this.message = 'آفلاین هستید — اطلاعات ذخیره‌شده نمایش داده می‌شود.',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: context.scheme.primary.withValues(alpha: 0.14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 16, color: context.scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: context.text.labelMedium?.copyWith(color: context.scheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small helper so screens can show a message without repeating boilerplate.
void showMessage(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? context.scheme.error : null,
        duration: const Duration(seconds: 3),
      ),
    );
}

void showErrorMessage(BuildContext context, Object error) {
  final message = error is ApiException ? error.message : 'خطایی رخ داد.';
  showMessage(context, message, isError: true);
}
