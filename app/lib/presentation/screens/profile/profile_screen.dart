import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/catalog_providers.dart';
import '../../widgets/app_image.dart';
import '../../widgets/state_views.dart';

/// Section 5.4 — my page: who I am, my three counters and every door that leads
/// out of here.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;

    if (!auth.isAuthenticated || user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('پروفایل'),
          actions: [
            IconButton(
              tooltip: 'تنظیمات',
              onPressed: () => context.push('/settings'),
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
        body: EmptyView(
          icon: Icons.person_outline_rounded,
          message: 'به‌عنوان مهمان می‌گردی.',
          hint: 'با ورود، وضعیت تماشا، امتیازها و فهرست‌هایت روی همهٔ دستگاه‌ها می‌ماند.',
          action: FilledButton(
            onPressed: () => context.push('/login'),
            child: const Text('ورود یا ثبت‌نام'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('پروفایل'),
        actions: [
          IconButton(
            tooltip: 'ویرایش پروفایل',
            onPressed: () => context.push('/profile/edit'),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'تنظیمات',
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(authControllerProvider.notifier).refreshProfile();
          ref.invalidate(userStatsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
          children: [
            _ProfileHeader(user: user),
            const SizedBox(height: 20),
            _SummaryRow(summary: user.summary),
            const SizedBox(height: 14),
            _FollowRow(user: user),
            const SizedBox(height: 22),
            _MenuTile(
              icon: Icons.insights_rounded,
              title: 'آمار فعالیت من',
              subtitle: 'زمان تماشا، ژانرهای محبوب و روند فعالیت',
              onTap: () => context.push('/stats'),
            ),
            _MenuTile(
              icon: Icons.dynamic_feed_rounded,
              title: 'فعالیت دوستان',
              subtitle: 'کارهای تازهٔ کسانی که دنبال می‌کنی',
              onTap: () => context.push('/feed'),
            ),
            _MenuTile(
              icon: Icons.playlist_play_rounded,
              title: 'فهرست‌های من',
              subtitle: 'فهرست‌های دلخواهی که ساخته‌ای',
              onTap: () => context.go('/lists'),
            ),
            _MenuTile(
              icon: Icons.favorite_border_rounded,
              title: 'موردعلاقه‌ها',
              subtitle: 'آثاری که نشان‌دار کرده‌ای',
              onTap: () => context.go('/watchlist'),
            ),
            if (user.isAdmin)
              _MenuTile(
                icon: Icons.shield_outlined,
                title: 'پنل مدیریت',
                subtitle: 'کاربران، نظرها، گزارش‌ها و حافظهٔ نهان',
                onTap: () => context.push('/admin'),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('خروج از حساب'),
                    content: const Text(
                      'اطلاعات ذخیره‌شدهٔ این دستگاه پاک می‌شود؛ حسابت دست‌نخورده می‌ماند.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('انصراف'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('خروج'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) return;
                await ref.read(authControllerProvider.notifier).logout();
                if (context.mounted) context.go('/home');
              },
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('خروج از حساب'),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.scheme.error,
                minimumSize: const Size.fromHeight(46),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppAvatar(url: user.avatarUrl, initial: user.initial, size: 78),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.fullName, style: context.text.headlineSmall),
              const SizedBox(height: 2),
              Text(
                '@${user.username}',
                textDirection: TextDirection.ltr,
                style: context.text.labelMedium,
              ),
              if (user.bio != null && user.bio!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(user.bio!, style: context.text.bodySmall),
              ],
              if (user.isAdmin) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: context.scheme.primary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'مدیر سامانه',
                    style: context.text.labelSmall?.copyWith(color: context.scheme.primary),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Section 5.1 — the three counters the profile promises.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.summary});

  final UserSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Counter(label: 'فیلم دیده‌شده', value: summary.watchedMovies),
        _Counter(label: 'سریال دنبال‌شده', value: summary.followedSeries),
        _Counter(label: 'موردعلاقه', value: summary.favorites),
      ],
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: context.colors.elevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colors.outline),
        ),
        child: Column(
          children: [
            Text(Formatters.count(value), style: context.text.headlineSmall),
            const SizedBox(height: 3),
            Text(label, textAlign: TextAlign.center, style: context.text.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _FollowRow extends StatelessWidget {
  const _FollowRow({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${Formatters.count(user.followers)} دنبال‌کننده',
          style: context.text.labelMedium,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text('·', style: context.text.labelMedium),
        ),
        Text('${Formatters.count(user.following)} دنبال‌شده', style: context.text.labelMedium),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: context.scheme.primary),
        title: Text(title),
        subtitle: Text(subtitle, style: context.text.labelSmall),
        trailing: const Icon(Icons.chevron_left_rounded, textDirection: TextDirection.ltr),
        onTap: onTap,
      ),
    );
  }
}
