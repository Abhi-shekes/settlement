import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/group_model.dart';
import '../models/split_model.dart';
import '../models/expense_model.dart';

/// A pending settlement paired with the split it belongs to, for the confirm
/// inbox.
class PendingSettlement {
  final SplitModel split;
  final SettlementModel settlement;
  PendingSettlement({required this.split, required this.settlement});
}

class GroupService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<GroupModel> _groups = [];
  List<GroupModel> get groups => _groups;

  List<SplitModel> _splits = [];
  List<SplitModel> get splits => _splits;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Clears cached data (e.g. on sign-out).
  void reset() {
    _groups = [];
    _splits = [];
    notifyListeners();
  }

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
      debugPrint('Error creating group: $e');
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
      debugPrint('Error loading groups: $e');
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
      debugPrint('Error adding member to group: $e');
      rethrow;
    }
  }

  Future<void> createSplit(SplitModel split) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Handshake: the payer is auto-accepted, but every other participant must
      // approve their share before it becomes a real debt — so we do NOT touch
      // group balances here. Balances move in [acceptSplitShare].
      final status = <String, String>{};
      for (final p in split.participants) {
        status[p] =
            p == split.paidBy
                ? ParticipantStatus.accepted
                : ParticipantStatus.pending;
      }
      final pendingSplit = split.copyWith(participantStatus: status);

      await _firestore
          .collection('splits')
          .doc(pendingSplit.id)
          .set(pendingSplit.toMap());
      _splits.add(pendingSplit);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Error creating split: $e');
      rethrow;
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
      debugPrint('Error loading splits: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Split-share approval (per-participant handshake)
  // ---------------------------------------------------------------------------

  /// A participant approves their share. Only now does their portion of the
  /// debt post to the group balances (payer credited, participant debited).
  Future<void> acceptSplitShare(String splitId, String userId) async {
    try {
      final splitRef = _firestore.collection('splits').doc(splitId);

      final result = await _firestore.runTransaction((txn) async {
        final splitDoc = await txn.get(splitRef);
        if (!splitDoc.exists) return null;

        final split = SplitModel.fromMap(splitDoc.data()!);
        if (split.statusFor(userId) == ParticipantStatus.accepted) {
          return null; // idempotent
        }

        final status = Map<String, String>.from(split.participantStatus);
        status[userId] = ParticipantStatus.accepted;
        final share = split.getAmountOwedBy(userId);

        DocumentReference? groupRef;
        Map<String, double>? balances;
        if (split.groupId != null && share != 0) {
          groupRef = _firestore.collection('groups').doc(split.groupId);
          final groupDoc = await txn.get(groupRef);
          if (groupDoc.exists) {
            final group = GroupModel.fromMap(
              groupDoc.data()! as Map<String, dynamic>,
            );
            balances = Map<String, double>.from(group.balances);
            balances[userId] = (balances[userId] ?? 0) - share;
            balances[split.paidBy] = (balances[split.paidBy] ?? 0) + share;
          }
        }

        txn.update(splitRef, {'participantStatus': status});
        if (groupRef != null && balances != null) {
          txn.update(groupRef, {'balances': balances});
        }

        return {
          'split': split.copyWith(participantStatus: status),
          'groupId': split.groupId,
          'balances': balances,
        };
      });

      if (result == null) return;
      _applyLocalSplitAndBalances(result);
      notifyListeners();
    } catch (e) {
      debugPrint('Error accepting split share: $e');
      rethrow;
    }
  }

  /// A participant declines their share; it never becomes a debt.
  Future<void> declineSplitShare(String splitId, String userId) async {
    try {
      final splitRef = _firestore.collection('splits').doc(splitId);
      final splitDoc = await splitRef.get();
      if (!splitDoc.exists) return;

      final split = SplitModel.fromMap(splitDoc.data()!);
      final status = Map<String, String>.from(split.participantStatus);
      status[userId] = ParticipantStatus.declined;

      await splitRef.update({'participantStatus': status});

      final idx = _splits.indexWhere((s) => s.id == splitId);
      if (idx != -1) {
        _splits[idx] = split.copyWith(participantStatus: status);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error declining split share: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Settlements (record → the other party confirms)
  // ---------------------------------------------------------------------------

  /// Records a settlement as PENDING. Balances do not move until the other
  /// party confirms it via [confirmSettlement]. [settlement] must carry
  /// status = pending and recordedBy = the current user.
  Future<void> recordSettlement(
    String splitId,
    SettlementModel settlement,
  ) async {
    try {
      final splitRef = _firestore.collection('splits').doc(splitId);
      final splitDoc = await splitRef.get();
      if (!splitDoc.exists) return;

      final split = SplitModel.fromMap(splitDoc.data()!);
      final updated = [...split.settlements, settlement];

      await splitRef.update({
        'settlements': updated.map((s) => s.toMap()).toList(),
      });

      final idx = _splits.indexWhere((s) => s.id == splitId);
      if (idx != -1) {
        _splits[idx] = split.copyWith(settlements: updated);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error recording settlement: $e');
      rethrow;
    }
  }

  /// The counterparty confirms a pending settlement: only now do balances move
  /// and the split can become fully settled.
  Future<void> confirmSettlement(String splitId, String settlementId) async {
    try {
      final splitRef = _firestore.collection('splits').doc(splitId);

      final result = await _firestore.runTransaction((txn) async {
        final splitDoc = await txn.get(splitRef);
        if (!splitDoc.exists) return null;

        final split = SplitModel.fromMap(splitDoc.data()!);
        final sIdx = split.settlements.indexWhere((s) => s.id == settlementId);
        if (sIdx == -1) return null;
        final target = split.settlements[sIdx];
        if (target.status != SettlementStatus.pending) return null;

        final updatedSettlements = List<SettlementModel>.from(
          split.settlements,
        );
        updatedSettlements[sIdx] = target.copyWith(
          status: SettlementStatus.confirmed,
        );

        // Fully settled only when every ACCEPTED non-payer participant is clear.
        final probe = split.copyWith(settlements: updatedSettlements);
        final acceptedDebtors =
            split.participants
                .where((p) => p != split.paidBy && split.hasAcceptedShare(p))
                .toList();
        final isFullySettled =
            acceptedDebtors.isNotEmpty &&
            acceptedDebtors.every((p) => probe.getRemainingAmount(p) <= 0.01);

        DocumentReference? groupRef;
        Map<String, double>? balances;
        if (split.groupId != null) {
          groupRef = _firestore.collection('groups').doc(split.groupId);
          final groupDoc = await txn.get(groupRef);
          if (groupDoc.exists) {
            final group = GroupModel.fromMap(
              groupDoc.data()! as Map<String, dynamic>,
            );
            balances = Map<String, double>.from(group.balances);
            balances[target.fromUserId] =
                (balances[target.fromUserId] ?? 0) + target.amount;
            balances[target.toUserId] =
                (balances[target.toUserId] ?? 0) - target.amount;
          }
        }

        txn.update(splitRef, {
          'settlements': updatedSettlements.map((s) => s.toMap()).toList(),
          'isFullySettled': isFullySettled,
        });
        if (groupRef != null && balances != null) {
          txn.update(groupRef, {'balances': balances});
        }

        return {
          'split': split.copyWith(
            settlements: updatedSettlements,
            isFullySettled: isFullySettled,
          ),
          'groupId': split.groupId,
          'balances': balances,
        };
      });

      if (result == null) return;
      _applyLocalSplitAndBalances(result);
      notifyListeners();
    } catch (e) {
      debugPrint('Error confirming settlement: $e');
      rethrow;
    }
  }

  /// The counterparty rejects a pending settlement; balances are untouched.
  Future<void> rejectSettlement(String splitId, String settlementId) async {
    try {
      final splitRef = _firestore.collection('splits').doc(splitId);
      final splitDoc = await splitRef.get();
      if (!splitDoc.exists) return;

      final split = SplitModel.fromMap(splitDoc.data()!);
      final sIdx = split.settlements.indexWhere((s) => s.id == settlementId);
      if (sIdx == -1) return;

      final updated = List<SettlementModel>.from(split.settlements);
      updated[sIdx] = updated[sIdx].copyWith(status: SettlementStatus.rejected);

      await splitRef.update({
        'settlements': updated.map((s) => s.toMap()).toList(),
      });

      final idx = _splits.indexWhere((s) => s.id == splitId);
      if (idx != -1) {
        _splits[idx] = split.copyWith(settlements: updated);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error rejecting settlement: $e');
      rethrow;
    }
  }

  void _applyLocalSplitAndBalances(Map<String, dynamic> result) {
    final updatedSplit = result['split'] as SplitModel;
    final idx = _splits.indexWhere((s) => s.id == updatedSplit.id);
    if (idx != -1) {
      _splits[idx] = updatedSplit;
    }
    final groupId = result['groupId'] as String?;
    final balances = result['balances'] as Map<String, double>?;
    if (groupId != null && balances != null) {
      final gi = _groups.indexWhere((g) => g.id == groupId);
      if (gi != -1) {
        _groups[gi] = _groups[gi].copyWith(balances: balances);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Pending-confirmation feeds (for the Requests inbox / inline surfaces)
  // ---------------------------------------------------------------------------

  /// Splits where [userId] still has to approve their share.
  List<SplitModel> splitsAwaitingApprovalFrom(String userId) {
    return _splits
        .where((s) => s.paidBy != userId && s.isAwaitingApprovalFrom(userId))
        .toList();
  }

  /// Pending settlements that [userId] is the one who must confirm.
  List<PendingSettlement> pendingSettlementsToConfirm(String userId) {
    final result = <PendingSettlement>[];
    for (final s in _splits) {
      for (final st in s.settlements) {
        if (st.isPending && st.confirmerId == userId) {
          result.add(PendingSettlement(split: s, settlement: st));
        }
      }
    }
    return result;
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
              s.hasAcceptedShare(userId) &&
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
                (p) =>
                    p != userId &&
                    s.hasAcceptedShare(p) &&
                    s.getRemainingAmount(p) > 0,
              ),
        )
        .toList();
  }

  double getTotalAmountOwed(String userId) {
    return getUserOwedSplits(
      userId,
    ).fold(0.0, (acc, split) => acc + split.getRemainingAmount(userId));
  }

  double getTotalAmountOwing(String userId) {
    return getUserOwingSplits(userId).fold(
      0.0,
      (acc, split) =>
          acc +
          split.participants
              .where((p) => p != userId && split.hasAcceptedShare(p))
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
      debugPrint('Error updating group: $e');
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
      debugPrint('Error deleting group: $e');
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
      debugPrint('Error leaving group: $e');
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
      debugPrint('Error adding group expense: $e');
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
      debugPrint('Error getting group expenses: $e');
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
    Map<String, String>? participantStatus,
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
      participantStatus: participantStatus ?? this.participantStatus,
    );
  }
}
