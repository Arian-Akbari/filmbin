import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../providers/auth_provider.dart';
import '../providers/catalog_providers.dart';
import '../widgets/app_image.dart';
import '../widgets/state_views.dart';

/// Section 13 — what the people you follow have been watching.
class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    if (!auth.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('فعالیت دوستان')),
        body: EmptyView(
          icon: Icons.dynamic_feed_outlined,
          message: 'برای دنبال کردن دیگران وارد شو.',
          action: FilledButton(
            onPressed: () => context.push('/login'),
            child: const Text('ورود یا ثبت‌نام'),
          ),
        ),
      );
    }

    final feed = ref.watch(feedProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('فعالیت دوستان')),
      body: feed.when(
        loading: () => const ListSkeleton(),
        error: (error, _) =>
            ErrorView(error: error, onRetry: () => ref.invalidate(feedProvider)),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyView(
              icon: Icons.group_outlined,
              message: 'هنوز فعالیتی نیست.',
              hint: 'از صفحهٔ نظرها روی نام کاربران بزن و دنبالشان کن تا اینجا پر شود.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(feedProvider);
              await ref.read(feedProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _FeedTile(item: items[index]),
            ),
          );
        },
      ),
    );
  }
}

class _FeedTile extends StatelessWidget {
  const _FeedTile({required this.item});

  final FeedItem item;

  IconData get _icon {
    switch (item.type) {
      case 'rated':
        return Icons.star_rounded;
      case 'reviewed':
        return Icons.rate_review_rounded;
      case 'finished':
        return Icons.done_all_rounded;
      case 'status_changed':
        return Icons.bookmark_rounded;
      case 'list_created':
        return Icons.playlist_add_rounded;
      default:
        return Icons.bolt_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.elevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => context.push('/user/${item.user.username}'),
            child: AppAvatar(url: item.user.avatarUrl, initial: item.user.initial, size: 42),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_icon, size: 14, color: context.scheme.primary),
                    const SizedBox(width: 5),
                    Text(item.dateLabel, style: context.text.labelSmall),
                  ],
                ),
                const SizedBox(height: 5),
                Text(item.sentence, style: context.text.bodyMedium),
              ],
            ),
          ),
          if (item.title != null) ...[
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => context.push('/title/${item.title!.imdbId}'),
              child: AppImage(
                url: item.title!.posterThumbUrl ?? item.title!.posterUrl,
                width: 44,
                height: 66,
                radius: 8,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
