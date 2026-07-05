import 'package:flutter/material.dart';
import '../models/expense_model.dart';

/// Single source of truth for how each expense category looks — icon + a
/// distinct, curated hue. Previously this switch was copy-pasted into five
/// screens (`_getCategoryColor` / `_getCategoryIcon`); they should all call
/// these instead so a category always reads the same way across the app.
extension CategoryStyle on ExpenseCategory {
  IconData get icon {
    switch (this) {
      case ExpenseCategory.food:
        return Icons.restaurant_rounded;
      case ExpenseCategory.travel:
        return Icons.directions_car_rounded;
      case ExpenseCategory.shopping:
        return Icons.shopping_bag_rounded;
      case ExpenseCategory.entertainment:
        return Icons.movie_rounded;
      case ExpenseCategory.utilities:
        return Icons.bolt_rounded;
      case ExpenseCategory.healthcare:
        return Icons.favorite_rounded;
      case ExpenseCategory.education:
        return Icons.school_rounded;
      case ExpenseCategory.other:
        return Icons.category_rounded;
    }
  }

  /// Category accent hue. These are intentionally distinct colors (categories
  /// need to be told apart at a glance) but tuned to sit well on both light
  /// and dark surfaces.
  Color get color {
    switch (this) {
      case ExpenseCategory.food:
        return const Color(0xFFF97316); // orange
      case ExpenseCategory.travel:
        return const Color(0xFF3B82F6); // blue
      case ExpenseCategory.shopping:
        return const Color(0xFF8B5CF6); // violet
      case ExpenseCategory.entertainment:
        return const Color(0xFFEC4899); // pink
      case ExpenseCategory.utilities:
        return const Color(0xFFF59E0B); // amber
      case ExpenseCategory.healthcare:
        return const Color(0xFF10B981); // emerald
      case ExpenseCategory.education:
        return const Color(0xFF6366F1); // indigo
      case ExpenseCategory.other:
        return const Color(0xFF64748B); // slate
    }
  }
}
