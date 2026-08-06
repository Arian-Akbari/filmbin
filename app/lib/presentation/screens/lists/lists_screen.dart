import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../providers/auth_provider.dart';
import '../../providers/catalog_providers.dart';
import '../../providers/core_providers.dart';
import '../../widgets/state_views.dart';
import '../title/title_detail_screen.dart' show NewListDialog;

/// Section 5.17 — the user's own named lists.
class ListsScreen extends ConsumerWidget {
  const ListsScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const NewListDialog(),
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      await ref.read(listsRepositoryProvider).create(name: name.trim());
      ref.invalidate(myListsProvider);
      if (context.mounted) showMessage(context, 'فهرست ساخته شد.');
    } on ApiException catch (error) {
      if (context.mounted) showMessage(context, error.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    if (!auth.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('فهرست‌های من')),
        body: EmptyView(
          icon: Icons.playlist_add_rounded,
          message: 'برای ساختن فهرست وارد شو.',
          hint: 'می‌توانی آثار را در فهرست‌های دلخواه مثل «بهترین فیلم‌های اکشن» بچینی.',
          action: FilledButton(
            onPressed: () => context.push('/login'),
            child: const Text('ورود یا ثبت‌نام'),
          ),
        ),
      );
    }

    final lists = ref.watch(myListsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('فهرست‌های من')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('فهرست تازه'),
      ),
      body: lists.when(
        loading: () => const ListSkeleton(itemCount: 4),
        error: (error, _) =>
            ErrorView(error: error, onRetry: () => ref.invalidate(myListsProvider)),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyView(
              icon: Icons.playlist_play_rounded,
              message: 'هنوز فهرستی نساخته‌ای.',
              hint: 'با دکمهٔ پایین صفحه اولین فهرستت را بساز.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myListsProvider);
              await ref.read(myListsProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final list = items[index];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: CircleAvatar(
                      backgroundColor: context.scheme.primary.withValues(alpha: 0.16),
                      child: Icon(
                        list.isPublic ? Icons.public_rounded : Icons.lock_outline_rounded,
                        size: 19,
                        color: context.scheme.primary,
                      ),
                    ),
                    title: Text(list.name),
                    subtitle: Text(
                      [
                        '${Formatters.digits('${list.itemCount}')} اثر',
                        if (list.description != null && list.description!.isNotEmpty)
                          list.description!,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelSmall,
                    ),
                    trailing: const Icon(
                      Icons.chevron_left_rounded,
                      textDirection: TextDirection.ltr,
                    ),
                    onTap: () => context.push('/list/${list.id}'),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
