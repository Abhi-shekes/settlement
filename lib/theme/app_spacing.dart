import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Spacing rhythm — a 4pt base scale used for padding, gaps, and margins.
/// Prefer these over magic numbers so vertical/horizontal rhythm stays even.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Standard screen edge padding.
  static const EdgeInsets screen = EdgeInsets.all(md);
  static const EdgeInsets screenH = EdgeInsets.symmetric(horizontal: md);
}

/// Corner radii. Cards, sheets, and pills each have a fixed value so the app
/// reads as one system rather than a grab-bag of rounded rectangles.
abstract final class AppRadii {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double pill = 999;

  static const BorderRadius card = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius chip = BorderRadius.all(Radius.circular(pill));
  static const BorderRadius sheet = BorderRadius.vertical(
    top: Radius.circular(xl),
  );
  static const BorderRadius field = BorderRadius.all(Radius.circular(md));
}

/// Elevation as soft, low-spread shadows keyed off the theme's shadow token.
abstract final class AppShadows {
  static List<BoxShadow> card(AppColors c) => [
    BoxShadow(color: c.shadow, blurRadius: 18, offset: const Offset(0, 8)),
  ];

  static List<BoxShadow> soft(AppColors c) => [
    BoxShadow(color: c.shadow, blurRadius: 10, offset: const Offset(0, 4)),
  ];

  static List<BoxShadow> glow(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.28),
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
  ];
}

/// Standard entrance-animation timings so motion feels consistent app-wide.
abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 520);
  static const Duration stagger = Duration(milliseconds: 60);
}
