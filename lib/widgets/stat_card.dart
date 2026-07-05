import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'money_text.dart';

/// A compact metric tile: an icon well, a label, and a value. Used in the
/// dashboard financial-overview grid and anywhere a KPI needs showing.
/// Replaces the per-screen `_buildBalanceCard` helpers.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.icon,
    required this.accent,
    this.amount,
    this.valueText,
    this.trailing,
    this.onTap,
    this.compactMoney = true,
  });

  final String label;
  final IconData icon;

  /// The tile's accent color (icon well + value tint).
  final Color accent;

  /// Provide either a monetary [amount] (rendered via MoneyText) …
  final double? amount;

  /// … or a plain [valueText] for non-money stats.
  final String? valueText;

  final Widget? trailing;
  final VoidCallback? onTap;
  final bool compactMoney;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.colors;

    final content = Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: AppRadii.card,
        border: Border.all(color: c.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          if (amount != null)
            MoneyText(amount!, size: 20, color: accent, compact: compactMoney)
          else
            Text(
              valueText ?? '',
              style: theme.textTheme.titleLarge?.copyWith(color: accent),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );

    if (onTap == null) return content;
    return InkWell(onTap: onTap, borderRadius: AppRadii.card, child: content);
  }
}
