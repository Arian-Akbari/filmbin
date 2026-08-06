import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/models.dart';
import '../../data/repositories/chat_repository.dart';
import 'core_providers.dart';

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(
    ref.watch(apiClientProvider),
    ref.watch(appConfigProvider),
    ref.watch(tokenStoreProvider),
  ),
);

class ChatState {
  const ChatState({
    this.messages = const [],
    this.loading = true,
    this.connected = false,
    this.error,
  });

  final List<ChatMessage> messages;
  final bool loading;
  final bool connected;
  final String? error;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? loading,
    bool? connected,
    String? error,
    bool clearError = false,
  }) => ChatState(
    messages: messages ?? this.messages,
    loading: loading ?? this.loading,
    connected: connected ?? this.connected,
    error: clearError ? null : (error ?? this.error),
  );
}

class ChatController extends StateNotifier<ChatState> {
  ChatController(this._ref, this.imdbId) : super(const ChatState()) {
    _start();
  }

  final Ref _ref;
  final String imdbId;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  Future<void> _start() async {
    final repository = _ref.read(chatRepositoryProvider);
    try {
      final history = await repository.history(imdbId);
      state = state.copyWith(messages: history, loading: false);
    } on ApiException catch (error) {
      state = state.copyWith(loading: false, error: error.message);
    }

    _channel = await repository.connect(imdbId);
    if (_channel == null) return;

    state = state.copyWith(connected: true);
    _subscription = _channel!.stream.listen(
      (frame) {
        final message = ChatRepository.decode(frame);
        if (message == null) return;
        if (state.messages.any((m) => m.id == message.id)) return;
        state = state.copyWith(messages: [...state.messages, message]);
      },
      onError: (_) => state = state.copyWith(connected: false),
      onDone: () => state = state.copyWith(connected: false),
    );
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    try {
      final message = await _ref.read(chatRepositoryProvider).send(imdbId, trimmed);
      if (!state.messages.any((m) => m.id == message.id)) {
        state = state.copyWith(messages: [...state.messages, message]);
      }
    } on ApiException catch (error) {
      state = state.copyWith(error: error.message);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}

final chatControllerProvider = StateNotifierProvider.autoDispose
    .family<ChatController, ChatState, String>((ref, imdbId) => ChatController(ref, imdbId));
