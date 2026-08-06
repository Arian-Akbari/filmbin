import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import '../../core/network/api_client.dart';
import '../models/models.dart';

/// Sections 5.4, 5.19 and the social extras.
class UserRepository {
  UserRepository(this._api);

  final ApiClient _api;

  Future<AppUser> me({bool forceRefresh = false}) async {
    final data = await _api.get('/users/me', forceRefresh: forceRefresh);
    return AppUser.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<AppUser> updateProfile({String? fullName, String? username, String? bio}) async {
    _api.invalidate('/users/me');
    final data = await _api.patch(
      '/users/me',
      data: {'full_name': ?fullName, 'username': ?username, 'bio': ?bio},
    );
    return AppUser.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> changePassword({required String currentPassword, required String newPassword}) =>
      _api.post(
        '/users/me/password',
        data: {'current_password': currentPassword, 'new_password': newPassword},
      );

  Future<String> uploadAvatar(String filePath) async {
    _api.invalidate('/users/me');
    final extension = filePath.split('.').last.toLowerCase();
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        filePath,
        contentType: MediaType('image', extension == 'jpg' ? 'jpeg' : extension),
      ),
    });
    final data = await _api.upload('/users/me/avatar', form);
    return (data as Map)['avatar_url'] as String;
  }

  Future<UserStats> stats({bool forceRefresh = true}) async {
    final data = await _api.get('/users/me/stats', forceRefresh: forceRefresh);
    return UserStats.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<AppUser> profile(String username) async {
    final data = await _api.get('/users/$username');
    return AppUser.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<bool> follow(String username, {required bool value}) async {
    _api.invalidate('/users/$username');
    _api.invalidate('/feed');
    final data = value
        ? await _api.put('/users/$username/follow')
        : await _api.delete('/users/$username/follow');
    return (data as Map)['is_following'] as bool? ?? value;
  }

  Future<List<FeedItem>> feed() async {
    final data = await _api.get('/feed', forceRefresh: true);
    return ((data as Map)['items'] as List)
        .map((e) => FeedItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
