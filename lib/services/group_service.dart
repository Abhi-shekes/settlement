import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/group_model.dart';
import '../models/split_model.dart';
import '../models/expense_model.dart';
import 'package:uuid/uuid.dart';

class GroupService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<GroupModel> _groups = [];
  List<GroupModel> get groups => _groups;

  List<SplitModel> _splits = [];
  List<SplitModel> get splits => _splits;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> createGroup(GroupModel group) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _firestore.collection('groups').doc(group.id).set(group.toMap());

      // Add group to user's groups list
      await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
        'groups': FieldValue.arrayUnion([group.id]),
      });

      _groups.add(group);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      print('Error creating group: $e');
      rethrow;
    }
  }

  Future<void> loadUserGroups() async {
    if (_auth.currentUser == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      final currentUserId = _auth.currentUser!.uid;

      // Get groups where user is admin
      final adminGroupsQuery =
          await _firestore
              .collection('groups')
              .where('adminId', isEqualTo: currentUserId)
              .get();

      // Get groups where user is a member
      final memberGroupsQuery =
          await _firestore
              .collection('groups')
              .where('memberIds', arrayContains: currentUserId)
              .get();

      final allGroupDocs = <QueryDocumentSnapshot>[];
      allGroupDocs.addAll(adminGroupsQuery.docs);
      allGroupDocs.addAll(memberGroupsQuery.docs);

      // Remove duplicates based on document ID
      final uniqueGroupDocs = <String, QueryDocumentSnapshot>{};
      for (final doc in allGroupDocs) {
        uniqueGroupDocs[doc.id] = doc;
      }

      _groups =
          uniqueGroupDocs.values
              .map(
                (doc) => GroupModel.fromMap(doc.data() as Map<String, dynamic>),
              )
              .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      print('Error loading groups: $e');
    }
  }

  Future<void> addMemberToGroup(String groupId, String userId) async {
    try {
      await _firestore.collection('groups').doc(groupId).update({
        'memberIds': FieldValue.arrayUnion([userId]),
      });

      await _firestore.collection('users').doc(userId).update({
        'groups': FieldValue.arrayUnion([groupId]),
      });

      // Update local groups list
      final groupIndex = _groups.indexWhere((g) => g.id == groupId);
      if (groupIndex != -1) {
        final updatedGroup = _groups[groupIndex].copyWith(
          memberIds: [..._groups[groupIndex].memberIds, userId],
        );
        _groups[groupIndex] = updatedGroup;
        notifyListeners();
      }
    } catch (e) {
      print('Error adding member to group: $e');
      rethrow;
    }
  }

  Future<void> createSplit(SplitModel split) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _firestore.collection('splits').doc(split.id).set(split.toMap());
      _splits.add(split);

      // Update group balances if it's a group split
      if (split.groupId != null) {
        await _updateGroupBalances(split.groupId!, split);
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      print('Error creating split: $e');
      rethrow;
    }
  }

  Future<void> _updateGroupBalances(String groupId, SplitModel split) async {
    try {
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      if (!groupDoc.exists) return;

      final group = GroupModel.fromMap(groupDoc.data()!);
      final updatedBalances = Map<String, double>.from(group.balances);

      // Update balances based on the split
      for (final participantId in split.participants) {
        if (participantId == split.paidBy) {
          // Person who paid gets credited
          updatedBalances[participantId] =
              (updatedBalances[participantId] ?? 0) +
              split.totalAmount -
              split.splitAmounts[participantId]!;
        } else {
          // Others get debited
          updatedBalances[participantId] =
              (updatedBalances[participantId] ?? 0) -
              split.splitAmounts[participantId]!;
        }
      }

      await _firestore.collection('groups').doc(groupId).update({
        'balances': updatedBalances,
      });

      // Update local group
      final groupIndex = _groups.indexWhere((g) => g.id == groupId);
      if (groupIndex != -1) {
        _groups[groupIndex] = group.copyWith(balances: updatedBalances);
        notifyListeners();
      }
    } catch (e) {
      print('Error updating group balances: $e');
    }
  }

  Future<void> loadUserSplits() async {
    if (_auth.currentUser == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      final query =
          await _firestore
              .collection('splits')
              .where('participants', arrayContains: _auth.currentUser!.uid)
              .orderBy('createdAt', descending: true)
              .get();

      _splits =
          query.docs.map((doc) => SplitModel.fromMap(doc.data())).toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      print('Error loading splits: $e');
    }
  }

  Future<void> addSettlement(String splitId, SettlementModel settlement) async {
    try {
      final splitDoc = await _firestore.collection('splits').doc(splitId).get();
      if (!splitDoc.exists) return;

      final split = SplitModel.fromMap(splitDoc.data()!);
      final updatedSettlements = [...split.settlements, settlement];

      // Check if split is fully settled
      final totalOwed = split.getAmountOwedBy(settlement.fromUserId);
      final totalSettled = updatedSettlements
          .where((s) => s.fromUserId == settlement.fromUserId)
          .fold(0.0, (sum, s) => sum + s.amount);

      final isFullySettled = totalSettled >= totalOwed;

      await _firestore.collection('splits').doc(splitId).update({
        'settlements': updatedSettlements.map((s) => s.toMap()).toList(),
        'isFullySettled': isFullySettled,
      });

      // Update local splits list
      final splitIndex = _splits.indexWhere((s) => s.id == splitId);
      if (splitIndex != -1) {
        _splits[splitIndex] = split.copyWith(
          settlements: updatedSettlements,
          isFullySettled: isFullySettled,
        );
        notifyListeners();
      }

      // Update group balances if it's a group split
      if (split.groupId != null) {
        await _updateGroupBalancesForSettlement(split.groupId!, settlement);
      }
    } catch (e) {
      print('Error adding settlement: $e');
      rethrow;
    }
  }

  Future<void> _updateGroupBalancesForSettlement(
    String groupId,
    SettlementModel settlement,
  ) async {
    try {
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      if (!groupDoc.exists) return;

      final group = GroupModel.fromMap(groupDoc.data()!);
      final updatedBalances = Map<String, double>.from(group.balances);

      // Update balances: fromUser pays, toUser receives
      updatedBalances[settlement.fromUserId] =
          (updatedBalances[settlement.fromUserId] ?? 0) + settlement.amount;
      updatedBalances[settlement.toUserId] =
          (updatedBalances[settlement.toUserId] ?? 0) - settlement.amount;

      await _firestore.collection('groups').doc(groupId).update({
        'balances': updatedBalances,
      });

      // Update local group
      final groupIndex = _groups.indexWhere((g) => g.id == groupId);
      if (groupIndex != -1) {
        _groups[groupIndex] = group.copyWith(balances: updatedBalances);
        notifyListeners();
      }
    } catch (e) {
      print('Error updating group balances for settlement: $e');
    }
  }

  List<SplitModel> getGroupSplits(String groupId) {
    return _splits.where((s) => s.groupId == groupId).toList();
  }

  List<SplitModel> getUserOwedSplits(String userId) {
    return _splits
        .where(
          (s) =>
              s.participants.contains(userId) &&
              s.paidBy != userId &&
              s.getRemainingAmount(userId) > 0,
        )
        .toList();
  }

  List<SplitModel> getUserOwingSplits(String userId) {
    return _splits
        .where(
          (s) =>
              s.paidBy == userId &&
              s.participants.any(
                (p) => p != userId && s.getRemainingAmount(p) > 0,
              ),
        )
        .toList();
  }

  double getTotalAmountOwed(String userId) {
    return getUserOwedSplits(
      userId,
    ).fold(0.0, (sum, split) => sum + split.getRemainingAmount(userId));
  }

  double getTotalAmountOwing(String userId) {
    return getUserOwingSplits(userId).fold(
      0.0,
      (sum, split) =>
          sum +
          split.participants
              .where((p) => p != userId)
              .fold(0.0, (pSum, p) => pSum + split.getRemainingAmount(p)),
    );
  }

  Future<void> updateGroup(GroupModel group) async {
    try {
      await _firestore.collection('groups').doc(group.id).update(group.toMap());

      final groupIndex = _groups.indexWhere((g) => g.id == group.id);
      if (groupIndex != -1) {
        _groups[groupIndex] = group;
        notifyListeners();
      }
    } catch (e) {
      print('Error updating group: $e');
      rethrow;
    }
  }

  Future<void> deleteGroup(String groupId) async {
    try {
      final group = _groups.firstWhere((g) => g.id == groupId);

      // Remove group from all members' user documents
      for (final memberId in group.allMemberIds) {
        await _firestore.collection('users').doc(memberId).update({
          'groups': FieldValue.arrayRemove([groupId]),
        });
      }

      // Delete all splits associated with this group
      final splitsQuery =
          await _firestore
              .collection('splits')
              .where('groupId', isEqualTo: groupId)
              .get();

      for (final splitDoc in splitsQuery.docs) {
        await splitDoc.reference.delete();
      }

      // Delete the group
      await _firestore.collection('groups').doc(groupId).delete();

      // Update local state
      _groups.removeWhere((g) => g.id == groupId);
      _splits.removeWhere((s) => s.groupId == groupId);
      notifyListeners();
    } catch (e) {
      print('Error deleting group: $e');
      rethrow;
    }
  }

  Future<void> leaveGroup(String groupId, String userId) async {
    try {
      final group = _groups.firstWhere((g) => g.id == groupId);

      if (group.adminId == userId) {
        throw Exception(
          'Admin cannot leave group. Transfer admin rights or delete the group.',
        );
      }

      // Remove user from group
      await _firestore.collection('groups').doc(groupId).update({
        'memberIds': FieldValue.arrayRemove([userId]),
      });

      // Remove group from user's groups list
      await _firestore.collection('users').doc(userId).update({
        'groups': FieldValue.arrayRemove([groupId]),
      });

      // Update local state
      final groupIndex = _groups.indexWhere((g) => g.id == groupId);
      if (groupIndex != -1) {
        final updatedMemberIds = List<String>.from(group.memberIds);
        updatedMemberIds.remove(userId);
        _groups[groupIndex] = group.copyWith(memberIds: updatedMemberIds);
        notifyListeners();
      }
    } catch (e) {
      print('Error leaving group: $e');
      rethrow;
    }
  }

  Future<void> addGroupExpense(String groupId, ExpenseModel expense) async {
    try {
      // Add expense to expenses collection
      await _firestore
          .collection('expenses')
          .doc(expense.id)
          .set(expense.toMap());

      // Add expense ID to group
      await _firestore.collection('groups').doc(groupId).update({
        'expenseIds': FieldValue.arrayUnion([expense.id]),
      });

      // Update local group
      final groupIndex = _groups.indexWhere((g) => g.id == groupId);
      if (groupIndex != -1) {
        final updatedExpenseIds = [
          ..._groups[groupIndex].expenseIds,
          expense.id,
        ];
        _groups[groupIndex] = _groups[groupIndex].copyWith(
          expenseIds: updatedExpenseIds,
        );
        notifyListeners();
      }
    } catch (e) {
      print('Error adding group expense: $e');
      rethrow;
    }
  }

  Future<void> settleGroupBalance(
    String groupId,
    String fromUserId,
    String toUserId,
    double amount,
  ) async {
    try {
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      if (!groupDoc.exists) return;

      final group = GroupModel.fromMap(groupDoc.data()!);
      final updatedBalances = Map<String, double>.from(group.balances);

      // Update balances: fromUser pays, toUser receives
      updatedBalances[fromUserId] = (updatedBalances[fromUserId] ?? 0) + amount;
      updatedBalances[toUserId] = (updatedBalances[toUserId] ?? 0) - amount;

      await _firestore.collection('groups').doc(groupId).update({
        'balances': updatedBalances,
      });

      // Create a settlement record
      final settlement = SettlementModel(
        id: const Uuid().v4(),
        fromUserId: fromUserId,
        toUserId: toUserId,
        amount: amount,
        settledAt: DateTime.now(),
        notes: 'Group settlement',
      );

      await _firestore.collection('settlements').add(settlement.toMap());

      // Update local group
      final groupIndex = _groups.indexWhere((g) => g.id == groupId);
      if (groupIndex != -1) {
        _groups[groupIndex] = group.copyWith(balances: updatedBalances);
        notifyListeners();
      }
    } catch (e) {
      print('Error settling group balance: $e');
      rethrow;
    }
  }

  Future<List<ExpenseModel>> getGroupExpenses(String groupId) async {
    try {
      final group = _groups.firstWhere((g) => g.id == groupId);
      if (group.expenseIds.isEmpty) return [];

      final expensesQuery =
          await _firestore
              .collection('expenses')
              .where(FieldPath.documentId, whereIn: group.expenseIds)
              .orderBy('createdAt', descending: true)
              .get();

      return expensesQuery.docs
          .map((doc) => ExpenseModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting group expenses: $e');
      return [];
    }
  }
}

