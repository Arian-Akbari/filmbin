import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../providers/auth_provider.dart';
import '../providers/catalog_providers.dart';
import '../widgets/poster_card.dart';
import '../widgets/state_views.dart';

/// Section 5.18 — the landing page: popular, new and top-rated rails, plus the
/// personal picks of section 13 for a signed-in user.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final discover = ref.watch(discoverProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(discoverProvider);
            ref.invalidate(recommendedProvider);
            ref.invalidate(watchlistProvider(WatchStatus.watching));
            await ref.read(discoverProvider.future);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _Header(user: auth.user)),
              if (auth.isAuthenticated) ...[
                const SliverToBoxAdapter(child: _ContinueWatchingRail()),
                const SliverToBoxAdapter(child: _RecommendedRail()),
              ],
              discover.when(
                loading: () => const SliverToBoxAdapter(
                  child: Column(
                    children: [
                      _RailHeaderSkeleton(),
                      PosterRailSkeleton(),
                      SizedBox(height: 26),
                      _RailHeaderSkeleton(),
                      PosterRailSkeleton(),
                    ],
                  ),
                ),
                error: (error, _) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorView(
                    error: error,
                    onRetry: () => ref.invalidate(discoverProvider),
                  ),
                ),
                data: (sections) => SliverList.builder(
                  itemCount: sections.length,
                  itemBuilder: (context, index) =>
                      PosterRail(title: sections[index].title, items: sections[index].items),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 26)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.user});

  final AppUser? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final greeting = user == null ? 'خوش آمدید' : 'سلام ${user!.fullName.split(' ').first}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greeting, style: context.text.headlineSmall),
                const SizedBox(height: 2),
                Text(
                  user == null ? 'برای ثبت فعالیت‌هایت وارد شو' : 'امروز چه چیزی می‌بینی؟',
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
          if (user == null)
            FilledButton.tonal(
              onPressed: () => context.push('/login'),
              child: const Text('ورود'),
            )
          else ...[
            IconButton(
              tooltip: 'فعالیت دوستان',
              onPressed: () => context.push('/feed'),
              icon: const Icon(Icons.dynamic_feed_rounded),
            ),
            if (user!.isAdmin)
              IconButton(
                tooltip: 'مدیریت',
                onPressed: () => context.push('/admin'),
                icon: const Icon(Icons.shield_outlined),
              ),
          ],
        ],
      ),
    );
  }
}

/// Section 5.12 — what the user left half-finished, right at the top.
class _ContinueWatchingRail extends ConsumerWidget {
  const _ContinueWatchingRail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watching = ref.watch(watchlistProvider(WatchStatus.watching));
    return watching.maybeWhen(
      data: (result) => result.items.isEmpty
          ? const SizedBox.shrink()
          : PosterRail(title: 'ادامهٔ تماشا', items: result.items),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// Section 13 — picks built from the genres the user already follows.
class _RecommendedRail extends ConsumerWidget {
  const _RecommendedRail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommended = ref.watch(recommendedProvider);
    return recommended.maybeWhen(
      // A brand-new account has no taste to go on, and the backend answers with
      // the popular rail — showing it twice under a different heading would be
      // a lie, so the shelf stays hidden until there is a real signal.
      data: (page) => page.items.isEmpty || !page.personalized
          ? const SizedBox.shrink()
          : PosterRail(
              title: 'پیشنهاد برای شما',
              subtitle: page.basedOn.isEmpty
                  ? null
                  : 'بر پایهٔ علاقهٔ تو به ${page.basedOn.join('، ')}',
              items: page.items,
            ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// A horizontal row of posters with a heading.
class PosterRail extends StatelessWidget {
  const PosterRail({super.key, required this.title, required this.items, this.subtitle});

  final String title;
  final List<TitleSummary> items;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.text.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(subtitle!, style: context.text.labelSmall),
              ],
            ],
          ),
        ),
        SizedBox(
          height: 292,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              return PosterCard(
                title: item,
                onTap: () => context.push('/title/${item.imdbId}'),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RailHeaderSkeleton extends StatelessWidget {
  const _RailHeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: ShimmerBox(width: 150, height: 19),
      ),
    );
  }
}
