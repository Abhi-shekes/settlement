import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_tracker/models/group.dart';
import 'package:expense_tracker/models/user_profile.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GroupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String userId = FirebaseAuth.instance.currentUser!.uid;

  // Add this method to your existing GroupService class

  Future<void> recordSettlement(
    String groupId,
    String fromUserId,
    String toUserId,
    double amount, {
    bool isPartial = false,
  }) async {
    try {
      // Create a unique identifier for this settlement
      String settlementId = DateTime.now().millisecondsSinceEpoch.toString();

      // Format: fromUserId|toUserId|amount|settlementId|isPartial
      String paymentInfo =
          '$fromUserId|$toUserId|$amount|$settlementId|${isPartial ? 'partial' : 'full'}';

      await _firestore.collection('groups').doc(groupId).update({
        'settledPayments': FieldValue.arrayUnion([paymentInfo]),
      });
    } catch (e) {
      print('Error recording settlement: $e');
      throw e;
    }
  }

  Future<List<Map<String, dynamic>>> getDetailedSettlements(
    String groupId,
  ) async {
    try {
      final doc = await _firestore.collection('groups').doc(groupId).get();
      final data = doc.data();

      if (data != null && data.containsKey('settledPayments')) {
        List<String> settledPayments = List<String>.from(
          data['settledPayments'],
        );

        List<Map<String, dynamic>> detailedSettlements = [];

        for (String paymentInfo in settledPayments) {
          final parts = paymentInfo.split('|');
          if (parts.length >= 4) {
            detailedSettlements.add({
              'fromId': parts[0],
              'toId': parts[1],
              'amount': double.parse(parts[2]),
              'settlementId': parts[3],
              'isPartial': parts.length > 4 ? parts[4] == 'partial' : false,
              'timestamp': parts.length > 5 ? DateTime.parse(parts[5]) : null,
            });
          }
        }

        return detailedSettlements;
      }

      return [];
    } catch (e) {
      print('Error getting settlements: $e');
      throw e;
    }
  }

  Future<List<String>> getSettledPayments(String groupId) async {
    try {
      final doc = await _firestore.collection('groups').doc(groupId).get();
      final data = doc.data();

      if (data != null && data.containsKey('settledPayments')) {
        return List<String>.from(data['settledPayments']);
      }

      return [];
    } catch (e) {
      print('Error getting settled payments: $e');
      return [];
    }
  }

  Future<String> createGroup(String name, List<String> members) async {
    try {
      if (!members.contains(userId)) {
        members.add(userId);
      }

      Group group = Group(
        id: '',
        name: name,
        createdBy: userId,
        members: members,
        createdAt: DateTime.now(),
      );

      DocumentReference docRef = await _firestore
          .collection('groups')
          .add(group.toMap());

      for (String memberId in members) {
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(memberId).get();
        if (userDoc.exists) {
          UserProfile userProfile = UserProfile.fromFirestore(userDoc);
          List<String> updatedGroups = [...userProfile.groups, docRef.id];
          await _firestore.collection('users').doc(memberId).update({
            'groups': updatedGroups,
          });
        }
      }

      return docRef.id;
    } catch (e) {
      throw e;
    }
  }

  Stream<List<Group>> getUserGroups() {
    return _firestore
        .collection('groups')
        .where('members', arrayContains: userId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Group.fromFirestore(doc)).toList(),
        );
  }

  Future<Group?> getGroup(String groupId) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('groups').doc(groupId).get();
      if (doc.exists) {
        return Group.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw e;
    }
  }

  Future<void> addMemberToGroup(String groupId, String memberId) async {
    try {
      DocumentSnapshot groupDoc =
          await _firestore.collection('groups').doc(groupId).get();
      if (groupDoc.exists) {
        Group group = Group.fromFirestore(groupDoc);
        if (!group.members.contains(memberId)) {
          List<String> updatedMembers = [...group.members, memberId];
          await _firestore.collection('groups').doc(groupId).update({
            'members': updatedMembers,
          });

          DocumentSnapshot userDoc =
              await _firestore.collection('users').doc(memberId).get();
          if (userDoc.exists) {
            UserProfile userProfile = UserProfile.fromFirestore(userDoc);
            List<String> updatedGroups = [...userProfile.groups, groupId];
            await _firestore.collection('users').doc(memberId).update({
              'groups': updatedGroups,
            });
          }
        }
      }
    } catch (e) {
      throw e;
    }
  }

  Future<void> removeMemberFromGroup(String groupId, String memberId) async {
    try {
      DocumentSnapshot groupDoc =
          await _firestore.collection('groups').doc(groupId).get();
      if (groupDoc.exists) {
        Group group = Group.fromFirestore(groupDoc);
        if (group.members.contains(memberId)) {
          List<String> updatedMembers = [...group.members];
          updatedMembers.remove(memberId);
          await _firestore.collection('groups').doc(groupId).update({
            'members': updatedMembers,
          });

          // Update user's groups
          DocumentSnapshot userDoc =
              await _firestore.collection('users').doc(memberId).get();
          if (userDoc.exists) {
            UserProfile userProfile = UserProfile.fromFirestore(userDoc);
            List<String> updatedGroups = [...userProfile.groups];
            updatedGroups.remove(groupId);
            await _firestore.collection('users').doc(memberId).update({
              'groups': updatedGroups,
            });
          }
        }
      }
    } catch (e) {
      throw e;
    }
  }

  Future<void> deleteGroup(String groupId) async {
    try {
      DocumentSnapshot groupDoc =
          await _firestore.collection('groups').doc(groupId).get();
      if (groupDoc.exists) {
        Group group = Group.fromFirestore(groupDoc);

        for (String memberId in group.members) {
          DocumentSnapshot userDoc =
              await _firestore.collection('users').doc(memberId).get();
          if (userDoc.exists) {
            UserProfile userProfile = UserProfile.fromFirestore(userDoc);
            List<String> updatedGroups = [...userProfile.groups];
            updatedGroups.remove(groupId);
            await _firestore.collection('users').doc(memberId).update({
              'groups': updatedGroups,
            });
          }
        }

        await _firestore.collection('groups').doc(groupId).delete();
      }
    } catch (e) {
      throw e;
    }
  }
}
