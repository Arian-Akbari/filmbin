import 'title.dart';

/// Section 5.17 — a list the user made, e.g. «بهترین فیلم‌های اکشن».
class CustomList {
  const CustomList({
    required this.id,
    required this.name,
    required this.isPublic,
    required this.itemCount,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.ownerUsername,
    this.items = const [],
  });

  final int id;
  final String name;
  final bool isPublic;
  final int itemCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? description;
  final String? ownerUsername;
  final List<TitleSummary> items;

  factory CustomList.fromJson(Map<String, dynamic> json) => CustomList(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String? ?? '',
    isPublic: json['is_public'] as bool? ?? true,
    itemCount: (json['item_count'] as num?)?.toInt() ?? 0,
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
    description: json['description'] as String?,
    ownerUsername: json['owner_username'] as String?,
    items: ((json['items'] as List?) ?? const [])
        .map((e) => TitleSummary.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );
}
