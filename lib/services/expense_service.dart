import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/models/settlement.dart';
import 'package:expense_tracker/services/settlement_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:expense_tracker/services/group_service.dart';
import 'package:expense_tracker/services/auth_service.dart';

class ExpenseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String userId = FirebaseAuth.instance.currentUser!.uid;
  final GroupService _groupService = GroupService();
  final SettlementService _settlementService = SettlementService();
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

      final allExpensesQuery = await _firestore.collection('expenses').get();

      for (var doc in allExpensesQuery.docs) {
        final expense = Expense.fromFirestore(doc);

        if (expense.splitDetails == null) continue;

        if (!expense.splitDetails!.containsKey(currentUserId) &&
            expense.userId != currentUserId) {
          continue;
        }

        if (expense.groupId == null && expense.splitDetails!.length == 2) {
          await _processIndividualSplitExpense(
            expense,
            currentUserId,
            individualBalances,
          );
        } else if (expense.groupId != null) {
          await _processGroupSplitExpense(
            expense,
            currentUserId,
            individualBalances,
          );
        }
      }

      // Clean and calculate final values
      Map<String, double> cleanedBalances = {};
      individualBalances.forEach((userId, balance) {
        if (balance.abs() > 0.01) {
          cleanedBalances[userId] = double.parse(balance.toStringAsFixed(2));
          if (balance > 0) {
            owedToMe += balance;
          } else {
            iOwe += balance.abs();
          }
        }
      });

      return {
        'owedToMe': double.parse(owedToMe.toStringAsFixed(2)),
        'iOwe': double.parse(iOwe.toStringAsFixed(2)),
        'individualBalances': cleanedBalances,
      };
    } catch (e) {
      print('Error getting owed amounts: $e');
      return {'owedToMe': 0.0, 'iOwe': 0.0, 'individualBalances': {}};
    }
  }

  Future<void> _processIndividualSplitExpense(
    Expense expense,
    String currentUserId,
    Map<String, double> individualBalances,
  ) async {
    final settlements = await _settlementService.getSettlementsForExpense(
      expense.id,
    );

    String? otherUserId;
    for (String userId in expense.splitDetails!.keys) {
      if (userId != currentUserId) {
        otherUserId = userId;
        break;
      }
    }
    if (otherUserId == null) return;

    double myShare = expense.splitDetails![currentUserId] ?? 0;
    double otherShare = expense.splitDetails![otherUserId] ?? 0;

    if (expense.userId == currentUserId) {
      // I paid, other owes me
      double paidByOther = settlements
          .where(
            (s) => s.fromUserId == otherUserId && s.toUserId == currentUserId,
          )
          .fold(0.0, (sum, s) => sum + s.amount);
      double balance = otherShare - paidByOther;
      individualBalances[otherUserId] =
          (individualBalances[otherUserId] ?? 0) + balance;
    } else {
      // Other paid, I owe them
      double paidByMe = settlements
          .where(
            (s) => s.fromUserId == currentUserId && s.toUserId == otherUserId,
          )
          .fold(0.0, (sum, s) => sum + s.amount);
      double balance = myShare - paidByMe;
      individualBalances[otherUserId] =
          (individualBalances[otherUserId] ?? 0) - balance;
    }
  }

  Future<void> _processGroupSplitExpense(
    Expense expense,
    String currentUserId,
    Map<String, double> individualBalances,
  ) async {
    final settlements = await _settlementService.getSettlementsForExpense(
      expense.id,
    );

    if (expense.userId == currentUserId) {
      // Others owe me
      for (var entry in expense.splitDetails!.entries) {
        String userId = entry.key;
        if (userId == currentUserId) continue;

        double expectedFromUser = entry.value;
        double paidByUser = settlements
            .where((s) => s.fromUserId == userId && s.toUserId == currentUserId)
            .fold(0.0, (sum, s) => sum + s.amount);
        double balance = expectedFromUser - paidByUser;

        individualBalances[userId] =
            (individualBalances[userId] ?? 0) + balance;
      }
    } else {
      // I owe the payer
      double myShare = expense.splitDetails![currentUserId] ?? 0;
      double paidByMe = settlements
          .where(
            (s) =>
                s.fromUserId == currentUserId && s.toUserId == expense.userId,
          )
          .fold(0.0, (sum, s) => sum + s.amount);
      double balance = myShare - paidByMe;

      individualBalances[expense.userId] =
          (individualBalances[expense.userId] ?? 0) - balance;
    }
  }

  Future<bool> isIndividualExpenseSettled(String expenseId) async {
    try {
      // Get the expense
      DocumentSnapshot expenseDoc =
          await _firestore.collection('expenses').doc(expenseId).get();

      if (!expenseDoc.exists) return false;

      Expense expense = Expense.fromFirestore(expenseDoc);

      // Check if it's an individual split
      if (expense.groupId != null ||
          expense.splitDetails == null ||
          expense.splitDetails!.length != 2) {
        return false;
      }

      return await _settlementService.isExpenseFullySettled(
        expenseId,
        expense.splitDetails!,
        expense.userId,
      );
    } catch (e) {
      print('Error checking if expense is settled: $e');
      return false;
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

  Stream<List<Expense>> getAllUserExpenses() {
    return _firestore
        .collection('expenses')
        .orderBy('date', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          List<Expense> userExpenses = [];

          for (var doc in snapshot.docs) {
            Expense expense = Expense.fromFirestore(doc);

            // Include if user created the expense
            if (expense.userId == userId) {
              userExpenses.add(expense);
              continue;
            }

            // Include if user is part of the split
            if (expense.splitDetails != null &&
                expense.splitDetails!.containsKey(userId)) {
              userExpenses.add(expense);
            }
          }

          return userExpenses;
        });
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
      // Delete the expense
      await _firestore.collection('expenses').doc(expenseId).delete();

      // Delete associated settlements
      QuerySnapshot settlements =
          await _firestore
              .collection('settlements')
              .where('expenseId', isEqualTo: expenseId)
              .get();

      for (var doc in settlements.docs) {
        await doc.reference.delete();
      }
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
