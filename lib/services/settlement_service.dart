import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_tracker/models/settlement.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettlementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String userId = FirebaseAuth.instance.currentUser!.uid;

  Future<void> recordSettlement({
    required String expenseId,
    required String fromUserId,
    required String toUserId,
    required double amount,
    bool isPartial = false,
    String? note,
  }) async {
    try {
      final settlement = Settlement(
        id: '',
        expenseId: expenseId,
        fromUserId: fromUserId,
        toUserId: toUserId,
        amount: amount,
        settledAt: DateTime.now(),
        isPartial: isPartial,
        note: note,
      );

      await _firestore.collection('settlements').add(settlement.toMap());
    } catch (e) {
      throw e;
    }
  }

  Future<List<Settlement>> getSettlementsForExpense(String expenseId) async {
    try {
      QuerySnapshot snapshot =
          await _firestore
              .collection('settlements')
              .where('expenseId', isEqualTo: expenseId)
              .orderBy('settledAt', descending: true)
              .get();

      return snapshot.docs.map((doc) => Settlement.fromFirestore(doc)).toList();
    } catch (e) {
      throw e;
    }
  }

  Future<Map<String, double>> getSettledAmountsForExpense(
    String expenseId,
  ) async {
    try {
      final settlements = await getSettlementsForExpense(expenseId);
      Map<String, double> settledAmounts = {};

      for (Settlement settlement in settlements) {
        String key = '${settlement.fromUserId}_${settlement.toUserId}';
        settledAmounts[key] = (settledAmounts[key] ?? 0) + settlement.amount;
      }

      return settledAmounts;
    } catch (e) {
      throw e;
    }
  }

  Future<bool> isExpenseFullySettled(
    String expenseId,
    Map<String, double> splitDetails,
    String expenseCreatorId,
  ) async {
    try {
      final settlements = await getSettlementsForExpense(expenseId);

      // Calculate total amount that should be settled
      double totalToSettle = 0;
      for (var entry in splitDetails.entries) {
        if (entry.key != expenseCreatorId) {
          totalToSettle += entry.value;
        }
      }

      // Calculate total settled amount
      double totalSettled = 0;
      for (Settlement settlement in settlements) {
        totalSettled += settlement.amount;
      }

      return (totalToSettle - totalSettled).abs() < 0.01;
    } catch (e) {
      throw e;
    }
  }

  Stream<List<Settlement>> getUserSettlements() {
    return _firestore
        .collection('settlements')
        .where('fromUserId', isEqualTo: userId)
        .orderBy('settledAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => Settlement.fromFirestore(doc))
                  .toList(),
        );
  }

  Future<double> getSettledAmountBetweenUsers(
    String user1Id,
    String user2Id,
    String expenseId,
  ) async {
    try {
      QuerySnapshot snapshot =
          await _firestore
              .collection('settlements')
              .where('expenseId', isEqualTo: expenseId)
              .get();

      double settledAmount = 0;
      for (var doc in snapshot.docs) {
        Settlement settlement = Settlement.fromFirestore(doc);
        if ((settlement.fromUserId == user1Id &&
                settlement.toUserId == user2Id) ||
            (settlement.fromUserId == user2Id &&
                settlement.toUserId == user1Id)) {
          settledAmount += settlement.amount;
        }
      }

      return settledAmount;
    } catch (e) {
      throw e;
    }
  }
}
