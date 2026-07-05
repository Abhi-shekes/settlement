import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A small pill for tags, categories, and status labels — filled with a soft
/// tint of [color]. Use [AppChip.selectable] wiring via [selected]/[onTap] for
/// filter rows.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.selected = false,
    this.onTap,
    this.dense = false,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final bool selected;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.colors;
    final tint = color ?? c.brand;
    final bg = selected ? tint.withValues(alpha: 0.16) : c.surfaceSunken;
    final fg = selected ? tint : c.muted;
    final borderColor = selected ? tint.withValues(alpha: 0.4) : c.cardBorder;

    final chip = Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 12,
        vertical: dense ? 4 : 7,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 13 : 15, color: fg),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: (dense ? theme.textTheme.labelSmall : theme.textTheme.labelMedium)
                ?.copyWith(color: fg, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );

    if (onTap == null) return chip;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: chip,
    );
  }
}
