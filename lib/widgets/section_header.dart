import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A consistent section title with an optional trailing action (e.g. a
/// "Manage" / "See all" text button). Replaces the ad-hoc bold `Text` +
/// `Row(Spacer, TextButton)` blocks scattered across screens.
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.icon,
    this.iconColor,
    this.actionLabel,
    this.onAction,
    this.padding = EdgeInsets.zero,
  });

  final String title;
  final IconData? icon;
  final Color? iconColor;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.colors;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: iconColor ?? c.brand),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}
