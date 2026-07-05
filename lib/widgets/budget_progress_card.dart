import 'package:flutter/material.dart';
import '../models/expense_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/category_style.dart';
import 'app_chip.dart';
import 'money_text.dart';

class BudgetProgressCard extends StatelessWidget {
  final ExpenseCategory category;
  final double budgetAmount;
  final double currentSpending;
  final VoidCallback onTap;

  const BudgetProgressCard({
    super.key,
    required this.category,
    required this.budgetAmount,
    required this.currentSpending,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.colors;

    double usage = 0;
    if (budgetAmount > 0) {
      usage = (currentSpending / budgetAmount).clamp(0, 1);
    }

    final exceeded = budgetAmount > 0 && currentSpending > budgetAmount;
    final nearLimit = budgetAmount > 0 &&
        currentSpending >= budgetAmount * 0.8 &&
        currentSpending <= budgetAmount;

    final Color progressColor = exceeded
        ? c.negative
        : nearLimit
            ? c.warning
            : c.brand;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: AppRadii.card,
        border: Border.all(color: c.cardBorder),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.card,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: category.color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                      ),
                      child: Icon(category.icon, color: category.color, size: 20),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        category.categoryDisplayName,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    if (exceeded)
                      AppChip(label: 'Exceeded', color: c.negative, dense: true)
                    else if (nearLimit)
                      AppChip(label: 'Near limit', color: c.warning, dense: true),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _stat(context, 'Spent', currentSpending, progressColor),
                    _stat(
                      context,
                      'Budget',
                      budgetAmount,
                      theme.colorScheme.onSurface,
                      alignEnd: true,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: usage,
                    backgroundColor: c.surfaceSunken,
                    color: progressColor,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${(usage * 100).toInt()}% used',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: progressColor,
                      ),
                    ),
                    if (budgetAmount > 0)
                      Text(
                        exceeded
                            ? 'Over by ₹${(currentSpending - budgetAmount).toInt()}'
                            : '₹${(budgetAmount - currentSpending).toInt()} left',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: exceeded ? c.negative : c.positive,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(
    BuildContext context,
    String label,
    double amount,
    Color color, {
    bool alignEnd = false,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: context.colors.muted,
          ),
        ),
        const SizedBox(height: 2),
        MoneyText(amount, size: 16, color: color),
      ],
    );
  }
}
