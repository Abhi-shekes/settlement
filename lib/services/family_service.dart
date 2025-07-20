import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/family_member_model.dart';
import '../models/split_model.dart';

class FamilyService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<FamilyMemberModel> _familyMembers = [];
  List<FamilyMemberModel> get familyMembers => _familyMembers;

  List<SplitModel> _familySplits = [];
  List<SplitModel> get familySplits => _familySplits;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> loadFamilyMembers() async {
    if (_auth.currentUser == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      final query =
          await _firestore
              .collection('family_members')
              .where('userId', isEqualTo: _auth.currentUser!.uid)
              .where('isActive', isEqualTo: true)
              .orderBy('addedAt', descending: false)
              .get();

      _familyMembers =
          query.docs
              .map((doc) => FamilyMemberModel.fromMap(doc.data()))
              .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      print('Error loading family members: $e');
    }
  }

  Future<void> addFamilyMember(FamilyMemberModel member) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _firestore
          .collection('family_members')
          .doc(member.id)
          .set(member.toMap());

      _familyMembers.add(member);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      print('Error adding family member: $e');
      rethrow;
    }
  }

  Future<void> updateFamilyMember(FamilyMemberModel member) async {
    try {
      await _firestore
          .collection('family_members')
          .doc(member.id)
          .update(member.toMap());

      final index = _familyMembers.indexWhere((m) => m.id == member.id);
      if (index != -1) {
        _familyMembers[index] = member;
        notifyListeners();
      }
    } catch (e) {
      print('Error updating family member: $e');
      rethrow;
    }
  }

  Future<void> removeFamilyMember(String memberId) async {
    try {
      await _firestore.collection('family_members').doc(memberId).update({
        'isActive': false,
      });

      _familyMembers.removeWhere((m) => m.id == memberId);
      notifyListeners();
    } catch (e) {
      print('Error removing family member: $e');
      rethrow;
    }
  }

  Future<void> createFamilySplit(SplitModel split) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Mark as family split
      final familySplit = SplitModel(
        id: split.id,
        title: split.title,
        description: split.description,
        totalAmount: split.totalAmount,
        paidBy: split.paidBy,
        participants: split.participants,
        splitType: split.splitType,
        splitAmounts: split.splitAmounts,
        createdAt: split.createdAt,
        groupId: null, // Family splits don't belong to groups
        notes: split.notes,
        isFullySettled: split.isFullySettled,
        settlements: split.settlements,
      );

      await _firestore
          .collection('splits')
          .doc(familySplit.id)
          .set(familySplit.toMap());

      _familySplits.add(familySplit);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      print('Error creating family split: $e');
      rethrow;
    }
  }

  Future<void> loadFamilySplits() async {
    if (_auth.currentUser == null) return;

    try {
      final query =
          await _firestore
              .collection('splits')
              .where('participants', arrayContains: _auth.currentUser!.uid)
              .where('tags', arrayContains: 'family')
              .orderBy('createdAt', descending: true)
              .get();

      _familySplits =
          query.docs.map((doc) => SplitModel.fromMap(doc.data())).toList();

      notifyListeners();
    } catch (e) {
      print('Error loading family splits: $e');
    }
  }

  List<FamilyMemberModel> getFamilyMembersByRole(FamilyRole role) {
    return _familyMembers.where((member) => member.role == role).toList();
  }

  double getTotalFamilyExpenses() {
    return _familySplits.fold(0.0, (sum, split) => sum + split.totalAmount);
  }

  double getFamilyMemberBalance(String memberId) {
    double balance = 0.0;
    for (final split in _familySplits) {
      if (split.participants.contains(memberId)) {
        if (split.paidBy == memberId) {
          // Member paid, so they are owed money
          balance += split.totalAmount - (split.splitAmounts[memberId] ?? 0);
        } else {
          // Member owes money
          balance -= split.splitAmounts[memberId] ?? 0;
        }
      }
    }
    return balance;
  }
}
