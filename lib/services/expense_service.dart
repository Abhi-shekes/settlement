import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:expense_tracker/services/group_service.dart';

class ExpenseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String userId = FirebaseAuth.instance.currentUser!.uid;
  final GroupService _groupService = GroupService();
  List<String> _settledPayments = [];

  Future<void> addExpense(Expense expense) async {
    try {
      await _firestore.collection('expenses').add(expense.toMap());
    } catch (e) {
      throw e;
    }
  }

  Future<Map<String, dynamic>> getOwedAmounts() async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;

      // Get all expenses
      final QuerySnapshot expenseSnapshot =
          await _firestore.collection('expenses').where('groupId').get();

      // Initialize balances
      double amountOwedToMe = 0;
      double amountIOwe = 0;
      Map<String, double> individualBalances = {};

      // Calculate balances from expenses
      for (var doc in expenseSnapshot.docs) {
        final expense = Expense.fromFirestore(doc);
        if (expense.splitDetails == null) continue;

        if (expense.userId == currentUserId) {
          // I paid for the expense
          final myShare = expense.splitDetails![currentUserId] ?? 0;
          final totalOthersShare = expense.amount - myShare;
          amountOwedToMe += totalOthersShare;

          expense.splitDetails!.forEach((userId, share) {
            if (userId != currentUserId) {
              individualBalances.update(
                userId,
                (value) => value + share, // They owe me
                ifAbsent: () => share,
              );
            }
          });
        } else if (expense.splitDetails!.containsKey(currentUserId)) {
          // Someone else paid, but I'm included in the split
          final myShare = expense.splitDetails![currentUserId] ?? 0;
          amountIOwe += myShare;

          individualBalances.update(
            expense.userId,
            (value) => value - myShare, // I owe them
            ifAbsent: () => -myShare,
          );
        }
      }

      // Get all groups the user is a member of
      final groupsSnapshot =
          await _firestore
              .collection('groups')
              .where('members', arrayContains: currentUserId)
              .get();

      // Process settled payments for each group
      for (var groupDoc in groupsSnapshot.docs) {
        final groupId = groupDoc.id;
        final settledPayments = await _groupService.getSettledPayments(groupId);

        // Adjust balances based on settled payments
        for (String paymentInfo in settledPayments) {
          final parts = paymentInfo.split('|');
          if (parts.length == 3) {
            final fromUserId = parts[0];
            final toUserId = parts[1];
            final amount = double.parse(parts[2]);

            // If I paid someone
            if (fromUserId == currentUserId) {
              // I've already paid this amount to someone, so reduce what I owe
              amountIOwe -= amount;

              // Update individual balance
              individualBalances.update(
                toUserId,
                (value) =>
                    value +
                    amount, // Increase what they owe me (or decrease what I owe them)
                ifAbsent: () => amount,
              );
            }
            // If someone paid me
            else if (toUserId == currentUserId) {
              // Someone has paid me, so reduce what they owe me
              amountOwedToMe -= amount;

              // Update individual balance
              individualBalances.update(
                fromUserId,
                (value) =>
                    value -
                    amount, // Decrease what they owe me (or increase what I owe them)
                ifAbsent: () => -amount,
              );
            }
          }
        }
      }

      // Ensure all balances are properly rounded to avoid floating point issues
      individualBalances.forEach((userId, balance) {
        individualBalances[userId] = double.parse(balance.toStringAsFixed(2));
      });

      // Make sure we don't have negative zeros due to rounding
      amountOwedToMe = double.parse(amountOwedToMe.toStringAsFixed(2));
      amountIOwe = double.parse(amountIOwe.toStringAsFixed(2));

      // Ensure we don't show negative values for the totals
      amountOwedToMe = amountOwedToMe < 0 ? 0 : amountOwedToMe;
      amountIOwe = amountIOwe < 0 ? 0 : amountIOwe;

      // Return the correct structure with adjusted balances
      return {
        'owedToMe': amountOwedToMe,
        'iOwe': amountIOwe,
        'individualBalances': individualBalances,
        'hasSettlements':
            _settledPayments
                .isNotEmpty, // Add this flag instead of actual settlement data
      };
    } catch (e) {
      print('Error calculating owed amounts: $e');
      throw e;
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
