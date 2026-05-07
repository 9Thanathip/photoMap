import 'package:flutter/material.dart';
import 'app_palette.dart';

/// Semantic design tokens. Resolves to a brightness-aware value via
/// `Theme.of(context).extension<AppTokens>()` (or the [AppTokensX]
/// helper: `context.tokens`).
///
/// Add tokens here when a value carries a *role* (surface, accent, text)
/// rather than a raw hex.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.surfaceBase,
    required this.surfaceCard,
    required this.surfaceCardAlt,
    required this.surfaceMuted,
    required this.surfaceElevated,
    required this.borderSubtle,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textOnAccent,
    required this.accentGold,
    required this.accentGoldDeep,
    required this.accentGoldLight,
    required this.accentViolet,
    required this.accentVioletText,
    required this.accentVioletSurface,
    required this.accentCoral,
    required this.goldRowGradient,
    required this.goldGrad,
    required this.shimmerBase,
    required this.shimmerHighlight,
    required this.glassFill,
    required this.glassBorder,
    required this.glassShadow,
    required this.scrimSoft,
    required this.scrimMedium,
    required this.scrimStrong,
    required this.dividerSoft,
  });

  // Surfaces
  final Color surfaceBase;       // page background
  final Color surfaceCard;       // primary card
  final Color surfaceCardAlt;    // alt card tone (#141420 / white)
  final Color surfaceMuted;      // non-visited / placeholder fill
  final Color surfaceElevated;   // pill / chip / inner placeholder

  // Borders
  final Color borderSubtle;
  final Color borderStrong;

  // Text
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textOnAccent;

  // Accents
  final Color accentGold;          // primary gold (kGold1)
  final Color accentGoldDeep;      // gold700
  final Color accentGoldLight;     // gold300
  final Color accentViolet;        // primary violet
  final Color accentVioletText;    // text-on-violet-surface
  final Color accentVioletSurface; // tinted bg for violet badges
  final Color accentCoral;

  // Gradients
  final List<Color> goldRowGradient; // visited card bg sweep
  final List<Color> goldGrad;        // pill / button gold sweep

  // Shimmer
  final Color shimmerBase;
  final Color shimmerHighlight;

  // Glass
  final Color glassFill;
  final Color glassBorder;
  final Color glassShadow;

  // Scrims (overlays — black at varying alpha)
  final Color scrimSoft;
  final Color scrimMedium;
  final Color scrimStrong;

  // Divider
  final Color dividerSoft;

  factory AppTokens.light() => AppTokens(
        surfaceBase: Palette.neutral50,
        surfaceCard: Colors.white,
        surfaceCardAlt: Colors.white,
        surfaceMuted: Palette.neutral200,
        surfaceElevated: Palette.neutral200,
        borderSubtle: Colors.black.withValues(alpha: 0.06),
        borderStrong: Palette.neutral200,
        textPrimary: Palette.neutral900,
        textSecondary: Palette.neutral500,
        textTertiary: Palette.neutral400,
        textOnAccent: Colors.black,
        accentGold: Palette.gold400,
        accentGoldDeep: Palette.gold700,
        accentGoldLight: Palette.gold300,
        accentViolet: Palette.violet500,
        accentVioletText: Palette.violet700,
        accentVioletSurface: Palette.violetTintLight,
        accentCoral: Palette.coral500,
        goldRowGradient: const [
          Palette.goldBgLight1,
          Palette.goldBgLight2,
          Palette.goldBgLight1,
        ],
        goldGrad: const [Palette.gold700, Palette.gold400],
        shimmerBase: const Color(0xFFEEEEEE),
        shimmerHighlight: const Color(0xFFFAFAFA),
        glassFill: Colors.white.withValues(alpha: 0.7),
        glassBorder: Colors.white.withValues(alpha: 0.3),
        glassShadow: Colors.black.withValues(alpha: 0.07),
        scrimSoft: Colors.black.withValues(alpha: 0.08),
        scrimMedium: Colors.black.withValues(alpha: 0.25),
        scrimStrong: Colors.black.withValues(alpha: 0.55),
        dividerSoft: Colors.black.withValues(alpha: 0.06),
      );

  factory AppTokens.dark() => AppTokens(
        surfaceBase: Palette.neutral950,
        surfaceCard: Palette.neutral860,
        surfaceCardAlt: Palette.neutral880,
        surfaceMuted: Palette.neutral720,
        surfaceElevated: Palette.neutral820,
        borderSubtle: Colors.white.withValues(alpha: 0.08),
        borderStrong: Palette.neutral720,
        textPrimary: Colors.white,
        textSecondary: Colors.white54,
        textTertiary: Colors.white24,
        textOnAccent: Colors.black,
        accentGold: Palette.gold400,
        accentGoldDeep: Palette.gold700,
        accentGoldLight: Palette.gold300,
        accentViolet: Palette.violet500,
        accentVioletText: Colors.white.withValues(alpha: 0.7),
        accentVioletSurface: Palette.violetTintDark,
        accentCoral: Palette.coral500,
        goldRowGradient: const [
          Palette.goldBgDark1,
          Palette.goldBgDark2,
          Palette.goldBgDark1,
        ],
        goldGrad: const [Palette.gold700, Palette.gold400],
        shimmerBase: Colors.white.withValues(alpha: 0.06),
        shimmerHighlight: Colors.white.withValues(alpha: 0.12),
        glassFill: Colors.white.withValues(alpha: 0.105),
        glassBorder: Colors.white.withValues(alpha: 0.12),
        glassShadow: Colors.black.withValues(alpha: 0.25),
        scrimSoft: Colors.white.withValues(alpha: 0.08),
        scrimMedium: Colors.black.withValues(alpha: 0.32),
        scrimStrong: Colors.black.withValues(alpha: 0.6),
        dividerSoft: Colors.white.withValues(alpha: 0.07),
      );

  @override
  AppTokens copyWith({
    Color? surfaceBase,
    Color? surfaceCard,
    Color? surfaceCardAlt,
    Color? surfaceMuted,
    Color? surfaceElevated,
    Color? borderSubtle,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textOnAccent,
    Color? accentGold,
    Color? accentGoldDeep,
    Color? accentGoldLight,
    Color? accentViolet,
    Color? accentVioletText,
    Color? accentVioletSurface,
    Color? accentCoral,
    List<Color>? goldRowGradient,
    List<Color>? goldGrad,
    Color? shimmerBase,
    Color? shimmerHighlight,
    Color? glassFill,
    Color? glassBorder,
    Color? glassShadow,
    Color? scrimSoft,
    Color? scrimMedium,
    Color? scrimStrong,
    Color? dividerSoft,
  }) {
    return AppTokens(
      surfaceBase: surfaceBase ?? this.surfaceBase,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      surfaceCardAlt: surfaceCardAlt ?? this.surfaceCardAlt,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textOnAccent: textOnAccent ?? this.textOnAccent,
      accentGold: accentGold ?? this.accentGold,
      accentGoldDeep: accentGoldDeep ?? this.accentGoldDeep,
      accentGoldLight: accentGoldLight ?? this.accentGoldLight,
      accentViolet: accentViolet ?? this.accentViolet,
      accentVioletText: accentVioletText ?? this.accentVioletText,
      accentVioletSurface: accentVioletSurface ?? this.accentVioletSurface,
      accentCoral: accentCoral ?? this.accentCoral,
      goldRowGradient: goldRowGradient ?? this.goldRowGradient,
      goldGrad: goldGrad ?? this.goldGrad,
      shimmerBase: shimmerBase ?? this.shimmerBase,
      shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
      glassFill: glassFill ?? this.glassFill,
      glassBorder: glassBorder ?? this.glassBorder,
      glassShadow: glassShadow ?? this.glassShadow,
      scrimSoft: scrimSoft ?? this.scrimSoft,
      scrimMedium: scrimMedium ?? this.scrimMedium,
      scrimStrong: scrimStrong ?? this.scrimStrong,
      dividerSoft: dividerSoft ?? this.dividerSoft,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      surfaceBase: Color.lerp(surfaceBase, other.surfaceBase, t)!,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t)!,
      surfaceCardAlt: Color.lerp(surfaceCardAlt, other.surfaceCardAlt, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textOnAccent: Color.lerp(textOnAccent, other.textOnAccent, t)!,
      accentGold: Color.lerp(accentGold, other.accentGold, t)!,
      accentGoldDeep: Color.lerp(accentGoldDeep, other.accentGoldDeep, t)!,
      accentGoldLight: Color.lerp(accentGoldLight, other.accentGoldLight, t)!,
      accentViolet: Color.lerp(accentViolet, other.accentViolet, t)!,
      accentVioletText: Color.lerp(accentVioletText, other.accentVioletText, t)!,
      accentVioletSurface:
          Color.lerp(accentVioletSurface, other.accentVioletSurface, t)!,
      accentCoral: Color.lerp(accentCoral, other.accentCoral, t)!,
      goldRowGradient: _lerpColors(goldRowGradient, other.goldRowGradient, t),
      goldGrad: _lerpColors(goldGrad, other.goldGrad, t),
      shimmerBase: Color.lerp(shimmerBase, other.shimmerBase, t)!,
      shimmerHighlight: Color.lerp(shimmerHighlight, other.shimmerHighlight, t)!,
      glassFill: Color.lerp(glassFill, other.glassFill, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      glassShadow: Color.lerp(glassShadow, other.glassShadow, t)!,
      scrimSoft: Color.lerp(scrimSoft, other.scrimSoft, t)!,
      scrimMedium: Color.lerp(scrimMedium, other.scrimMedium, t)!,
      scrimStrong: Color.lerp(scrimStrong, other.scrimStrong, t)!,
      dividerSoft: Color.lerp(dividerSoft, other.dividerSoft, t)!,
    );
  }

  static List<Color> _lerpColors(List<Color> a, List<Color> b, double t) {
    final n = a.length < b.length ? a.length : b.length;
    return [for (var i = 0; i < n; i++) Color.lerp(a[i], b[i], t)!];
  }
}

extension AppTokensX on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Quick dim helpers — black at [light] alpha in light mode,
  /// white at [dark] alpha in dark mode.
  Color dimW(double a) => Colors.white.withValues(alpha: a);
  Color dimB(double a) => Colors.black.withValues(alpha: a);
  Color dim(double light, double dark) => isDark ? dimW(dark) : dimB(light);
}
