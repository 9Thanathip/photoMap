import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_tokens.dart';

abstract final class AppTheme {
  /// The platform system UI font — San Francisco on Apple, Roboto (null =
  /// Flutter default) on Android — so the app reads as native, not Google-web.
  static final String? _systemFont =
      (Platform.isIOS || Platform.isMacOS) ? '.SF Pro Text' : null;

  static ThemeData light() => _build(
        ColorScheme.fromSeed(seedColor: AppColors.seed, brightness: Brightness.light),
        AppTokens.light(),
      );

  static ThemeData dark() => _build(
        ColorScheme.fromSeed(seedColor: AppColors.seed, brightness: Brightness.dark),
        AppTokens.dark(),
      );

  static ThemeData _build(ColorScheme seeded, AppTokens tokens) {
    // No purple in this app — primary actions are monochrome:
    // black on light, white on dark (matches the splash brand).
    final isDark = seeded.brightness == Brightness.dark;
    final mono = isDark ? Colors.white : Colors.black;
    final onMono = isDark ? Colors.black : Colors.white;
    final cs = seeded.copyWith(
      primary: mono,
      onPrimary: onMono,
      secondary: mono,
      onSecondary: onMono,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      fontFamily: _systemFont,
    );
    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[tokens],
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: _systemFont,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: cs.onSurface,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        labelTextStyle: WidgetStateProperty.all(
          TextStyle(
              fontFamily: _systemFont,
              fontSize: 11,
              fontWeight: FontWeight.w500),
        ),
        height: 68,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerHighest.withAlpha(80),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
          textStyle: TextStyle(
              fontFamily: _systemFont,
              fontSize: 16,
              fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: cs.outline),
          textStyle: TextStyle(
              fontFamily: _systemFont,
              fontSize: 16,
              fontWeight: FontWeight.w500),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cs.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
