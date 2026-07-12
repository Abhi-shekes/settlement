import 'package:flutter/material.dart';
import 'expense_model.dart';
import '../utils/category_style.dart';

/// A spending category — either one of the fixed built-ins (Food, Travel, …) or
/// a user-defined custom category. This is the universal type used across
/// expenses, budgets, recurring rules and analytics.
///
/// Categories are identified by a stable string [id]:
/// - Built-ins keep the original enum string (e.g. `"ExpenseCategory.food"`),
///   so every expense/budget written before custom categories existed keeps
///   resolving correctly — no data migration needed.
/// - Custom categories get a UUID assigned when created.
///
/// Only the [id] is persisted on an expense/budget; the name, icon and colour
/// live in one place (the built-in table, or the custom category's own Firestore
/// document) and are resolved through [CategoryRegistry]. Equality is by [id]
/// so a `Category` works as a dropdown value and in `==` comparisons.
@immutable
class Category {
  final String id;
  final String name;

  /// Stored as an int so custom categories round-trip through Firestore. Always
  /// one of [kCategoryIconPalette] (or a built-in icon) so the concrete const
  /// `IconData` stays referenced and survives icon tree-shaking in release
  /// builds — see [icon].
  final int iconCodePoint;
  final int colorValue;
  final bool isBuiltIn;

  /// Owner of a custom category; null for built-ins.
  final String? userId;

  const Category({
    required this.id,
    required this.name,
    required this.iconCodePoint,
    required this.colorValue,
    required this.isBuiltIn,
    this.userId,
  });

  bool get isCustom => !isBuiltIn;

  /// Kept so existing call sites that read `category.categoryDisplayName`
  /// (the old enum member) keep working unchanged.
  String get categoryDisplayName => name;

  /// Resolves the code point back to a concrete const [IconData]. Reconstructing
  /// `IconData(codePoint, …)` at runtime would be shaken out of release builds,
  /// so we look the glyph up among the const icons we actually ship (built-ins
  /// plus [kCategoryIconPalette]) and fall back to a category glyph.
  IconData get icon => _iconByCodePoint(iconCodePoint);

  Color get color => Color(colorValue);

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] ?? '',
      name: map['name'] ?? 'Category',
      iconCodePoint:
          (map['iconCodePoint'] as num?)?.toInt() ??
          Icons.category_rounded.codePoint,
      colorValue: (map['colorValue'] as num?)?.toInt() ?? 0xFF64748B,
      isBuiltIn: false,
      userId: map['userId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
      'userId': userId,
    };
  }

  Category copyWith({String? name, int? iconCodePoint, int? colorValue}) {
    return Category(
      id: id,
      name: name ?? this.name,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      isBuiltIn: isBuiltIn,
      userId: userId,
    );
  }

  @override
  bool operator ==(Object other) => other is Category && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// The fixed built-in categories, derived from the original [ExpenseCategory]
/// enum plus its curated icon/colour (see `category_style.dart`) so there is
/// still a single source of truth for how a built-in looks. Their ids are the
/// enum's `toString()` for backward compatibility with stored data.
final List<Category> kBuiltInCategories = ExpenseCategory.values
    .map(
      (e) => Category(
        id: e.toString(),
        name: e.categoryDisplayName,
        iconCodePoint: e.icon.codePoint,
        colorValue: e.color.toARGB32(),
        isBuiltIn: true,
      ),
    )
    .toList(growable: false);

/// Convenience default (used where a category must be pre-selected).
final Category kDefaultCategory = kBuiltInCategories.firstWhere(
  (c) => c.id == ExpenseCategory.food.toString(),
);

/// Default category for recurring rules (rent/bills/subscriptions).
final Category kUtilitiesCategory = kBuiltInCategories.firstWhere(
  (c) => c.id == ExpenseCategory.utilities.toString(),
);

/// The neutral fallback category.
final Category kOtherCategory = kBuiltInCategories.firstWhere(
  (c) => c.id == ExpenseCategory.other.toString(),
);

