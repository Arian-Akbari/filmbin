import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../providers/auth_provider.dart';
import '../../providers/catalog_providers.dart';
import '../../providers/core_providers.dart';
import '../../router.dart';
import '../../widgets/app_image.dart';
import '../../widgets/state_views.dart';

/// Section 13 — someone else's profile, and the follow button that fills the
/// activity feed.
class PublicProfileScreen extends ConsumerStatefulWidget {
  const PublicProfileScreen({super.key, required this.username});

  final String username;

  @override
  ConsumerState<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends ConsumerState<PublicProfileScreen> {
  bool _busy = false;

  Future<void> _toggleFollow(bool currentlyFollowing) async {
    if (!ref.read(authControllerProvider).isAuthenticated) {
      await promptSignIn(context);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(userRepositoryProvider)
          .follow(widget.username, value: !currentlyFollowing);
      ref.invalidate(publicProfileProvider(widget.username));
      ref.invalidate(feedProvider);
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(publicProfileProvider(widget.username));
    final me = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: Text('@${widget.username}')),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(publicProfileProvider(widget.username)),
        ),
        data: (user) {
          final isMe = me != null && me.id == user.id;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(publicProfileProvider(widget.username));
              await ref.read(publicProfileProvider(widget.username).future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
              children: [
                Center(
                  child: AppAvatar(url: user.avatarUrl, initial: user.initial, size: 96),
                ),
                const SizedBox(height: 14),
                Text(
                  user.fullName,
                  textAlign: TextAlign.center,
                  style: context.text.headlineSmall,
                ),
                const SizedBox(height: 3),
                Text(
                  '@${user.username}',
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.ltr,
                  style: context.text.labelMedium,
                ),
                if (user.bio != null && user.bio!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(user.bio!, textAlign: TextAlign.center, style: context.text.bodyMedium),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Stat(label: 'دنبال‌کننده', value: user.followers),
                    _Stat(label: 'دنبال‌شده', value: user.following),
                    _Stat(label: 'فیلم دیده‌شده', value: user.summary.watchedMovies),
                    _Stat(label: 'سریال', value: user.summary.followedSeries),
                  ],
                ),
                const SizedBox(height: 22),
                if (!isMe)
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _toggleFollow(user.isFollowing),
                    icon: Icon(
                      user.isFollowing
                          ? Icons.person_remove_alt_1_outlined
                          : Icons.person_add_alt_1_rounded,
                      size: 18,
                    ),
                    label: Text(user.isFollowing ? 'دنبال نکن' : 'دنبال کن'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      backgroundColor: user.isFollowing ? context.colors.elevated : null,
                      foregroundColor: user.isFollowing ? context.scheme.onSurface : null,
                    ),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () => context.push('/profile/edit'),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('ویرایش پروفایل من'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                  ),
                const SizedBox(height: 18),
                Text(
                  'عضو از ${Formatters.relativeDate(user.createdAt)}',
                  textAlign: TextAlign.center,
                  style: context.text.labelSmall,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(Formatters.count(value), style: context.text.titleLarge),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: context.text.labelSmall),
        ],
      ),
    );
  }
}
