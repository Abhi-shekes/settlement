import 'package:flutter/material.dart';

/// Semantic color tokens for the Settlement design system.
///
/// These live alongside the Material [ColorScheme] and carry meaning the
/// scheme can't express on its own — finance semantics (money owed vs. owed to
/// you), brand gradients, and the layered neutral surfaces used by cards.
///
/// Read them anywhere via `context.colors` (see the extension at the bottom of
/// this file) so light and dark resolve automatically.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.brand,
    required this.onBrand,
    required this.brandSoft,
    required this.onBrandSoft,
    required this.heroGradientStart,
    required this.heroGradientEnd,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.positive,
    required this.positiveSoft,
    required this.negative,
    required this.negativeSoft,
    required this.warning,
    required this.warningSoft,
    required this.info,
    required this.infoSoft,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceSunken,
    required this.cardBorder,
    required this.muted,
    required this.faint,
    required this.shadow,
  });

  /// Primary brand teal — identity, primary actions.
  final Color brand;
  final Color onBrand;

  /// Tinted brand background for chips, icon wells, soft emphasis.
  final Color brandSoft;
  final Color onBrandSoft;

  /// Endpoints for the signature brand gradient (hero cards).
  final Color heroGradientStart;
  final Color heroGradientEnd;

  /// Amber-coral secondary accent.
  final Color accent;
  final Color onAccent;
  final Color accentSoft;

  /// Money owed to you / income / under budget.
  final Color positive;
  final Color positiveSoft;

  /// Money you owe / over budget / destructive.
  final Color negative;
  final Color negativeSoft;

  /// Budget approaching limit.
  final Color warning;
  final Color warningSoft;

  /// Neutral informational accent.
  final Color info;
  final Color infoSoft;

  /// Base scaffold background.
  final Color surface;

  /// Raised surfaces (cards, sheets, nav bar).
  final Color surfaceElevated;

  /// Recessed wells (inputs, track backgrounds).
  final Color surfaceSunken;

  /// Hairline border around cards / dividers.
  final Color cardBorder;

  /// Secondary text.
  final Color muted;

  /// Tertiary text / disabled / faint icons.
  final Color faint;

  /// Ambient shadow color (already includes intended opacity).
  final Color shadow;

  static const AppColors light = AppColors(
    brand: Color(0xFF0F766E),
    onBrand: Color(0xFFFFFFFF),
    brandSoft: Color(0xFFD5EFEC),
    onBrandSoft: Color(0xFF0B534D),
    heroGradientStart: Color(0xFF0F766E),
    heroGradientEnd: Color(0xFF14B8A6),
    accent: Color(0xFFF97316),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFFFEAD6),
    positive: Color(0xFF16A34A),
    positiveSoft: Color(0xFFDCFCE7),
    negative: Color(0xFFE11D48),
    negativeSoft: Color(0xFFFFE4E9),
    warning: Color(0xFFD97706),
    warningSoft: Color(0xFFFEF0D5),
    info: Color(0xFF2563EB),
    infoSoft: Color(0xFFDCE7FF),
    surface: Color(0xFFF6F8FA),
    surfaceElevated: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFEEF1F5),
    cardBorder: Color(0xFFE6EAF0),
    muted: Color(0xFF5B6472),
    faint: Color(0xFF98A2B3),
    shadow: Color(0x140F172A),
  );

  static const AppColors dark = AppColors(
    brand: Color(0xFF2DD4BF),
    onBrand: Color(0xFF04201D),
    brandSoft: Color(0xFF124E48),
    onBrandSoft: Color(0xFF99F6E4),
    heroGradientStart: Color(0xFF0D9488),
    heroGradientEnd: Color(0xFF115E59),
    accent: Color(0xFFFB923C),
    onAccent: Color(0xFF2A1503),
    accentSoft: Color(0xFF4A2A12),
    positive: Color(0xFF4ADE80),
    positiveSoft: Color(0xFF10331F),
    negative: Color(0xFFFB7185),
    negativeSoft: Color(0xFF3D1621),
    warning: Color(0xFFFBBF24),
    warningSoft: Color(0xFF3A2A0A),
    info: Color(0xFF60A5FA),
    infoSoft: Color(0xFF16233F),
    surface: Color(0xFF0B1220),
    surfaceElevated: Color(0xFF141C2B),
    surfaceSunken: Color(0xFF0A0F1A),
    cardBorder: Color(0xFF1F293B),
    muted: Color(0xFF9AA6B8),
    faint: Color(0xFF63708A),
    shadow: Color(0x40000000),
  );

  @override
  AppColors copyWith({
    Color? brand,
    Color? onBrand,
    Color? brandSoft,
    Color? onBrandSoft,
    Color? heroGradientStart,
    Color? heroGradientEnd,
    Color? accent,
    Color? onAccent,
    Color? accentSoft,
    Color? positive,
    Color? positiveSoft,
    Color? negative,
    Color? negativeSoft,
    Color? warning,
    Color? warningSoft,
    Color? info,
    Color? infoSoft,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceSunken,
    Color? cardBorder,
    Color? muted,
    Color? faint,
    Color? shadow,
  }) {
    return AppColors(
      brand: brand ?? this.brand,
      onBrand: onBrand ?? this.onBrand,
      brandSoft: brandSoft ?? this.brandSoft,
      onBrandSoft: onBrandSoft ?? this.onBrandSoft,
      heroGradientStart: heroGradientStart ?? this.heroGradientStart,
      heroGradientEnd: heroGradientEnd ?? this.heroGradientEnd,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      accentSoft: accentSoft ?? this.accentSoft,
      positive: positive ?? this.positive,
      positiveSoft: positiveSoft ?? this.positiveSoft,
      negative: negative ?? this.negative,
      negativeSoft: negativeSoft ?? this.negativeSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      info: info ?? this.info,
      infoSoft: infoSoft ?? this.infoSoft,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      cardBorder: cardBorder ?? this.cardBorder,
      muted: muted ?? this.muted,
      faint: faint ?? this.faint,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      brand: Color.lerp(brand, other.brand, t)!,
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
      brandSoft: Color.lerp(brandSoft, other.brandSoft, t)!,
      onBrandSoft: Color.lerp(onBrandSoft, other.onBrandSoft, t)!,
      heroGradientStart:
          Color.lerp(heroGradientStart, other.heroGradientStart, t)!,
      heroGradientEnd: Color.lerp(heroGradientEnd, other.heroGradientEnd, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      positive: Color.lerp(positive, other.positive, t)!,
      positiveSoft: Color.lerp(positiveSoft, other.positiveSoft, t)!,
      negative: Color.lerp(negative, other.negative, t)!,
      negativeSoft: Color.lerp(negativeSoft, other.negativeSoft, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoSoft: Color.lerp(infoSoft, other.infoSoft, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceSunken: Color.lerp(surfaceSunken, other.surfaceSunken, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      faint: Color.lerp(faint, other.faint, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

/// Ergonomic access: `context.colors.positive`, `context.colors.brand`, …
extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
