import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Posters and stills.
///
/// Every remote image goes through here so caching, sizing and the fallback are
/// decided in one place (sections 8.1 and 8.8 — images must be cached and never
/// downloaded larger than they are drawn).
class AppImage extends StatelessWidget {
  const AppImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.radius = 14,
    this.fit = BoxFit.cover,
    this.icon = Icons.movie_outlined,
  });

  final String? url;
  final double? width;
  final double? height;
  final double radius;
  final BoxFit fit;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final placeholder = _Placeholder(width: width, height: height, icon: icon);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url == null || url!.isEmpty
          ? placeholder
          : CachedNetworkImage(
              imageUrl: url!,
              width: width,
              height: height,
              fit: fit,
              fadeInDuration: const Duration(milliseconds: 180),
              // Decode at display size instead of full resolution. A width of
              // `infinity` means "as wide as the parent", which is not a number
              // we can decode to — fall back to the generic cap.
              memCacheWidth: width == null || !width!.isFinite
                  ? 720
                  : (width! * MediaQuery.devicePixelRatioOf(context)).round(),
              placeholder: (_, _) => placeholder,
              errorWidget: (_, _, _) => placeholder,
            ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({this.width, this.height, required this.icon});

  final double? width;
  final double? height;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: context.colors.elevated,
      alignment: Alignment.center,
      child: Icon(icon, color: context.colors.muted, size: 26),
    );
  }
}

/// Round avatar with a letter fallback.
class AppAvatar extends StatelessWidget {
  const AppAvatar({super.key, required this.url, required this.initial, this.size = 44});

  final String? url;
  final String initial;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.scheme.primary.withValues(alpha: 0.18),
        ),
        alignment: Alignment.center,
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.42,
            fontWeight: FontWeight.w700,
            color: context.scheme.primary,
          ),
        ),
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        memCacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
        errorWidget: (_, _, _) => AppAvatar(url: null, initial: initial, size: size),
      ),
    );
  }
}
