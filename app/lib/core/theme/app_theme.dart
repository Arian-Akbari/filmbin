import 'package:flutter/material.dart';

import '../../data/models/models.dart';

/// The visual language of the app.
///
/// Cinema-dark by default with a single warm accent; the light theme is the
/// same palette inverted so both feel like one product (section 8.5 — the UI
/// has to look right on every device, including the ones that force light mode).
class AppTheme {
  const AppTheme._();

  static const _accent = Color(0xFFE8B23A);
  static const _accentDeep = Color(0xFFB8801A);

  static const darkBackground = Color(0xFF0D0F14);
  static const darkSurface = Color(0xFF161A22);
  static const darkElevated = Color(0xFF1F2531);
  static const lightBackground = Color(0xFFF6F7FA);
  static const lightSurface = Color(0xFFFFFFFF);

  static const fontFamily = 'Vazirmatn';

  /// Section 5.11 — the five states of the progress bar.
  static Color progressColor(ProgressColor color, Brightness brightness) {
    switch (color) {
      case ProgressColor.none:
        return brightness == Brightness.dark
            ? const Color(0xFF3A4152)
            : const Color(0xFFC9CEDA);
      case ProgressColor.yellow:
        return const Color(0xFFE8B23A);
      case ProgressColor.green:
        return const Color(0xFF3FBF7F);
      case ProgressColor.purple:
        return const Color(0xFF8B6BE0);
      case ProgressColor.red:
        return const Color(0xFFE2564D);
    }
  }

  static String progressLegend(ProgressColor color) {
    switch (color) {
      case ProgressColor.none:
        return 'هنوز شروع نشده';
      case ProgressColor.yellow:
        return 'قسمت دیده‌نشده دارید';
      case ProgressColor.green:
        return 'به‌روزید — ادامه دارد';
      case ProgressColor.purple:
        return 'کامل دیده‌اید';
      case ProgressColor.red:
        return 'تماشا را متوقف کرده‌اید';
    }
  }

  static Color statusColor(WatchStatus? status) {
    switch (status) {
      case WatchStatus.planToWatch:
        return const Color(0xFF5B8DEF);
      case WatchStatus.watching:
        return const Color(0xFF3FBF7F);
      case WatchStatus.watched:
        return const Color(0xFF8B6BE0);
      case WatchStatus.paused:
        return const Color(0xFFE8B23A);
      case WatchStatus.dropped:
        return const Color(0xFFE2564D);
      case null:
        return const Color(0xFF6B7280);
    }
  }

  static ThemeData dark() => _build(
    brightness: Brightness.dark,
    background: darkBackground,
    surface: darkSurface,
    elevated: darkElevated,
    onSurface: const Color(0xFFECEFF6),
    muted: const Color(0xFF9AA3B5),
    outline: const Color(0xFF262D3A),
  );

  static ThemeData light() => _build(
    brightness: Brightness.light,
    background: lightBackground,
    surface: lightSurface,
    elevated: const Color(0xFFEFF1F6),
    onSurface: const Color(0xFF12151C),
    muted: const Color(0xFF5C6579),
    outline: const Color(0xFFE1E4EC),
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color elevated,
    required Color onSurface,
    required Color muted,
    required Color outline,
  }) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: _accent,
      onPrimary: const Color(0xFF1A1400),
      secondary: const Color(0xFF4FB6C4),
      onSecondary: const Color(0xFF001417),
      error: const Color(0xFFE2564D),
      onError: Colors.white,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: elevated,
      outline: outline,
      primaryContainer: _accentDeep,
      onPrimaryContainer: Colors.white,
      // Tonal buttons read from here. Without it Material falls back to the
      // teal secondary, which fights the warm accent everywhere it appears.
      secondaryContainer: elevated,
      onSecondaryContainer: onSurface,
    );

    final base = brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light();

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      dividerColor: outline,
      textTheme: _textTheme(base.textTheme, onSurface, muted),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: elevated,
        hintStyle: TextStyle(color: muted, fontFamily: fontFamily),
        labelStyle: TextStyle(color: muted, fontFamily: fontFamily),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _accent, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // A finite minimum width on purpose: `Size.fromHeight` means an
          // *infinite* minimum width, which explodes the moment a button sits
          // in a Row. Screens that want a full-width button stretch it there.
          minimumSize: const Size(96, 52),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(96, 50),
          side: BorderSide(color: outline),
          foregroundColor: onSurface,
          textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _accent,
          textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: elevated,
        side: BorderSide(color: outline),
        labelStyle: TextStyle(fontFamily: fontFamily, color: onSurface, fontSize: 12.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: _accent,
        unselectedItemColor: muted,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontFamily: fontFamily, fontSize: 11.5),
        unselectedLabelStyle: const TextStyle(fontFamily: fontFamily, fontSize: 11.5),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: _accent.withValues(alpha: 0.16),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontFamily: fontFamily, fontSize: 11.5, color: onSurface),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: elevated,
        contentTextStyle: TextStyle(fontFamily: fontFamily, color: onSurface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: _accent),
      tabBarTheme: TabBarThemeData(
        labelColor: _accent,
        unselectedLabelColor: muted,
        indicatorColor: _accent,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontFamily: fontFamily),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: muted,
        textColor: onSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? _accent : muted,
        ),
      ),
      extensions: [AppColors(muted: muted, elevated: elevated, outline: outline)],
    );
  }

  static TextTheme _textTheme(TextTheme base, Color onSurface, Color muted) {
    TextStyle style(double size, FontWeight weight, {Color? color, double height = 1.55}) =>
        TextStyle(
          fontFamily: fontFamily,
          fontSize: size,
          fontWeight: weight,
          color: color ?? onSurface,
          height: height,
        );

    return base.copyWith(
      displaySmall: style(26, FontWeight.w700, height: 1.35),
      headlineMedium: style(22, FontWeight.w700, height: 1.4),
      headlineSmall: style(19, FontWeight.w700, height: 1.4),
      titleLarge: style(17, FontWeight.w700, height: 1.45),
      titleMedium: style(15, FontWeight.w600),
      titleSmall: style(13.5, FontWeight.w600, color: muted),
      bodyLarge: style(15, FontWeight.w400),
      bodyMedium: style(13.8, FontWeight.w400),
      bodySmall: style(12.5, FontWeight.w400, color: muted),
      labelLarge: style(14, FontWeight.w600),
      labelMedium: style(12.5, FontWeight.w500, color: muted),
      labelSmall: style(11.5, FontWeight.w500, color: muted),
    );
  }
}

/// Extra roles the Material scheme has no slot for.
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({required this.muted, required this.elevated, required this.outline});

  final Color muted;
  final Color elevated;
  final Color outline;

  @override
  AppColors copyWith({Color? muted, Color? elevated, Color? outline}) => AppColors(
    muted: muted ?? this.muted,
    elevated: elevated ?? this.elevated,
    outline: outline ?? this.outline,
  );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      muted: Color.lerp(muted, other.muted, t)!,
      elevated: Color.lerp(elevated, other.elevated, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
  TextTheme get text => Theme.of(this).textTheme;
  ColorScheme get scheme => Theme.of(this).colorScheme;
}
