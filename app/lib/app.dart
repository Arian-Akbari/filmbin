import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'presentation/providers/settings_provider.dart';
import 'presentation/router.dart';

/// Section 8.2 — the app is Persian and right-to-left first. `fa` is the default
/// locale, and `flutter_localizations` gives the framework widgets (dialogs,
/// pickers, text selection) the same direction and wording.
class FilmBinApp extends ConsumerWidget {
  const FilmBinApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);

    return MaterialApp.router(
      title: 'فیلم‌بین',
      debugShowCheckedModeBanner: false,
      routerConfig: ref.watch(routerProvider),
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      locale: const Locale('fa'),
      supportedLocales: L.supportedLocales,
      localizationsDelegates: const [
        L.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // Keep type sizes sane on phones with very large accessibility settings
        // so the layout never breaks (section 8.5).
        final scale = MediaQuery.textScalerOf(
          context,
        ).clamp(minScaleFactor: 0.9, maxScaleFactor: 1.3);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scale),
          child: Directionality(textDirection: TextDirection.rtl, child: child!),
        );
      },
    );
  }
}
