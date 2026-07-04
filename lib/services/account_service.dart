import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/account_model.dart';

/// Manages the user's payment accounts (cash, bank, credit card, wallet) and
/// the transfers between them. Account balances are stored on each account
/// document and adjusted atomically via [FieldValue.increment] whenever money
/// moves, so concurrent writes (e.g. an expense and a transfer) never clobber
/// each other's balance changes.
class AccountService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<AccountModel> _accounts = [];
  List<AccountModel> get accounts => _accounts;

  List<TransferModel> _transfers = [];
  List<TransferModel> get transfers => _transfers;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Clears cached data (e.g. on sign-out).
  void reset() {
    _accounts = [];
    _transfers = [];
    notifyListeners();
  }

  Future<void> loadUserAccounts() async {
    if (_auth.currentUser == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      final query =
          await _firestore
              .collection('accounts')
              .where('userId', isEqualTo: _auth.currentUser!.uid)
              .orderBy('createdAt', descending: false)
              .get();

      _accounts =
          query.docs.map((doc) => AccountModel.fromMap(doc.data())).toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Error loading accounts: $e');
    }
  }

  Future<void> addAccount({
    required String name,
    required AccountType type,
    required double openingBalance,
  }) async {
    if (_auth.currentUser == null) return;

    final account = AccountModel(
      id: const Uuid().v4(),
      userId: _auth.currentUser!.uid,
      name: name,
      type: type,
      balance: openingBalance,
      createdAt: DateTime.now(),
    );

    try {
      await _firestore
          .collection('accounts')
          .doc(account.id)
          .set(account.toMap());
      _accounts.add(account);
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding account: $e');
      rethrow;
    }
  }

  Future<void> updateAccount(AccountModel account) async {
    try {
      await _firestore
          .collection('accounts')
          .doc(account.id)
          .update(account.toMap());
      final index = _accounts.indexWhere((a) => a.id == account.id);
      if (index != -1) {
        _accounts[index] = account;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating account: $e');
      rethrow;
    }
  }

  Future<void> deleteAccount(String accountId) async {
    try {
      await _firestore.collection('accounts').doc(accountId).delete();
      _accounts.removeWhere((a) => a.id == accountId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting account: $e');
      rethrow;
    }
  }

  /// Adjusts an account's balance by [delta] (negative for spending, positive
  /// for income/refund). Used by [ExpenseService] when expenses that reference
  /// an account are created, edited, or removed. No-ops for an unknown id.
  Future<void> adjustBalance(String accountId, double delta) async {
    if (delta == 0) return;
    final index = _accounts.indexWhere((a) => a.id == accountId);
    if (index == -1) return;

    try {
      await _firestore.collection('accounts').doc(accountId).update({
        'balance': FieldValue.increment(delta),
      });
      _accounts[index] = _accounts[index].copyWith(
        balance: _accounts[index].balance + delta,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error adjusting account balance: $e');
      rethrow;
    }
  }

  /// Moves [amount] from one account to another. Records a [TransferModel] for
  /// history and decrements/increments the two balances. Transfers do not count
  /// as expenses.
  Future<void> transfer({
    required String fromAccountId,
    required String toAccountId,
    required double amount,
    String note = '',
  }) async {
    if (_auth.currentUser == null) return;
    if (fromAccountId == toAccountId) {
      throw Exception('Choose two different accounts.');
    }
    if (amount <= 0) {
      throw Exception('Enter a valid amount.');
    }

    final transferRecord = TransferModel(
      id: const Uuid().v4(),
      userId: _auth.currentUser!.uid,
      fromAccountId: fromAccountId,
      toAccountId: toAccountId,
      amount: amount,
      note: note,
      createdAt: DateTime.now(),
    );

    try {
      await _firestore
          .collection('transfers')
          .doc(transferRecord.id)
          .set(transferRecord.toMap());
      await adjustBalance(fromAccountId, -amount);
      await adjustBalance(toAccountId, amount);
      _transfers.insert(0, transferRecord);
      notifyListeners();
    } catch (e) {
      debugPrint('Error transferring: $e');
      rethrow;
    }
  }

  AccountModel? getAccountById(String? accountId) {
    if (accountId == null) return null;
    final index = _accounts.indexWhere((a) => a.id == accountId);
    return index == -1 ? null : _accounts[index];
  }

  /// Net worth: the sum of all account balances.
  double getTotalBalance() {
    return _accounts.fold(0.0, (acc, a) => acc + a.balance);
  }

  bool get hasAccounts => _accounts.isNotEmpty;
}
