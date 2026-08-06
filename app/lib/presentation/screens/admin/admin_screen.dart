import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';
import '../../providers/admin_providers.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../widgets/state_views.dart';

/// Section 4.3 — the admin console. Every call behind these tabs is already
/// refused by the backend for a normal user; the UI just stops showing the door.
class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    if (!auth.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('پنل مدیریت')),
        body: EmptyView(
          icon: Icons.lock_outline_rounded,
          message: 'این بخش فقط برای مدیران است.',
          action: OutlinedButton(
            onPressed: () => context.go('/home'),
            child: const Text('بازگشت به خانه'),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('پنل مدیریت'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'آمار'),
              Tab(text: 'کاربران'),
              Tab(text: 'گزارش‌ها'),
              Tab(text: 'نظرها'),
              Tab(text: 'حافظهٔ نهان'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_StatsTab(), _UsersTab(), _ReportsTab(), _ReviewsTab(), _CacheTab()],
        ),
      ),
    );
  }
}

class _StatsTab extends ConsumerWidget {
  const _StatsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(adminStatsProvider);

    return stats.when(
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
      error: (error, _) =>
          ErrorView(error: error, onRetry: () => ref.invalidate(adminStatsProvider)),
      data: (data) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(adminStatsProvider);
          await ref.read(adminStatsProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            if (data.imdbCircuitOpen)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.scheme.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.scheme.error.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cloud_off_rounded, color: context.scheme.error, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'مدار محافظ IMDb باز است — سرویس بالادستی پاسخ نمی‌دهد و '
                        'فعلاً از حافظهٔ نهان سرو می‌شود.',
                        style: context.text.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            _Metrics(stats: data),
            if (data.mostTracked.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('پرتعقیب‌ترین آثار', style: context.text.titleLarge),
              const SizedBox(height: 10),
              ...data.mostTracked.map(
                (title) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(title.title),
                  subtitle: Text(
                    title.imdbId,
                    textDirection: TextDirection.ltr,
                    style: context.text.labelSmall,
                  ),
                  trailing: Text(
                    '${Formatters.count(title.count)} کاربر',
                    style: context.text.labelMedium,
                  ),
                  onTap: () => context.push('/title/${title.imdbId}'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.stats});

  final AdminStats stats;

  @override
  Widget build(BuildContext context) {
    final tiles = <(String, String)>[
      ('کاربران', Formatters.count(stats.users)),
      ('کاربران فعال', Formatters.count(stats.activeUsers)),
      ('مدیران', Formatters.count(stats.admins)),
      ('نشست‌های باز', Formatters.count(stats.activeSessions)),
      ('آثار در حافظه', Formatters.count(stats.cachedTitles)),
      ('قسمت‌های در حافظه', Formatters.count(stats.cachedEpisodes)),
      ('امتیازها', Formatters.count(stats.ratings)),
      ('نظرها', Formatters.count(stats.reviews)),
      ('نظرهای پنهان‌شده', Formatters.count(stats.hiddenReviews)),
      ('گزارش‌های باز', Formatters.count(stats.pendingReports)),
      ('ردیف‌های فهرست تماشا', Formatters.count(stats.watchEntries)),
      ('قسمت‌های دیده‌شده', Formatters.count(stats.episodeMarks)),
      ('فهرست‌های دلخواه', Formatters.count(stats.lists)),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 190,
        childAspectRatio: 2.1,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: tiles.length,
      itemBuilder: (context, index) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.colors.elevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(tiles[index].$2, style: context.text.titleLarge),
            Text(
              tiles[index].$1,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _UsersTab extends ConsumerStatefulWidget {
  const _UsersTab();

  @override
  ConsumerState<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<_UsersTab> {
  final _search = TextEditingController();
  String? _query;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _update(AdminUserRow row, {bool? isActive, String? role}) async {
    try {
      await ref
          .read(adminRepositoryProvider)
          .updateUser(row.id, isActive: isActive, role: role);
      ref.invalidate(adminUsersProvider);
      ref.invalidate(adminStatsProvider);
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(adminUsersProvider(_query));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: TextField(
            controller: _search,
            onSubmitted: (value) =>
                setState(() => _query = value.trim().isEmpty ? null : value.trim()),
            decoration: InputDecoration(
              hintText: 'جست‌وجوی نام کاربری یا ایمیل',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  _search.clear();
                  setState(() => _query = null);
                },
              ),
            ),
          ),
        ),
        Expanded(
          child: users.when(
            loading: () => const ListSkeleton(),
            error: (error, _) =>
                ErrorView(error: error, onRetry: () => ref.invalidate(adminUsersProvider)),
            data: (rows) => rows.isEmpty
                ? const EmptyView(icon: Icons.person_off_outlined, message: 'کاربری پیدا نشد.')
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                    itemCount: rows.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 14, color: context.colors.outline),
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Row(
                          children: [
                            Flexible(child: Text(row.fullName)),
                            if (row.isAdmin) ...[
                              const SizedBox(width: 6),
                              Icon(
                                Icons.shield_rounded,
                                size: 14,
                                color: context.scheme.primary,
                              ),
                            ],
                            if (!row.isActive) ...[
                              const SizedBox(width: 6),
                              Icon(Icons.block_rounded, size: 14, color: context.scheme.error),
                            ],
                          ],
                        ),
                        // Two lines, two directions: the handle and the email
                        // are Latin, the counts are Persian. One Text with a
                        // forced direction mangles whichever half loses.
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '@${row.username} · ${row.email}',
                              textDirection: TextDirection.ltr,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.labelSmall,
                            ),
                            Text(
                              '${Formatters.digits('${row.reviews}')} نظر · '
                              '${Formatters.digits('${row.ratings}')} امتیاز',
                              style: context.text.labelSmall,
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            switch (value) {
                              case 'block':
                                _update(row, isActive: false);
                              case 'unblock':
                                _update(row, isActive: true);
                              case 'promote':
                                _update(row, role: 'admin');
                              case 'demote':
                                _update(row, role: 'user');
                            }
                          },
                          itemBuilder: (context) => [
                            if (row.isActive)
                              const PopupMenuItem(value: 'block', child: Text('مسدود کن'))
                            else
                              const PopupMenuItem(value: 'unblock', child: Text('رفع مسدودی')),
                            if (row.isAdmin)
                              const PopupMenuItem(
                                value: 'demote',
                                child: Text('سلب دسترسی مدیر'),
                              )
                            else
                              const PopupMenuItem(
                                value: 'promote',
                                child: Text('ارتقا به مدیر'),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _ReportsTab extends ConsumerWidget {
  const _ReportsTab();

  Future<void> _resolve(
    BuildContext context,
    WidgetRef ref,
    AdminReport report, {
    required String status,
    bool deleteReview = false,
  }) async {
    try {
      await ref
          .read(adminRepositoryProvider)
          .resolveReport(report.id, status: status, deleteReview: deleteReview);
      ref.invalidate(adminReportsProvider);
      ref.invalidate(adminStatsProvider);
      if (context.mounted) showMessage(context, 'گزارش رسیدگی شد.');
    } on ApiException catch (error) {
      if (context.mounted) showMessage(context, error.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(adminReportsProvider);

    return reports.when(
      loading: () => const ListSkeleton(),
      error: (error, _) =>
          ErrorView(error: error, onRetry: () => ref.invalidate(adminReportsProvider)),
      data: (items) => items.isEmpty
          ? const EmptyView(icon: Icons.flag_outlined, message: 'گزارشی در انتظار رسیدگی نیست.')
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final report = items[index];
                return Container(
                  padding: const EdgeInsets.all(13),
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
                          Icon(
                            report.isPending ? Icons.flag_rounded : Icons.check_circle_rounded,
                            size: 16,
                            color: report.isPending
                                ? context.scheme.error
                                : const Color(0xFF3FBF7F),
                          ),
                          const SizedBox(width: 7),
                          Expanded(child: Text(report.reason)),
                          Text(
                            Formatters.relativeDate(report.createdAt),
                            style: context.text.labelSmall,
                          ),
                        ],
                      ),
                      if (report.reporterUsername != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'گزارش‌دهنده: @${report.reporterUsername}',
                          textDirection: TextDirection.ltr,
                          style: context.text.labelSmall,
                        ),
                      ],
                      if (report.review != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: context.scheme.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '@${report.review!.user.username}',
                                textDirection: TextDirection.ltr,
                                style: context.text.labelSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(report.review!.text, style: context.text.bodySmall),
                            ],
                          ),
                        ),
                      ],
                      if (report.isPending) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    _resolve(context, ref, report, status: 'dismissed'),
                                child: const Text('رد گزارش'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                onPressed: () => _resolve(
                                  context,
                                  ref,
                                  report,
                                  status: 'resolved',
                                  deleteReview: true,
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: context.scheme.error,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('حذف نظر'),
                              ),
                            ),
                          ],
                        ),
                      ] else if (report.resolutionNote != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'یادداشت: ${report.resolutionNote}',
                            style: context.text.labelSmall,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _ReviewsTab extends ConsumerWidget {
  const _ReviewsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(adminReviewsProvider);

    return reviews.when(
      loading: () => const ListSkeleton(),
      error: (error, _) =>
          ErrorView(error: error, onRetry: () => ref.invalidate(adminReviewsProvider)),
      data: (rows) => rows.isEmpty
          ? const EmptyView(icon: Icons.rate_review_outlined, message: 'نظری ثبت نشده است.')
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              itemCount: rows.length,
              separatorBuilder: (_, _) => Divider(height: 16, color: context.colors.outline),
              itemBuilder: (context, index) {
                final row = rows[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    row.titleName ?? row.review.titleId,
                    style: context.text.titleMedium,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 3),
                      Text(
                        '@${row.review.user.username} · ${row.review.dateLabel}'
                        '${row.review.hasSpoiler ? ' · اسپویل' : ''}'
                        '${row.isHidden ? ' · پنهان‌شده' : ''}',
                        style: context.text.labelSmall,
                      ),
                      const SizedBox(height: 5),
                      Text(row.review.text, maxLines: 3, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: row.isHidden
                      ? null
                      : IconButton(
                          tooltip: 'پنهان کردن نظر',
                          icon: Icon(
                            Icons.visibility_off_outlined,
                            color: context.scheme.error,
                          ),
                          onPressed: () async {
                            try {
                              await ref.read(adminRepositoryProvider).hideReview(row.review.id);
                              ref.invalidate(adminReviewsProvider);
                              ref.invalidate(adminStatsProvider);
                            } on ApiException catch (error) {
                              if (context.mounted) {
                                showMessage(context, error.message, isError: true);
                              }
                            }
                          },
                        ),
                  onTap: () => context.push('/title/${row.review.titleId}'),
                );
              },
            ),
    );
  }
}

/// Section 7.6 — the admin can force a re-fetch or drop a title from the mirror.
class _CacheTab extends ConsumerWidget {
  const _CacheTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titles = ref.watch(adminTitlesProvider);

    return titles.when(
      loading: () => const ListSkeleton(),
      error: (error, _) =>
          ErrorView(error: error, onRetry: () => ref.invalidate(adminTitlesProvider)),
      data: (rows) => rows.isEmpty
          ? const EmptyView(icon: Icons.storage_rounded, message: 'حافظهٔ نهان خالی است.')
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              itemCount: rows.length,
              separatorBuilder: (_, _) => Divider(height: 12, color: context.colors.outline),
              itemBuilder: (context, index) {
                final row = rows[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(row.title),
                  subtitle: Text(
                    '${row.imdbId} · ${row.kind == 'series' ? 'سریال' : 'فیلم'}'
                    '${row.year == null ? '' : ' · ${Formatters.digits('${row.year}')}'}'
                    ' · ${Formatters.relativeDate(row.fetchedAt)}'
                    ' · ${Formatters.digits('${row.trackedBy}')} دنبال‌کننده',
                    style: context.text.labelSmall,
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      final repository = ref.read(adminRepositoryProvider);
                      try {
                        if (value == 'refresh') {
                          await repository.refreshTitle(row.imdbId);
                          if (context.mounted) {
                            showMessage(context, 'اطلاعات از IMDb تازه‌سازی شد.');
                          }
                        } else {
                          await repository.evictTitle(row.imdbId);
                          if (context.mounted) {
                            showMessage(context, 'از حافظهٔ نهان پاک شد.');
                          }
                        }
                        ref.invalidate(adminTitlesProvider);
                        ref.invalidate(adminStatsProvider);
                      } on ApiException catch (error) {
                        if (context.mounted) {
                          showMessage(context, error.message, isError: true);
                        }
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'refresh', child: Text('تازه‌سازی از IMDb')),
                      PopupMenuItem(value: 'evict', child: Text('پاک کردن از حافظه')),
                    ],
                  ),
                  onTap: () => context.push('/title/${row.imdbId}'),
                );
              },
            ),
    );
  }
}
