import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/token_store.dart';
import '../models/models.dart';

/// Live discussion room per title (bonus feature).
///
/// History comes over REST, new messages over a WebSocket. If the socket cannot
/// be opened the room still works — it just stops updating by itself.
class ChatRepository {
  ChatRepository(this._api, this._config, this._tokens);

  final ApiClient _api;
  final AppConfig _config;
  final TokenStore _tokens;

  Future<List<ChatMessage>> history(String imdbId) async {
    final data = await _api.get('/titles/$imdbId/chat', forceRefresh: true);
    return ((data as Map)['items'] as List)
        .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<ChatMessage> send(String imdbId, String text) async {
    final data = await _api.post('/titles/$imdbId/chat', data: {'text': text});
    return ChatMessage.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<WebSocketChannel?> connect(String imdbId) async {
    final token = await _tokens.readAccessToken();
    if (token == null || token.isEmpty) return null;

    final path = Uri.parse(_config.baseUrl).path;
    final uri = Uri.parse('${_config.socketOrigin}$path/titles/$imdbId/chat/ws?token=$token');
    try {
      return WebSocketChannel.connect(uri);
    } catch (_) {
      return null;
    }
  }

  static ChatMessage? decode(dynamic frame) {
    try {
      final data = jsonDecode(frame as String);
      if (data is Map && data['id'] != null) {
        return ChatMessage.fromJson(Map<String, dynamic>.from(data));
      }
    } catch (_) {
      // A malformed frame is not worth crashing the room over.
    }
    return null;
  }
}
