import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:settlement/models/group_Invitation_model.dart';
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

      _sentInvitations.add(invitation);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      print('Error sending invitation: $e');
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
      print('Error loading received invitations: $e');
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
      print('Error loading sent invitations: $e');
    }
  }

  Future<void> acceptInvitation(String invitationId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final invitation = _receivedInvitations.firstWhere(
        (inv) => inv.id == invitationId,
      );

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

      // Remove from received invitations
      _receivedInvitations.removeWhere((inv) => inv.id == invitationId);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      print('Error accepting invitation: $e');
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
      print('Error declining invitation: $e');
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
      print('Error canceling invitation: $e');
      rethrow;
    }
  }
}
