import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/storage/local_database.dart';
import 'core/storage/preferences.dart';
import 'presentation/providers/core_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Both are opened once at startup so no screen ever waits on disk I/O.
  final database = await LocalDatabase.open();
  final preferences = await Preferences.load();

  runApp(
    ProviderScope(
      overrides: [
        localDatabaseProvider.overrideWithValue(database),
        preferencesProvider.overrideWithValue(preferences),
      ],
      child: const FilmBinApp(),
    ),
  );
}
