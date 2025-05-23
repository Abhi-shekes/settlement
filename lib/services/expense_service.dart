import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:expense_tracker/services/group_service.dart';
import 'package:expense_tracker/services/auth_service.dart';

class ExpenseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String userId = FirebaseAuth.instance.currentUser!.uid;
  final GroupService _groupService = GroupService();
  List<String> _settledPayments = [];
  final AuthService _authService = AuthService();

  Future<void> addExpense(Expense expense) async {
    try {
      await _firestore.collection('expenses').add(expense.toMap());
    } catch (e) {
      throw e;
    }
  }

  Future<Map<String, dynamic>> getOwedAmounts() async {
    try {
      final currentUserId = _authService.currentUser!.uid;
      double owedToMe = 0;
      double iOwe = 0;
      Map<String, double> individualBalances = {};

      // 1. Expenses created by the user (others owe you)
      final userExpensesQuery =
          await _firestore
              .collection('expenses')
              .where('userId', isEqualTo: currentUserId)
              .get();

      for (var doc in userExpensesQuery.docs) {
        final expense = Expense.fromFirestore(doc);
        if (expense.splitDetails != null) {
          expense.splitDetails!.forEach((userId, amount) {
            if (userId != currentUserId) {
              owedToMe += amount;
              individualBalances[userId] =
                  (individualBalances[userId] ?? 0) + amount;
            }
          });
        }
      }

      // 2. Expenses where others paid and you owe
      final splitExpensesQuery =
          await _firestore
              .collection('expenses')
              .where('splitDetails.$currentUserId', isGreaterThan: 0)
              .get();

      for (var doc in splitExpensesQuery.docs) {
        final expense = Expense.fromFirestore(doc);

        // 🔥 Skip if you were the one who paid
        if (expense.userId == currentUserId) continue;

        if (expense.splitDetails != null &&
            expense.splitDetails!.containsKey(currentUserId)) {
          final amount = expense.splitDetails![currentUserId] ?? 0;
          iOwe += amount;
          individualBalances[expense.userId] =
              (individualBalances[expense.userId] ?? 0) - amount;
        }
      }

      // 3. Adjust balances with settlements (full or partial)
      final userGroups = await _groupService.getUserGroups().first;

      for (var group in userGroups) {
        final settlements = await _groupService.getDetailedSettlements(
          group.id,
        );

        for (var settlement in settlements) {
          final fromId = settlement['fromId'];
          final toId = settlement['toId'];
          final amount = settlement['amount'];

          if (fromId == currentUserId) {
            // You paid someone → reduce your iOwe
            iOwe -= amount;
            individualBalances[toId] = (individualBalances[toId] ?? 0) + amount;
          } else if (toId == currentUserId) {
            // Someone paid you → reduce your owedToMe
            owedToMe -= amount;
            individualBalances[fromId] =
                (individualBalances[fromId] ?? 0) - amount;
          }
        }
      }

      // 4. Clean and round balances
      Map<String, double> cleanedBalances = {};
      individualBalances.forEach((userId, balance) {
        if (balance.abs() > 0.01) {
          cleanedBalances[userId] = double.parse(balance.toStringAsFixed(2));
        }
      });

      owedToMe = owedToMe < 0 ? 0 : double.parse(owedToMe.toStringAsFixed(2));
      iOwe = iOwe < 0 ? 0 : double.parse(iOwe.toStringAsFixed(2));

      return {
        'owedToMe': owedToMe,
        'iOwe': iOwe,
        'individualBalances': cleanedBalances,
      };
    } catch (e) {
      print('Error getting owed amounts: $e');
      return {'owedToMe': 0, 'iOwe': 0, 'individualBalances': {}};
    }
  }

  Stream<List<Expense>> getExpenses() {
    return _firestore
        .collection('expenses')
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Expense.fromFirestore(doc)).toList(),
        );
  }

  Stream<List<Expense>> getGroupExpenses(String groupId) {
    return _firestore
        .collection('expenses')
        .where('groupId', isEqualTo: groupId)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Expense.fromFirestore(doc)).toList(),
        );
  }

  Future<void> updateExpense(Expense expense) async {
    try {
      await _firestore
          .collection('expenses')
          .doc(expense.id)
          .update(expense.toMap());
    } catch (e) {
      throw e;
    }
  }

  Future<void> deleteExpense(String expenseId) async {
    try {
      await _firestore.collection('expenses').doc(expenseId).delete();
    } catch (e) {
      throw e;
    }
  }

  Future<Map<String, double>> getExpenseSummaryByCategory() async {
    try {
      QuerySnapshot snapshot =
          await _firestore
              .collection('expenses')
              .where('userId', isEqualTo: userId)
              .get();

      Map<String, double> categorySummary = {};

      for (var doc in snapshot.docs) {
        Expense expense = Expense.fromFirestore(doc);
        if (categorySummary.containsKey(expense.category)) {
          categorySummary[expense.category] =
              categorySummary[expense.category]! + expense.amount;
        } else {
          categorySummary[expense.category] = expense.amount;
        }
      }

      return categorySummary;
    } catch (e) {
      throw e;
    }
  }

  Future<Map<String, double>> getMonthlyExpenseSummary() async {
    try {
      QuerySnapshot snapshot =
          await _firestore
              .collection('expenses')
              .where('userId', isEqualTo: userId)
              .get();

      Map<String, double> monthlySummary = {};

      for (var doc in snapshot.docs) {
        Expense expense = Expense.fromFirestore(doc);
        String monthYear = '${expense.date.month}-${expense.date.year}';

        if (monthlySummary.containsKey(monthYear)) {
          monthlySummary[monthYear] =
              monthlySummary[monthYear]! + expense.amount;
        } else {
          monthlySummary[monthYear] = expense.amount;
        }
      }

      return monthlySummary;
    } catch (e) {
      throw e;
    }
  }
}
