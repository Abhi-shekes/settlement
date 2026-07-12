import 'dart:io' show Platform;
// Hide foundation's `Category` annotation so our category model's `Category`
// (used below for the top-spending grouping) is unambiguous.
import 'package:flutter/foundation.dart' hide Category;
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import '../models/category_model.dart';
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
    'OverviewWidget',
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
      final Map<Category, double> byCategory = {};
      for (final e in monthExpenses) {
        byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
      }
      String topLine = 'No spending yet';
      if (byCategory.isNotEmpty) {
        final top = byCategory.entries
            .where((e) => e.value > 0)
            .fold<MapEntry<Category, double>?>(
              null,
              (best, e) => best == null || e.value > best.value ? e : best,
            );
        if (top != null) {
          topLine =
              'Top: ${top.key.categoryDisplayName} · ${_rupees(top.value)}';
        }
      }

      // Month-over-month trend: compare this month's spend with last month's.
      final prevStart = DateTime(now.year, now.month - 1, 1);
      final prevTotal = expenses
          .getExpensesByDateRange(prevStart, start)
          .fold<double>(0, (sum, e) => sum + e.amount);
      String monthDelta = '';
      if (prevTotal > 0) {
        final change = ((monthTotal - prevTotal) / prevTotal * 100).round();
        if (change != 0) {
          final arrow = change > 0 ? '▲' : '▼';
          monthDelta = '$arrow ${change.abs()}% vs last month';
        }
      }

      // Net worth across accounts, plus the single largest-balance account.
      final netWorth = accounts.getTotalBalance();
      final count = accounts.accounts.length;
      final accountsSub =
          count == 0
              ? 'No accounts yet'
              : 'Across $count account${count == 1 ? '' : 's'}';
      String accountTop = '';
      if (accounts.accounts.isNotEmpty) {
        final top = accounts.accounts.reduce(
          (a, b) => a.balance >= b.balance ? a : b,
        );
        accountTop = 'Top: ${top.name} · ${_rupees(top.balance)}';
      }

      // Budget progress — structured, month-to-date. Each row carries a label,
      // "spent / limit", a percentage (for the native progress bar) and a state
      // (ok / warn / over) that colors the bar. `budget_body` is kept as a
      // legacy fallback for any old widget instance still bound to it.
      final validBudgets = budgets.budgets.where((b) => b.amount > 0).toList();
      final legacyLines = <String>[];
      final data = <String, String>{
        'month_label': DateFormat('MMMM y').format(now),
        'month_spend': _rupees(monthTotal),
        'month_delta': monthDelta,
        'month_top': topLine,
        'net_worth': _rupees(netWorth),
        'accounts_sub': accountsSub,
        'account_top': accountTop,
        'budget_count': validBudgets.length.toString(),
        'updated': 'Updated ${DateFormat('h:mm a').format(now)}',
      };
      for (var i = 0; i < validBudgets.length && i < 4; i++) {
        final b = validBudgets[i];
        final spent = byCategory[b.category] ?? 0;
        final pct = ((spent / b.amount) * 100).clamp(0, 999).round();
        final state = pct >= 100 ? 'over' : (pct >= 80 ? 'warn' : 'ok');
        data['budget_${i}_label'] = b.category.categoryDisplayName;
        data['budget_${i}_amount'] = '${_rupees(spent)} / ${_rupees(b.amount)}';
        data['budget_${i}_pct'] = pct.toString();
        data['budget_${i}_state'] = state;
        legacyLines.add(
          '${b.category.categoryDisplayName}  '
          '${_rupees(spent)} / ${_rupees(b.amount)}  ($pct%)',
        );
      }
      data['budget_body'] =
          legacyLines.isEmpty ? 'No budgets set' : legacyLines.join('\n');

      await Future.wait(
        data.entries.map(
          (e) => HomeWidget.saveWidgetData<String>(e.key, e.value),
        ),
      );

      for (final provider in _providers) {
        await HomeWidget.updateWidget(qualifiedAndroidName: '$_pkg.$provider');
      }
    } catch (e) {
      debugPrint('HomeWidget update failed: $e');
    }
  }
}
