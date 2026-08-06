import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/catalog_providers.dart';
import '../../providers/core_providers.dart';
import '../../widgets/poster_card.dart';
import '../../widgets/state_views.dart';

/// Section 5.17 — one list: rename it, open it up or lock it down, drop titles
/// out of it, and share the whole thing as text (section 13).
class ListDetailScreen extends ConsumerWidget {
  const ListDetailScreen({super.key, required this.listId});

  final int listId;

  Future<void> _rename(BuildContext context, WidgetRef ref, CustomList list) async {
    final controller = TextEditingController(text: list.name);
    final description = TextEditingController(text: list.description ?? '');
    var isPublic = list.isPublic;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('ویرایش فهرست'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                maxLength: 80,
                decoration: const InputDecoration(labelText: 'نام فهرست'),
              ),
              TextField(
                controller: description,
                maxLength: 300,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'توضیح (اختیاری)'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: isPublic,
                onChanged: (value) => setState(() => isPublic = value),
                title: const Text('همه بتوانند ببینند'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('ذخیره'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    try {
      await ref
          .read(listsRepositoryProvider)
          .update(
            list.id,
            name: controller.text.trim(),
            description: description.text.trim(),
            isPublic: isPublic,
          );
      ref.invalidate(listDetailProvider(list.id));
      ref.invalidate(myListsProvider);
    } on ApiException catch (error) {
      if (context.mounted) showMessage(context, error.message, isError: true);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, CustomList list) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف فهرست'),
        content: Text('فهرست «${list.name}» و همهٔ آیتم‌هایش حذف می‌شوند. مطمئنی؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حذف کن'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(listsRepositoryProvider).remove(list.id);
      ref.invalidate(myListsProvider);
      if (context.mounted) {
        context.pop();
        showMessage(context, 'فهرست حذف شد.');
      }
    } on ApiException catch (error) {
      if (context.mounted) showMessage(context, error.message, isError: true);
    }
  }

  Future<void> _removeItem(
    BuildContext context,
    WidgetRef ref,
    CustomList list,
    TitleSummary title,
  ) async {
    try {
      await ref.read(listsRepositoryProvider).removeItem(list.id, title.imdbId);
      ref.invalidate(listDetailProvider(list.id));
      ref.invalidate(myListsProvider);
    } on ApiException catch (error) {
      if (context.mounted) showMessage(context, error.message, isError: true);
    }
  }

  void _share(CustomList list) {
    final lines = [
      'فهرست «${list.name}» در فیلم‌بین',
      if (list.description != null && list.description!.isNotEmpty) list.description!,
      '',
      ...list.items.map((item) {
        final year = item.yearLabel == null ? '' : ' (${item.yearLabel})';
        return '• ${item.title}$year';
      }),
    ];
    Share.share(lines.join('\n'), subject: list.name);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(listDetailProvider(listId));
    final me = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(list.valueOrNull?.name ?? 'فهرست'),
        actions: [
          if (list.hasValue)
            IconButton(
              tooltip: 'هم‌رسانی فهرست',
              onPressed: () => _share(list.value!),
              icon: const Icon(Icons.ios_share_rounded),
            ),
          if (list.hasValue &&
              me != null &&
              (list.value!.ownerUsername == null || list.value!.ownerUsername == me.username))
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') _rename(context, ref, list.value!);
                if (value == 'delete') _delete(context, ref, list.value!);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('ویرایش فهرست')),
                PopupMenuItem(value: 'delete', child: Text('حذف فهرست')),
              ],
            ),
        ],
      ),
      body: list.when(
        loading: () => const ListSkeleton(),
        error: (error, _) =>
            ErrorView(error: error, onRetry: () => ref.invalidate(listDetailProvider(listId))),
        data: (data) {
          final isOwner =
              me != null && (data.ownerUsername == null || data.ownerUsername == me.username);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(listDetailProvider(listId));
              await ref.read(listDetailProvider(listId).future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                Row(
                  children: [
                    Icon(
                      data.isPublic ? Icons.public_rounded : Icons.lock_outline_rounded,
                      size: 16,
                      color: context.colors.muted,
                    ),
                    const SizedBox(width: 6),
                    Text(data.isPublic ? 'عمومی' : 'خصوصی', style: context.text.labelSmall),
                    const SizedBox(width: 12),
                    Text(
                      '${Formatters.digits('${data.itemCount}')} اثر',
                      style: context.text.labelSmall,
                    ),
                    if (data.ownerUsername != null && !isOwner) ...[
                      const SizedBox(width: 12),
                      Text('ساختهٔ @${data.ownerUsername}', style: context.text.labelSmall),
                    ],
                  ],
                ),
                if (data.description != null && data.description!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(data.description!, style: context.text.bodyMedium),
                ],
                const SizedBox(height: 12),
                if (data.items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: EmptyView(
                      icon: Icons.movie_filter_outlined,
                      message: 'این فهرست خالی است.',
                      hint: 'از صفحهٔ هر اثر، دکمهٔ «افزودن به فهرست دلخواه» را بزن.',
                    ),
                  )
                else
                  for (final item in data.items)
                    TitleRow(
                      title: item,
                      onTap: () => context.push('/title/${item.imdbId}'),
                      trailing: isOwner
                          ? IconButton(
                              tooltip: 'برداشتن از فهرست',
                              onPressed: () => _removeItem(context, ref, data, item),
                              icon: Icon(
                                Icons.remove_circle_outline_rounded,
                                color: context.colors.muted,
                              ),
                            )
                          : null,
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}
