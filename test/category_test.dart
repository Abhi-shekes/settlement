import 'package:flutter_test/flutter_test.dart';
import 'package:settlement/models/category_model.dart';
import 'package:settlement/models/expense_model.dart';

void main() {
  group('built-in categories', () {
    test(
      'there is one per ExpenseCategory, with the enum string as its id',
      () {
        expect(kBuiltInCategories.length, ExpenseCategory.values.length);
        for (final e in ExpenseCategory.values) {
          final match = kBuiltInCategories.where((c) => c.id == e.toString());
          expect(match.length, 1, reason: 'missing built-in for $e');
          expect(match.first.name, e.categoryDisplayName);
          expect(match.first.isBuiltIn, isTrue);
        }
      },
    );
  });

  group('CategoryRegistry', () {
    setUp(() => CategoryRegistry.instance.clear());

    test('resolves built-ins by their enum string id (back-compat)', () {
      final food = CategoryRegistry.instance.byId(
        ExpenseCategory.food.toString(),
      );
      expect(food.name, 'Food');
      expect(food.isBuiltIn, isTrue);
    });

    test('resolves a custom category once registered', () {
      const custom = Category(
        id: 'custom-1',
        name: 'Pets',
        iconCodePoint: 0xe4a1,
        colorValue: 0xFF10B981,
        isBuiltIn: false,
        userId: 'u1',
      );
      CategoryRegistry.instance.setCustom([custom]);

      final resolved = CategoryRegistry.instance.byId('custom-1');
      expect(resolved.name, 'Pets');
      expect(resolved.isCustom, isTrue);
      expect(CategoryRegistry.instance.all, contains(custom));
    });

    test('falls back to a neutral placeholder for an unknown id', () {
      final unknown = CategoryRegistry.instance.byId('deleted-xyz');
      expect(unknown.id, 'deleted-xyz');
      expect(unknown.name, 'Category');
    });
  });

  group('ExpenseModel category round-trip', () {
    test('reads the legacy "category" enum string into categoryId', () {
      final e = ExpenseModel.fromMap({
        'id': 'e1',
        'userId': 'u1',
        'title': 'Lunch',
        'amount': 250,
        'category': 'ExpenseCategory.food',
        'createdAt': 0,
      });
      expect(e.categoryId, 'ExpenseCategory.food');
      expect(e.category.name, 'Food');
    });

    test('persists the category id under the "category" key', () {
      final e = ExpenseModel(
        id: 'e2',
        userId: 'u1',
        title: 'Vet',
        description: '',
        amount: 900,
        categoryId: 'custom-42',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      );
      expect(e.toMap()['category'], 'custom-42');
    });

    test('missing category defaults to other', () {
      final e = ExpenseModel.fromMap({
        'id': 'e3',
        'userId': 'u1',
        'title': 'Misc',
        'amount': 10,
        'createdAt': 0,
      });
      expect(e.categoryId, ExpenseCategory.other.toString());
    });
  });
}
