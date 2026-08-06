import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/app_image.dart';
import '../widgets/state_views.dart';

/// Section 13 — a live room per title. History arrives over REST, new lines over
/// a WebSocket; if the socket never opens the room still works, it just stops
/// updating on its own.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.imdbId, this.titleName = ''});

  final String imdbId;
  final String titleName;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    await ref.read(chatControllerProvider(widget.imdbId).notifier).send(text);
    _scrollToEnd();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatControllerProvider(widget.imdbId));
    final me = ref.watch(currentUserProvider);

    ref.listen(chatControllerProvider(widget.imdbId), (previous, next) {
      if ((previous?.messages.length ?? 0) < next.messages.length) _scrollToEnd();
    });

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('گفت‌وگو'),
            if (widget.titleName.isNotEmpty)
              Text(
                widget.titleName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall,
              ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: state.connected ? const Color(0xFF3FBF7F) : context.colors.muted,
                  ),
                ),
                const SizedBox(width: 6),
                Text(state.connected ? 'زنده' : 'آفلاین', style: context.text.labelSmall),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: state.loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
                : state.messages.isEmpty
                ? const EmptyView(
                    icon: Icons.forum_outlined,
                    message: 'هنوز کسی چیزی ننوشته.',
                    hint: 'اولین نفری باش که نظرش را اینجا می‌گوید.',
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                    itemCount: state.messages.length,
                    itemBuilder: (context, index) {
                      final message = state.messages[index];
                      return _Bubble(
                        message: message,
                        isMine: me != null && me.id == message.user.id,
                      );
                    },
                  ),
          ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                state.error!,
                style: context.text.labelSmall?.copyWith(color: context.scheme.error),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: me == null
                  ? OutlinedButton.icon(
                      onPressed: () => context.push('/login'),
                      icon: const Icon(Icons.login_rounded, size: 18),
                      label: const Text('برای نوشتن پیام وارد شو'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _input,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                            maxLength: 1000,
                            decoration: const InputDecoration(
                              hintText: 'پیامت را بنویس…',
                              counterText: '',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _send,
                          icon: const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.isMine});

  final ChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final name = message.user.fullName.isEmpty ? message.user.username : message.user.fullName;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMine) ...[
            GestureDetector(
              onTap: () => context.push('/user/${message.user.username}'),
              child: AppAvatar(
                url: message.user.avatarUrl,
                initial: message.user.initial,
                size: 32,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color: isMine
                    ? context.scheme.primary.withValues(alpha: 0.20)
                    : context.colors.elevated,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(isMine ? 14 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 14),
                ),
                border: Border.all(color: context.colors.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMine)
                    Text(
                      name,
                      style: context.text.labelSmall?.copyWith(
                        color: context.scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  Text(message.text, style: context.text.bodyMedium),
                  const SizedBox(height: 3),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text(message.timeLabel, style: context.text.labelSmall),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
