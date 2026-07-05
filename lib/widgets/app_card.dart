import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// The base surface for content across the app: a rounded, hairline-bordered
/// panel with an optional soft shadow. Replaces the dozens of hand-rolled
/// `Container(decoration: BoxDecoration(...))` cards.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
    this.color,
    this.borderColor,
    this.elevated = false,
    this.borderRadius = AppRadii.card,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;

  /// Adds a soft drop shadow for cards that should float above the surface.
  final bool elevated;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final decoration = BoxDecoration(
      color: color ?? c.surfaceElevated,
      borderRadius: borderRadius,
      border: Border.all(color: borderColor ?? c.cardBorder),
      boxShadow: elevated ? AppShadows.card(c) : null,
    );

    final content = Padding(padding: padding, child: child);

    if (onTap == null) {
      return DecoratedBox(decoration: decoration, child: content);
    }

    return Material(
      color: color ?? c.surfaceElevated,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border.all(color: borderColor ?? c.cardBorder),
            boxShadow: elevated ? AppShadows.card(c) : null,
          ),
          child: content,
        ),
      ),
    );
  }
}
