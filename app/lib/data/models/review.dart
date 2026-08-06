import '../../core/utils/formatters.dart';

class ReviewAuthor {
  const ReviewAuthor({
    required this.id,
    required this.username,
    required this.fullName,
    this.avatarUrl,
  });

  final int id;
  final String username;
  final String fullName;
  final String? avatarUrl;

  String get initial {
    final source = fullName.trim().isNotEmpty ? fullName.trim() : username;
    return source.isEmpty ? '؟' : source.substring(0, 1);
  }

  factory ReviewAuthor.fromJson(Map<String, dynamic> json) => ReviewAuthor(
    id: (json['id'] as num).toInt(),
    username: json['username'] as String? ?? '',
    fullName: json['full_name'] as String? ?? '',
    avatarUrl: json['avatar_url'] as String?,
  );
}

/// Section 5.14 — text, author, avatar, date and the spoiler flag.
class Review {
  const Review({
    required this.id,
    required this.titleId,
    required this.text,
    required this.hasSpoiler,
    required this.createdAt,
    required this.updatedAt,
    required this.user,
  });

  final int id;
  final String titleId;
  final String text;
  final bool hasSpoiler;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ReviewAuthor user;

  String get dateLabel => Formatters.relativeDate(createdAt);

  factory Review.fromJson(Map<String, dynamic> json) => Review(
    id: (json['id'] as num).toInt(),
    titleId: json['title_id'] as String? ?? '',
    text: json['text'] as String? ?? '',
    hasSpoiler: json['has_spoiler'] as bool? ?? false,
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
    updatedAt:
        DateTime.tryParse(json['updated_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
    user: ReviewAuthor.fromJson(Map<String, dynamic>.from(json['user'] as Map)),
  );
}

class ReviewPage {
  const ReviewPage({required this.items, required this.total, this.hiddenSpoilers = 0});

  final List<Review> items;
  final int total;
  final int hiddenSpoilers;

  factory ReviewPage.fromJson(Map<String, dynamic> json) => ReviewPage(
    items: ((json['items'] as List?) ?? const [])
        .map((e) => Review.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    total: (json['total'] as num?)?.toInt() ?? 0,
    hiddenSpoilers: (json['hidden_spoilers'] as num?)?.toInt() ?? 0,
  );
}
