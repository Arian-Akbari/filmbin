import '../../core/network/api_client.dart';
import '../models/models.dart';

/// Section 5.17 — the user's own lists.
class ListsRepository {
  ListsRepository(this._api);

  final ApiClient _api;

  Future<List<CustomList>> myLists() async {
    final data = await _api.get('/lists', forceRefresh: true);
    return (data as List)
        .map((e) => CustomList.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<CustomList> create({
    required String name,
    String? description,
    bool isPublic = true,
  }) async {
    _api.invalidate('/lists');
    final data = await _api.post(
      '/lists',
      data: {
        'name': name,
        if (description != null && description.isNotEmpty) 'description': description,
        'is_public': isPublic,
      },
    );
    return CustomList.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<CustomList> detail(int listId) async {
    final data = await _api.get('/lists/$listId', forceRefresh: true);
    return CustomList.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<CustomList> update(
    int listId, {
    String? name,
    String? description,
    bool? isPublic,
  }) async {
    _api.invalidate('/lists');
    final data = await _api.patch(
      '/lists/$listId',
      data: {'name': ?name, 'description': ?description, 'is_public': ?isPublic},
    );
    return CustomList.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> remove(int listId) async {
    _api.invalidate('/lists');
    await _api.delete('/lists/$listId');
  }

  Future<CustomList> addItem(int listId, String imdbId) async {
    _api.invalidate('/lists');
    final data = await _api.post('/lists/$listId/items', data: {'imdb_id': imdbId});
    return CustomList.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> removeItem(int listId, String imdbId) async {
    _api.invalidate('/lists');
    await _api.delete('/lists/$listId/items/$imdbId');
  }
}
