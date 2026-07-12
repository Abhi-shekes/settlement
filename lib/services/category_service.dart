import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/category_model.dart';

/// Owns the user's custom spending categories. Built-in categories are constant
/// (see [kBuiltInCategories]); custom ones live in the `categories` Firestore
/// collection scoped by `userId`.
///
/// Whenever the custom set changes this pushes it into [CategoryRegistry] so
/// model getters (e.g. `ExpenseModel.category`) resolve custom ids too, then
/// notifies listeners so category pickers and the budget list rebuild.
class CategoryService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Category> _custom = [];

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Built-ins first, then the user's custom categories.
  List<Category> get all => [...kBuiltInCategories, ..._custom];
  List<Category> get custom => List.unmodifiable(_custom);

  /// Resolves an id to a [Category] (delegates to the registry, which also
  /// covers built-ins and deleted-category fallback).
  Category byId(String id) => CategoryRegistry.instance.byId(id);

  void _publish() {
    CategoryRegistry.instance.setCustom(_custom);
    notifyListeners();
  }

  /// Clears cached data (e.g. on sign-out) so the next user never sees the
  /// previous user's categories.
  void reset() {
    _custom = [];
    CategoryRegistry.instance.clear();
    notifyListeners();
  }

  Future<void> loadUserCategories() async {
    if (_auth.currentUser == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      final query =
          await _firestore
              .collection('categories')
              .where('userId', isEqualTo: _auth.currentUser!.uid)
              .get();

      _custom =
          query.docs.map((doc) => Category.fromMap(doc.data())).toList()..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

      _isLoading = false;
      _publish();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Error loading categories: $e');
    }
  }

  /// Creates a custom category and returns it. Throws on failure.
  Future<Category> addCustomCategory({
    required String name,
    required int iconCodePoint,
    required int colorValue,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to add a category.');
    }

    final category = Category(
      id: const Uuid().v4(),
      name: name.trim(),
      iconCodePoint: iconCodePoint,
      colorValue: colorValue,
      isBuiltIn: false,
      userId: user.uid,
    );

    await _firestore
        .collection('categories')
        .doc(category.id)
        .set(category.toMap());

    _custom = [..._custom, category]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _publish();
    return category;
  }

  /// True when a custom category with this (case-insensitive) name already
  /// exists — used to keep names unique and avoid confusing duplicates.
  bool nameExists(String name) {
    final n = name.trim().toLowerCase();
    return all.any((c) => c.name.toLowerCase() == n);
  }

  Future<void> deleteCustomCategory(String id) async {
    try {
      await _firestore.collection('categories').doc(id).delete();
      _custom = _custom.where((c) => c.id != id).toList();
      _publish();
    } catch (e) {
      debugPrint('Error deleting category: $e');
      rethrow;
    }
  }
}
