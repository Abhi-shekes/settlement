import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import '../models/expense_model.dart';
import 'expense_service.dart';
import 'account_service.dart';
import 'budget_service.dart';

/// Pushes a compact snapshot of the user's finances to the Android home-screen
/// widgets (Quick Add, This Month, Net Worth, Budgets). The native widget
/// providers read these keys from shared preferences via the home_widget
/// plugin. No-op on non-Android platforms.
class HomeWidgetService {
  static const _pkg = 'com.example.settlement';
  static const _providers = [
    'MonthSpendWidget',
    'NetWorthWidget',
    'BudgetWidget',
    'QuickAddWidget',
  ];

  static final NumberFormat _inr = NumberFormat.decimalPattern('en_IN');

  static bool get _supported {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  static String _rupees(num value) {
    final rounded = value.round();
    final sign = rounded < 0 ? '-' : '';
    return '$sign₹${_inr.format(rounded.abs())}';
  }

  /// Recomputes the widget snapshot from the current service state and pushes
  /// it to every home-screen widget. Safe to call often; cheap and guarded.
  static Future<void> update({
    required ExpenseService expenses,
    required AccountService accounts,
    required BudgetService budgets,
  }) async {
    if (!_supported) return;

    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, 1);
      final end = DateTime(now.year, now.month + 1, 1);
      final monthExpenses = expenses.getExpensesByDateRange(start, end);

      // Month total (refunds carry negative amounts and net out automatically).
      final monthTotal = monthExpenses.fold<double>(
        0,
        (sum, e) => sum + e.amount,
      );

      // Per-category month totals → top spending category.
      final Map<ExpenseCategory, double> byCategory = {};
      for (final e in monthExpenses) {
        byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
      }
      String topLine = 'No spending yet';
      if (byCategory.isNotEmpty) {
        final top = byCategory.entries
            .where((e) => e.value > 0)
            .fold<MapEntry<ExpenseCategory, double>?>(
              null,
              (best, e) => best == null || e.value > best.value ? e : best,
            );
        if (top != null) {
          topLine =
              'Top: ${top.key.categoryDisplayName} · ${_rupees(top.value)}';
        }
      }

      // Net worth across accounts.
      final netWorth = accounts.getTotalBalance();
      final count = accounts.accounts.length;
      final accountsSub =
          count == 0
              ? 'No accounts yet'
              : 'Across $count account${count == 1 ? '' : 's'}';

      // Budget progress (up to 3 category budgets, month-to-date).
      final budgetLines = <String>[];
      for (final b in budgets.budgets) {
        if (b.amount <= 0) continue;
        final spent = byCategory[b.category] ?? 0;
        final pct = ((spent / b.amount) * 100).clamp(0, 999).round();
        budgetLines.add(
          '${b.category.categoryDisplayName}  '
          '${_rupees(spent)} / ${_rupees(b.amount)}  ($pct%)',
        );
        if (budgetLines.length == 3) break;
      }
      final budgetBody =
          budgetLines.isEmpty ? 'No budgets set' : budgetLines.join('\n');

      await Future.wait([
        HomeWidget.saveWidgetData<String>(
          'month_label',
          DateFormat('MMMM y').format(now),
        ),
        HomeWidget.saveWidgetData<String>('month_spend', _rupees(monthTotal)),
        HomeWidget.saveWidgetData<String>('month_top', topLine),
        HomeWidget.saveWidgetData<String>('net_worth', _rupees(netWorth)),
        HomeWidget.saveWidgetData<String>('accounts_sub', accountsSub),
        HomeWidget.saveWidgetData<String>('budget_body', budgetBody),
        HomeWidget.saveWidgetData<String>(
          'updated',
          'Updated ${DateFormat('h:mm a').format(now)}',
        ),
      ]);

      for (final provider in _providers) {
        await HomeWidget.updateWidget(qualifiedAndroidName: '$_pkg.$provider');
      }
    } catch (e) {
      debugPrint('HomeWidget update failed: $e');
    }
  }
}