/// The set of icons a user may pick for a custom category. Kept as const
/// `IconData` so every glyph survives release tree-shaking. Built-in icons are
/// added so stored built-in code points also resolve here.
const List<IconData> kCategoryIconPalette = [
  Icons.category_rounded,
  Icons.restaurant_rounded,
  Icons.directions_car_rounded,
  Icons.shopping_bag_rounded,
  Icons.movie_rounded,
  Icons.bolt_rounded,
  Icons.favorite_rounded,
  Icons.school_rounded,
  Icons.pets_rounded,
  Icons.fitness_center_rounded,
  Icons.flight_rounded,
  Icons.home_rounded,
  Icons.card_giftcard_rounded,
  Icons.local_cafe_rounded,
  Icons.sports_esports_rounded,
  Icons.spa_rounded,
  Icons.child_care_rounded,
  Icons.build_rounded,
  Icons.savings_rounded,
  Icons.phone_iphone_rounded,
];

/// The colours a user may pick for a custom category (also used to tint them).
const List<int> kCategoryColorPalette = [
  0xFFF97316, // orange
  0xFF3B82F6, // blue
  0xFF8B5CF6, // violet
  0xFFEC4899, // pink
  0xFFF59E0B, // amber
  0xFF10B981, // emerald
  0xFF6366F1, // indigo
  0xFF64748B, // slate
  0xFFEF4444, // red
  0xFF14B8A6, // teal
  0xFF84CC16, // lime
  0xFF06B6D4, // cyan
];

/// Builds dropdown items (icon + name) for a category picker, shared by the
/// add/edit expense, group expense and recurring screens so custom categories
/// appear everywhere consistently.
List<DropdownMenuItem<Category>> categoryDropdownItems(
  List<Category> categories,
) {
  return [
    for (final category in categories)
      DropdownMenuItem<Category>(
        value: category,
        child: Row(
          children: [
            Icon(category.icon, size: 18, color: category.color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                category.categoryDisplayName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
  ];
}

IconData _iconByCodePoint(int codePoint) {
  for (final icon in kCategoryIconPalette) {
    if (icon.codePoint == codePoint) return icon;
  }
  for (final c in kBuiltInCategories) {
    if (c.iconCodePoint == codePoint) {
      // Built-in code points map onto their palette-equivalent glyph above; if
      // a built-in uses an icon not in the palette we still resolve it here via
      // the enum's const icon.
      return ExpenseCategory.values
          .firstWhere((e) => e.icon.codePoint == codePoint)
          .icon;
    }
  }
  return Icons.category_rounded;
}

/// Global, always-available resolver from a stored category id to its
/// [Category]. Model getters (e.g. `ExpenseModel.category`) resolve through
/// this, so they cannot reach the Provider tree. [CategoryService] keeps the
/// custom set in sync here whenever it loads or changes; built-ins are constant.
///
/// Resolving lazily (on every read) rather than capturing a `Category` at load
/// time means a newly created custom category is reflected immediately, without
/// reloading already-loaded expenses.
class CategoryRegistry {
  CategoryRegistry._();
  static final CategoryRegistry instance = CategoryRegistry._();

  List<Category> _custom = const [];

  List<Category> get builtIns => kBuiltInCategories;
  List<Category> get custom => _custom;
  List<Category> get all => [...kBuiltInCategories, ..._custom];

  void setCustom(List<Category> categories) {
    _custom = List.unmodifiable(categories);
  }

  void clear() => _custom = const [];

  /// Resolves [id] to a [Category], falling back to a neutral placeholder for a
  /// custom category that has since been deleted (so old expenses still render).
  Category byId(String id) {
    for (final c in kBuiltInCategories) {
      if (c.id == id) return c;
    }
    for (final c in _custom) {
      if (c.id == id) return c;
    }
    return Category(
      id: id,
      name: 'Category',
      iconCodePoint: Icons.category_rounded.codePoint,
      colorValue: 0xFF64748B,
      isBuiltIn: false,
    );
  }
}
