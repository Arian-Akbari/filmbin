import '../../core/utils/formatters.dart';
import 'review.dart';
import 'title.dart';

/// One line of the activity feed of the people you follow.
class FeedItem {
  const FeedItem({
    required this.id,
    required this.type,
    required this.createdAt,
    required this.user,
    this.title,
    this.payload,
  });

  final int id;
  final String type;
  final DateTime createdAt;
  final ReviewAuthor user;
  final TitleSummary? title;
  final Map<String, dynamic>? payload;

  String get dateLabel => Formatters.relativeDate(createdAt);

  String get sentence {
    final name = user.fullName.isNotEmpty ? user.fullName : user.username;
    final work = title?.title ?? 'یک اثر';
    switch (type) {
      case 'rated':
        final score = payload?['score'];
        return '$name به «$work» ${Formatters.digits('$score')} ستاره داد.';
      case 'reviewed':
        return '$name برای «$work» نظر نوشت.';
      case 'finished':
        return '$name تماشای «$work» را تمام کرد.';
      case 'status_changed':
        final status = WatchStatus.fromApi(payload?['status'] as String?);
        return '$name وضعیت «$work» را به «${status?.label ?? '—'}» تغییر داد.';
      case 'list_created':
        return '$name فهرست «${payload?['name'] ?? ''}» را ساخت.';
      default:
        return '$name فعالیتی ثبت کرد.';
    }
  }

  factory FeedItem.fromJson(Map<String, dynamic> json) => FeedItem(
    id: (json['id'] as num).toInt(),
    type: json['type'] as String? ?? '',
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
    user: ReviewAuthor.fromJson(Map<String, dynamic>.from(json['user'] as Map)),
    title: json['title'] == null
        ? null
        : TitleSummary.fromJson(Map<String, dynamic>.from(json['title'] as Map)),
    payload: json['payload'] == null ? null : Map<String, dynamic>.from(json['payload'] as Map),
  );
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.room,
    required this.text,
    required this.createdAt,
    required this.user,
  });

  final int id;
  final String room;
  final String text;
  final DateTime createdAt;
  final ReviewAuthor user;

  String get timeLabel => Formatters.digits(
    '${createdAt.hour.toString().padLeft(2, '0')}:'
    '${createdAt.minute.toString().padLeft(2, '0')}',
  );

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: (json['id'] as num).toInt(),
    room: json['room'] as String? ?? '',
    text: json['text'] as String? ?? '',
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
    user: ReviewAuthor.fromJson(Map<String, dynamic>.from(json['user'] as Map)),
  );
}
