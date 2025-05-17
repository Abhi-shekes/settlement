import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_tracker/models/user_profile.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String userId = FirebaseAuth.instance.currentUser!.uid;

  Future<List<UserProfile>> searchUsersByEmail(String email) async {
    try {
      QuerySnapshot snapshot =
          await _firestore
              .collection('users')
              .where('email', isEqualTo: email)
              .get();

      return snapshot.docs
          .map((doc) => UserProfile.fromFirestore(doc))
          .where((user) => user.id != userId) // Exclude current user
          .toList();
    } catch (e) {
      throw e;
    }
  }

  Future<UserProfile?> getUserProfile(String memberId) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(memberId).get();
      if (doc.exists) {
        return UserProfile.fromFirestore(doc);
      } else {
        return null;
      }
    } catch (e) {
      throw e;
    }
  }

  Future<void> addFriend(String friendId) async {
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        UserProfile userProfile = UserProfile.fromFirestore(userDoc);
        if (!userProfile.friends.contains(friendId)) {
          List<String> updatedFriends = [...userProfile.friends, friendId];
          await _firestore.collection('users').doc(userId).update({
            'friends': updatedFriends,
          });
        }
      }

      DocumentSnapshot friendDoc =
          await _firestore.collection('users').doc(friendId).get();
      if (friendDoc.exists) {
        UserProfile friendProfile = UserProfile.fromFirestore(friendDoc);
        if (!friendProfile.friends.contains(userId)) {
          List<String> updatedFriends = [...friendProfile.friends, userId];
          await _firestore.collection('users').doc(friendId).update({
            'friends': updatedFriends,
          });
        }
      }
    } catch (e) {
      throw e;
    }
  }

  Future<void> removeFriend(String friendId) async {
    try {
      // Update current user's friends list
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        UserProfile userProfile = UserProfile.fromFirestore(userDoc);
        if (userProfile.friends.contains(friendId)) {
          List<String> updatedFriends = [...userProfile.friends];
          updatedFriends.remove(friendId);
          await _firestore.collection('users').doc(userId).update({
            'friends': updatedFriends,
          });
        }
      }

      DocumentSnapshot friendDoc =
          await _firestore.collection('users').doc(friendId).get();
      if (friendDoc.exists) {
        UserProfile friendProfile = UserProfile.fromFirestore(friendDoc);
        if (friendProfile.friends.contains(userId)) {
          List<String> updatedFriends = [...friendProfile.friends];
          updatedFriends.remove(userId);
          await _firestore.collection('users').doc(friendId).update({
            'friends': updatedFriends,
          });
        }
      }
    } catch (e) {
      throw e;
    }
  }

  // In FriendService
  Future<Map<String, UserProfile>> getUsersByIds(List<String> userIds) async {
    try {
      final Map<String, UserProfile> users = {};
      for (String userId in userIds) {
        final doc = await _firestore.collection('users').doc(userId).get();
        if (doc.exists) {
          users[userId] = UserProfile.fromFirestore(doc);
        }
      }
      return users;
    } catch (e) {
      throw e;
    }
  }

  Future<List<UserProfile>> getFriends() async {
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        UserProfile userProfile = UserProfile.fromFirestore(userDoc);
        List<UserProfile> friends = [];

        for (String friendId in userProfile.friends) {
          DocumentSnapshot friendDoc =
              await _firestore.collection('users').doc(friendId).get();
          if (friendDoc.exists) {
            friends.add(UserProfile.fromFirestore(friendDoc));
          }
        }

        return friends;
      }
      return [];
    } catch (e) {
      throw e;
    }
  }
}
