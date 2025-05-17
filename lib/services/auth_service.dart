import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_tracker/models/user_profile.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw e;
    }
  }

  Future<UserCredential> registerWithEmailAndPassword(
    String email,
    String password,
    String name,
  ) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _createUserProfile(result.user!.uid, email, name);

      return result;
    } catch (e) {
      throw e;
    }
  }

  Future<void> _createUserProfile(String uid, String email, String name) async {
    UserProfile userProfile = UserProfile(
      id: uid,
      email: email,
      name: name,
      groups: [],
      friends: [],
    );

    await _firestore.collection('users').doc(uid).set(userProfile.toMap());
  }

  Future<void> signOut() async {
    return await _auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    return await _auth.sendPasswordResetEmail(email: email);
  }

  Future<UserProfile?> getUserProfile(String uid) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserProfile.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  Future<void> updateUserProfile(UserProfile userProfile) async {
    try {
      await _firestore
          .collection('users')
          .doc(userProfile.id)
          .update(userProfile.toMap());
    } catch (e) {
      throw e;
    }
  }
}
