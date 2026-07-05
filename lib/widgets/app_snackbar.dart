import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Consistent, typed feedback messages. Replaces the ad-hoc `showSnackBar`
/// calls that each set their own color. Errors state what happened; success
/// confirms the action in the same words the button used.
abstract final class AppSnackbar {
  static void success(BuildContext context, String message) =>
      _show(context, message, Icons.check_circle_rounded, context.colors.positive);

  static void error(BuildContext context, String message) =>
      _show(context, message, Icons.error_rounded, context.colors.negative);

  static void info(BuildContext context, String message) =>
      _show(context, message, Icons.info_rounded, context.colors.brand);

  static void _show(
    BuildContext context,
    String message,
    IconData icon,
    Color accent,
  ) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: accent, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }
}