extension GroupModelExtension on GroupModel {
  GroupModel copyWith({
    String? id,
    String? name,
    String? description,
    String? adminId,
    List<String>? memberIds,
    DateTime? createdAt,
    String? imageUrl,
    List<String>? expenseIds,
    Map<String, double>? balances,
  }) {
    return GroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      adminId: adminId ?? this.adminId,
      memberIds: memberIds ?? this.memberIds,
      createdAt: createdAt ?? this.createdAt,
      imageUrl: imageUrl ?? this.imageUrl,
      expenseIds: expenseIds ?? this.expenseIds,
      balances: balances ?? this.balances,
    );
  }
}

extension SplitModelExtension on SplitModel {
  SplitModel copyWith({
    String? id,
    String? title,
    String? description,
    double? totalAmount,
    String? paidBy,
    List<String>? participants,
    SplitType? splitType,
    Map<String, double>? splitAmounts,
    DateTime? createdAt,
    String? groupId,
    String? notes,
    bool? isFullySettled,
    List<SettlementModel>? settlements,
  }) {
    return SplitModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      totalAmount: totalAmount ?? this.totalAmount,
      paidBy: paidBy ?? this.paidBy,
      participants: participants ?? this.participants,
      splitType: splitType ?? this.splitType,
      splitAmounts: splitAmounts ?? this.splitAmounts,
      createdAt: createdAt ?? this.createdAt,
      groupId: groupId ?? this.groupId,
      notes: notes ?? this.notes,
      isFullySettled: isFullySettled ?? this.isFullySettled,
      settlements: settlements ?? this.settlements,
    );
  }
}
