import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core_providers.dart';

class SettingsState {
  const SettingsState({
    this.themeMode = ThemeMode.dark,
    this.hideSpoilers = true,
    this.dataSaver = false,
  });

  final ThemeMode themeMode;
  final bool hideSpoilers;
  final bool dataSaver;

  SettingsState copyWith({ThemeMode? themeMode, bool? hideSpoilers, bool? dataSaver}) =>
      SettingsState(
        themeMode: themeMode ?? this.themeMode,
        hideSpoilers: hideSpoilers ?? this.hideSpoilers,
        dataSaver: dataSaver ?? this.dataSaver,
      );
}

class SettingsController extends StateNotifier<SettingsState> {
  SettingsController(this._ref)
    : super(
        SettingsState(
          themeMode: _ref.read(preferencesProvider).themeMode,
          hideSpoilers: _ref.read(preferencesProvider).hideSpoilers,
          dataSaver: _ref.read(preferencesProvider).dataSaver,
        ),
      );

  final Ref _ref;

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _ref.read(preferencesProvider).setThemeMode(mode);
  }

  Future<void> setHideSpoilers(bool value) async {
    state = state.copyWith(hideSpoilers: value);
    await _ref.read(preferencesProvider).setHideSpoilers(value);
  }

  Future<void> setDataSaver(bool value) async {
    state = state.copyWith(dataSaver: value);
    await _ref.read(preferencesProvider).setDataSaver(value);
  }
}

final settingsControllerProvider = StateNotifierProvider<SettingsController, SettingsState>(
  (ref) => SettingsController(ref),
);
