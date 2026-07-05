import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Assembles the light and dark [ThemeData] for Settlement.
///
/// Everything a screen would otherwise style by hand — app bars, cards, nav,
/// buttons, inputs, chips, dialogs, snackbars — is configured here once so the
/// UI stays consistent and screens can stop hardcoding colors.
abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light, AppColors.light);
  static ThemeData get dark => _build(Brightness.dark, AppColors.dark);

  static ThemeData _build(Brightness brightness, AppColors c) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F766E),
      brightness: brightness,
    ).copyWith(
      primary: c.brand,
      onPrimary: c.onBrand,
      secondary: c.accent,
      onSecondary: c.onAccent,
      error: c.negative,
      surface: c.surfaceElevated,
      surfaceContainerLowest: c.surface,
      surfaceContainerHighest: c.surfaceSunken,
      outline: c.cardBorder,
      outlineVariant: c.cardBorder,
      shadow: c.shadow,
    );

    final textTheme = AppTypography.textTheme(brightness);
    final onSurface = scheme.onSurface;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.surface,
      canvasColor: c.surface,
      textTheme: textTheme.apply(
        bodyColor: onSurface,
        displayColor: onSurface,
      ),
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      extensions: [c],

      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: onSurface),
        iconTheme: IconThemeData(color: onSurface),
      ),

      cardTheme: CardThemeData(
        color: c.surfaceElevated,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.card,
          side: BorderSide(color: c.cardBorder),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surfaceElevated,
        elevation: 0,
        height: 68,
        indicatorColor: c.brandSoft,
        surfaceTintColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color:
                states.contains(WidgetState.selected) ? c.brand : c.faint,
            size: 24,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelSmall!.copyWith(
            color: states.contains(WidgetState.selected) ? c.brand : c.faint,
            fontSize: 11,
          ),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.brand,
        foregroundColor: c.onBrand,
        elevation: 3,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.brand,
          foregroundColor: c.onBrand,
          elevation: 0,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
          shape: RoundedRectangleBorder(borderRadius: AppRadii.field),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.brand,
          foregroundColor: c.onBrand,
          minimumSize: const Size(0, 52),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
          shape: RoundedRectangleBorder(borderRadius: AppRadii.field),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.brand,
          minimumSize: const Size(0, 52),
          side: BorderSide(color: c.cardBorder),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
          shape: RoundedRectangleBorder(borderRadius: AppRadii.field),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.brand,
          textStyle: textTheme.labelLarge,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceSunken,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: c.faint),
        labelStyle: textTheme.bodyMedium?.copyWith(color: c.muted),
        prefixIconColor: c.faint,
        suffixIconColor: c.faint,
        border: OutlineInputBorder(
          borderRadius: AppRadii.field,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.field,
          borderSide: BorderSide(color: c.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.field,
          borderSide: BorderSide(color: c.brand, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadii.field,
          borderSide: BorderSide(color: c.negative),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadii.field,
          borderSide: BorderSide(color: c.negative, width: 1.6),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceSunken,
        selectedColor: c.brandSoft,
        side: BorderSide(color: c.cardBorder),
        labelStyle: textTheme.labelMedium!.copyWith(color: onSurface),
        secondaryLabelStyle: textTheme.labelMedium!.copyWith(color: c.brand),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.chip),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: c.surfaceElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.xl)),
        titleTextStyle: textTheme.titleLarge?.copyWith(color: onSurface),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: c.muted),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheet),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: brightness == Brightness.dark
            ? c.surfaceSunken
            : const Color(0xFF1F2733),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        actionTextColor: c.brand,
        insetPadding: const EdgeInsets.all(AppSpacing.md),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.field),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: c.brand,
        unselectedLabelColor: c.faint,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: c.brand, width: 2.5),
          insets: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: c.cardBorder,
        thickness: 1,
        space: 1,
      ),

      listTileTheme: ListTileThemeData(
        iconColor: c.muted,
        textColor: onSurface,
        titleTextStyle: textTheme.titleSmall?.copyWith(color: onSurface),
        subtitleTextStyle: textTheme.bodySmall?.copyWith(color: c.muted),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.brand : c.faint,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? c.brandSoft
              : c.surfaceSunken,
        ),
        trackOutlineColor: WidgetStateProperty.all(c.cardBorder),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.brand),

      popupMenuTheme: PopupMenuThemeData(
        color: c.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: BorderSide(color: c.cardBorder),
        ),
        textStyle: textTheme.bodyMedium?.copyWith(color: onSurface),
      ),

      iconTheme: IconThemeData(color: c.muted),
    );
  }
}
