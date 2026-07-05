import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography for Settlement.
///
/// Two families, deliberately paired:
///  - **Sora** (display) — geometric, modern, confident; used with restraint
///    for screen titles, hero balances, and section headers.
///  - **Inter** (body/UI) — highly legible at small sizes and, crucially for a
///    money app, ships tabular figures so amounts align in columns.
abstract final class AppTypography {
  /// Tabular figures — the signature detail for all monetary values. Applied
  /// by [AppTypography.money] and the MoneyText widget.
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  static TextTheme textTheme(Brightness brightness) {
    final base =
        brightness == Brightness.dark
            ? ThemeData.dark().textTheme
            : ThemeData.light().textTheme;

    final display = GoogleFonts.soraTextTheme(base);
    final body = GoogleFonts.interTextTheme(base);

    return TextTheme(
      // Display / headline roles use Sora.
      displayLarge: display.displayLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
      ),
      displayMedium: display.displayMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
      ),
      displaySmall: display.displaySmall?.copyWith(fontWeight: FontWeight.w700),
      headlineLarge: display.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineMedium: display.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      headlineSmall: display.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      titleLarge: display.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      // Title small/medium + all body + labels use Inter.
      titleMedium: body.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: body.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: body.bodyLarge?.copyWith(height: 1.45),
      bodyMedium: body.bodyMedium?.copyWith(height: 1.45),
      bodySmall: body.bodySmall?.copyWith(height: 1.4),
      labelLarge: body.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      labelMedium: body.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      labelSmall: body.labelSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
    );
  }

  /// A Sora money style with tabular figures — use for prominent balances.
  static TextStyle money({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
  }) {
    return GoogleFonts.sora(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      fontFeatures: tabular,
      letterSpacing: -0.5,
    );
  }
}
