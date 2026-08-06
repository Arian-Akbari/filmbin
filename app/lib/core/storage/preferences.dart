import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/models.dart';

/// Small, non-sensitive settings (deck 08). Tokens never come near this class.
class Preferences {
  Preferences(this._prefs);

  final SharedPreferences _prefs;

  static const _themeKey = 'settings.theme_mode';
  static const _hideSpoilersKey = 'settings.hide_spoilers';
  static const _dataSaverKey = 'settings.data_saver';
  static const _profileKey = 'session.last_profile';

  static Future<Preferences> load() async => Preferences(await SharedPreferences.getInstance());

  ThemeMode get themeMode {
    switch (_prefs.getString(_themeKey)) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) => _prefs.setString(_themeKey, mode.name);

  /// Section 5.15 — remembers whether the reader wants spoilers folded away.
  bool get hideSpoilers => _prefs.getBool(_hideSpoilersKey) ?? true;

  Future<void> setHideSpoilers(bool value) => _prefs.setBool(_hideSpoilersKey, value);

  /// Section 8.8 — skips the large poster and sticks to thumbnails.
  bool get dataSaver => _prefs.getBool(_dataSaverKey) ?? false;

  Future<void> setDataSaver(bool value) => _prefs.setBool(_dataSaverKey, value);

  /// Section 8.4 — the last profile the server confirmed. Not a credential:
  /// the token still lives in secure storage and is still what authorises a
  /// request. This only lets the app open with a name instead of a login
  /// screen when the phone starts up with no connection.
  AppUser? get cachedProfile {
    final raw = _prefs.getString(_profileKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return AppUser.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheProfile(AppUser? user) => user == null
      ? _prefs.remove(_profileKey)
      : _prefs.setString(_profileKey, jsonEncode(user.toJson()));
}
