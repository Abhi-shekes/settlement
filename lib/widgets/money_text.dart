import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/money.dart';

/// The app's signature money treatment: grouped ₹ formatting, tabular figures
/// (so digits never jitter and columns of amounts line up), and — when
/// [colored] is set — a sign-driven color (green for positive, red for owed).
///
/// Use this for every monetary value instead of `'₹${x.toInt()}'`.
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.amount, {
    super.key,
    this.size = 16,
    this.weight = FontWeight.w700,
    this.color,
    this.colored = false,
    this.signed = false,
    this.compact = false,
    this.decimals = false,
  });

  final double amount;
  final double size;
  final FontWeight weight;

  /// Explicit color override. Ignored when [colored] resolves a semantic color.
  final Color? color;

  /// Color by sign: positive → green, negative → red, zero → default.
  final bool colored;

  /// Prefix positive values with `+`.
  final bool signed;

  /// Abbreviate large values (`₹1.2L`).
  final bool compact;

  /// Show paise when the amount isn't whole.
  final bool decimals;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Color resolved;
    if (color != null) {
      resolved = color!;
    } else if (colored && amount > 0) {
      resolved = c.positive;
    } else if (colored && amount < 0) {
      resolved = c.negative;
    } else {
      resolved = Theme.of(context).colorScheme.onSurface;
    }

    return Text(
      formatCurrency(
        amount,
        compact: compact,
        signed: signed,
        decimals: decimals,
      ),
      style: AppTypography.money(
        fontSize: size,
        fontWeight: weight,
        color: resolved,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
