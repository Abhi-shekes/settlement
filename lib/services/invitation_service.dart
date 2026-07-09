import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:settlement/models/group_invitation_model.dart';
import 'package:settlement/models/group_model.dart';
import 'package:settlement/models/app_notification.dart';
import 'package:settlement/services/notification_emitter.dart';
import 'package:uuid/uuid.dart';

class InvitationService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<GroupInvitationModel> _receivedInvitations = [];
  List<GroupInvitationModel> get receivedInvitations => _receivedInvitations;

  List<GroupInvitationModel> _sentInvitations = [];
  List<GroupInvitationModel> get sentInvitations => _sentInvitations;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Clears cached data (e.g. on sign-out).
  void reset() {
    _receivedInvitations = [];
    _sentInvitations = [];
    notifyListeners();
  }

  Future<void> sendGroupInvitation({
    required String groupId,
    required String groupName,
    required String inviteeEmail,
    String? inviteePhone,
    String? message,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final currentUser = _auth.currentUser!;
      final invitation = GroupInvitationModel(
        id: const Uuid().v4(),
        groupId: groupId,
        groupName: groupName,
        invitedBy: currentUser.uid,
        invitedByName:
            currentUser.displayName ?? currentUser.email ?? 'Someone',
        inviteeEmail: inviteeEmail.toLowerCase().trim(),
        inviteePhone: inviteePhone?.trim(),
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 7)), // 7 days expiry
        message: message?.trim(),
      );

      await _firestore
          .collection('group_invitations')
          .doc(invitation.id)
          .set(invitation.toMap());

      // Notify the invitee if they already have an account.
      NotificationEmitter.sendToEmail(
        invitation.inviteeEmail,
        type: 'group_invite',
        category: NotificationCategory.groups,
        title: 'Group invitation',
        body: '${invitation.invitedByName} invited you to "$groupName"',
        data: {'groupId': groupId},
      );

      _sentInvitations.add(invitation);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Error sending invitation: $e');
      rethrow;
    }
  }

  Future<void> loadReceivedInvitations() async {
    if (_auth.currentUser == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      final userEmail = _auth.currentUser!.email!.toLowerCase();
      final query =
          await _firestore
              .collection('group_invitations')
              .where('inviteeEmail', isEqualTo: userEmail)
              .where('status', isEqualTo: 'pending')
              .orderBy('createdAt', descending: true)
              .get();

      _receivedInvitations =
          query.docs
              .map((doc) => GroupInvitationModel.fromMap(doc.data()))
              .where((invitation) => invitation.isPending)
              .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Error loading received invitations: $e');
    }
  }

  Future<void> loadSentInvitations() async {
    if (_auth.currentUser == null) return;

    try {
      final query =
          await _firestore
              .collection('group_invitations')
              .where('invitedBy', isEqualTo: _auth.currentUser!.uid)
              .orderBy('createdAt', descending: true)
              .get();

      _sentInvitations =
          query.docs
              .map((doc) => GroupInvitationModel.fromMap(doc.data()))
              .toList();

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading sent invitations: $e');
    }
  }

  Future<void> acceptInvitation(String invitationId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final invitation = _receivedInvitations.firstWhere(
        (inv) => inv.id == invitationId,
      );

      // Reject expired invitations.
      if (invitation.isExpired) {
        await _firestore
            .collection('group_invitations')
            .doc(invitationId)
            .update({'status': 'expired'});
        _receivedInvitations.removeWhere((inv) => inv.id == invitationId);
        _isLoading = false;
        notifyListeners();
        throw Exception('This invitation has expired.');
      }

      // Verify the group still exists and the user isn't already a member.
      final groupDoc =
          await _firestore.collection('groups').doc(invitation.groupId).get();
      if (!groupDoc.exists) {
        _receivedInvitations.removeWhere((inv) => inv.id == invitationId);
        _isLoading = false;
        notifyListeners();
        throw Exception('This group no longer exists.');
      }
      final group = GroupModel.fromMap(groupDoc.data()!);
      if (group.allMemberIds.contains(_auth.currentUser!.uid)) {
        await _firestore
            .collection('group_invitations')
            .doc(invitationId)
            .update({'status': 'accepted'});
        _receivedInvitations.removeWhere((inv) => inv.id == invitationId);
        _isLoading = false;
        notifyListeners();
        return; // Already a member — nothing more to do.
      }

      // Update invitation status
      await _firestore.collection('group_invitations').doc(invitationId).update(
        {'status': 'accepted'},
      );

      // Add user to group
      await _firestore.collection('groups').doc(invitation.groupId).update({
        'memberIds': FieldValue.arrayUnion([_auth.currentUser!.uid]),
      });

      // Add group to user's groups list
      await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
        'groups': FieldValue.arrayUnion([invitation.groupId]),
      });

      // Tell the existing members that someone joined.
      final joinerName = _auth.currentUser?.displayName ?? 'Someone';
      NotificationEmitter.sendToAll(
        group.allMemberIds,
        type: 'group_member',
        category: NotificationCategory.groups,
        title: group.name,
        body: '$joinerName joined "${group.name}"',
        data: {'groupId': invitation.groupId},
      );

      // Remove from received invitations
      _receivedInvitations.removeWhere((inv) => inv.id == invitationId);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Error accepting invitation: $e');
      rethrow;
    }
  }

  Future<void> declineInvitation(String invitationId) async {
    try {
      await _firestore.collection('group_invitations').doc(invitationId).update(
        {'status': 'declined'},
      );

      _receivedInvitations.removeWhere((inv) => inv.id == invitationId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error declining invitation: $e');
      rethrow;
    }
  }

  Future<void> cancelInvitation(String invitationId) async {
    try {
      await _firestore
          .collection('group_invitations')
          .doc(invitationId)
          .delete();

      _sentInvitations.removeWhere((inv) => inv.id == invitationId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error canceling invitation: $e');
      rethrow;
    }
  }
}
