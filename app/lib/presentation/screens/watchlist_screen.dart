import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../providers/auth_provider.dart';
import '../providers/catalog_providers.dart';
import '../widgets/poster_card.dart';
import '../widgets/progress_bar.dart';
import '../widgets/state_views.dart';

/// Section 5.12 — everything the user is tracking, split by status, with the
/// favourites kept as their own tab because «موردعلاقه» is a flag, not a status.
class WatchlistScreen extends ConsumerStatefulWidget {
  const WatchlistScreen({super.key});

  @override
  ConsumerState<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends ConsumerState<WatchlistScreen>
    with SingleTickerProviderStateMixin {
  static const _tabs = <WatchStatus?>[
    null,
    WatchStatus.watching,
    WatchStatus.planToWatch,
    WatchStatus.watched,
    WatchStatus.paused,
    WatchStatus.dropped,
  ];

  late final TabController _controller;

  @override
  void initState() {
    super.initState();
    // Built eagerly: a guest never reaches the TabBarView, and a `late final`
    // created inside dispose() would look up an already-deactivated ancestor.
    _controller = TabController(length: _tabs.length + 1, vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _labelFor(WatchStatus? status, Map<WatchStatus, int> counts, int total) {
    final count = status == null ? total : (counts[status] ?? 0);
    final name = status?.label ?? 'همه';
    return count == 0 ? name : '$name (${Formatters.digits('$count')})';
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    if (!auth.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('فهرست من')),
        body: EmptyView(
          icon: Icons.bookmark_border_rounded,
          message: 'برای داشتن فهرست شخصی وارد شو.',
          hint: 'وضعیت تماشا، پیشرفت قسمت‌ها و موردعلاقه‌ها به حساب تو گره خورده‌اند.',
          action: FilledButton(
            onPressed: () => context.push('/login'),
            child: const Text('ورود یا ثبت‌نام'),
          ),
        ),
      );
    }

    final all = ref.watch(watchlistProvider(null));
    final counts = all.valueOrNull?.counts ?? const <WatchStatus, int>{};
    final total = all.valueOrNull?.total ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('فهرست من'),
        bottom: TabBar(
          controller: _controller,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            for (final status in _tabs) Tab(text: _labelFor(status, counts, total)),
            const Tab(text: 'موردعلاقه'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  Text('راهنمای رنگ نوار پیشرفت:', style: context.text.labelSmall),
                  const ProgressLegend(),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _controller,
              children: [
                for (final status in _tabs) _WatchlistTab(status: status),
                const _FavoritesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WatchlistTab extends ConsumerWidget {
  const _WatchlistTab({required this.status});

  final WatchStatus? status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(watchlistProvider(status));

    return result.when(
      loading: () => const ListSkeleton(),
      error: (error, _) =>
          ErrorView(error: error, onRetry: () => ref.invalidate(watchlistProvider(status))),
      data: (data) => _TitleGrid(
        items: data.items,
        emptyMessage: status == null
            ? 'هنوز چیزی به فهرستت اضافه نکرده‌ای.'
            : 'در «${status!.label}» چیزی نیست.',
        onRefresh: () async {
          ref.invalidate(watchlistProvider(status));
          await ref.read(watchlistProvider(status).future);
        },
      ),
    );
  }
}

class _FavoritesTab extends ConsumerWidget {
  const _FavoritesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);

    return favorites.when(
      loading: () => const ListSkeleton(),
      error: (error, _) =>
          ErrorView(error: error, onRetry: () => ref.invalidate(favoritesProvider)),
      data: (data) => _TitleGrid(
        items: data.items,
        emptyMessage: 'هنوز چیزی را موردعلاقه نکرده‌ای.',
        onRefresh: () async {
          ref.invalidate(favoritesProvider);
          await ref.read(favoritesProvider.future);
        },
      ),
    );
  }
}

class _TitleGrid extends StatelessWidget {
  const _TitleGrid({required this.items, required this.emptyMessage, required this.onRefresh});

  final List<TitleSummary> items;
  final String emptyMessage;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
            EmptyView(
              icon: Icons.movie_filter_outlined,
              message: emptyMessage,
              hint: 'از صفحهٔ جست‌وجو یا خانه، اثری را انتخاب و وضعیتش را ثبت کن.',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 160,
          childAspectRatio: 0.50,
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final title = items[index];
          return PosterCard(
            title: title,
            width: double.infinity,
            onTap: () => context.push('/title/${title.imdbId}'),
          );
        },
      ),
    );
  }
}
