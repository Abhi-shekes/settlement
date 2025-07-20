import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import '../models/user_model.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _generateFriendCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        8,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      _isLoading = true;
      notifyListeners();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _isLoading = false;
        notifyListeners();
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      // Create or update user document in Firestore
      if (userCredential.user != null) {
        await _createOrUpdateUserDocument(userCredential.user!);
      }

      _isLoading = false;
      notifyListeners();
      return userCredential;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      print('Error signing in with Google: $e');
      rethrow;
    }
  }

  Future<void> _createOrUpdateUserDocument(User user) async {
    final userDoc = await _firestore.collection('users').doc(user.uid).get();

    if (!userDoc.exists) {
      // Create new user document
      final userModel = UserModel(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName ?? '',
        photoURL: user.photoURL,
        friendCode: _generateFriendCode(),
        createdAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(user.uid).set(userModel.toMap());
    } else {
      // Update existing user document
      await _firestore.collection('users').doc(user.uid).update({
        'displayName': user.displayName ?? '',
        'photoURL': user.photoURL,
      });
    }
  }

  Future<UserModel?> getCurrentUserModel() async {
    if (currentUser == null) return null;

    try {
      final doc =
          await _firestore.collection('users').doc(currentUser!.uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data()!);
      }
    } catch (e) {
      print('Error getting user model: $e');
    }
    return null;
  }

  Future<UserModel?> getUserByFriendCode(String friendCode) async {
    try {
      final query =
          await _firestore
              .collection('users')
              .where('friendCode', isEqualTo: friendCode.toUpperCase())
              .limit(1)
              .get();

      if (query.docs.isNotEmpty) {
        return UserModel.fromMap(query.docs.first.data());
      }
    } catch (e) {
      print('Error getting user by friend code: $e');
    }
    return null;
  }

  Future<UserModel?> getUserByEmail(String email) async {
    try {
      final query =
          await _firestore
              .collection('users')
              .where('email', isEqualTo: email.toLowerCase())
              .limit(1)
              .get();

      if (query.docs.isNotEmpty) {
        return UserModel.fromMap(query.docs.first.data());
      }
    } catch (e) {
      print('Error getting user by email: $e');
    }
    return null;
  }

  Future<void> addFriend(String friendId) async {
    if (currentUser == null) return;

    try {
      // Add friend to current user's friends list
      await _firestore.collection('users').doc(currentUser!.uid).update({
        'friends': FieldValue.arrayUnion([friendId]),
      });

      // Add current user to friend's friends list
      await _firestore.collection('users').doc(friendId).update({
        'friends': FieldValue.arrayUnion([currentUser!.uid]),
      });
    } catch (e) {
      print('Error adding friend: $e');
      rethrow;
    }
  }

  Future<List<UserModel>> getFriends() async {
    if (currentUser == null) return [];

    try {
      final userDoc =
          await _firestore.collection('users').doc(currentUser!.uid).get();
      if (!userDoc.exists) return [];

      final userData = UserModel.fromMap(userDoc.data()!);
      if (userData.friends.isEmpty) return [];

      final friendsQuery =
          await _firestore
              .collection('users')
              .where(FieldPath.documentId, whereIn: userData.friends)
              .get();

      return friendsQuery.docs
          .map((doc) => UserModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting friends: $e');
      return [];
    }
  }

  Future<UserModel?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting user by ID: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      notifyListeners(); // <-- add this
    } catch (e) {
      print('Error signing out: $e');
      rethrow;
    }
  }
}
