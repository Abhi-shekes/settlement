import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';
import '../models/user_model.dart';
import '../models/friend_request_model.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // Pass the Firebase Web client ID explicitly as the serverClientId so Google
  // mints a valid ID token for Firebase across build variants. Without this,
  // sign-in can fail with ApiException: 10 (DEVELOPER_ERROR) / a null idToken.
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId:
        '558917768047-qh90bdr8r19k5a6mkcoj800ihr1bdkt2.apps.googleusercontent.com',
  );
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<FriendRequestModel> _incomingFriendRequests = [];
  List<FriendRequestModel> get incomingFriendRequests =>
      _incomingFriendRequests;

  List<FriendRequestModel> _outgoingFriendRequests = [];
  List<FriendRequestModel> get outgoingFriendRequests =>
      _outgoingFriendRequests;

  AuthService() {
    // Keep the app's auth gate in sync with Firebase's own auth state
    // (cold-start restoration, token expiry, sign-out from elsewhere).
    _auth.authStateChanges().listen((_) => notifyListeners());
  }

  /// Clears cached data (e.g. on sign-out).
  void reset() {
    _incomingFriendRequests = [];
    _outgoingFriendRequests = [];
    notifyListeners();
  }

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
      debugPrint('Error signing in with Google: $e');
      rethrow;
    }
  }

  Future<void> _createOrUpdateUserDocument(User user) async {
    final userDoc = await _firestore.collection('users').doc(user.uid).get();

    if (!userDoc.exists) {
      // Create new user document
      final userModel = UserModel(
        uid: user.uid,
        email: (user.email ?? '').toLowerCase(),
        displayName: user.displayName ?? '',
        photoURL: user.photoURL,
        friendCode: _generateFriendCode(),
        createdAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(user.uid).set(userModel.toMap());
    } else {
      // Update existing user document
      await _firestore.collection('users').doc(user.uid).update({
        'email': (user.email ?? '').toLowerCase(),
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
      debugPrint('Error getting user model: $e');
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
      debugPrint('Error getting user by friend code: $e');
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
      debugPrint('Error getting user by email: $e');
    }
    return null;
  }

  /// Sends a friend request to [target]. The friendship only forms once the
  /// other person accepts. Throws with a user-facing message on invalid cases.
  Future<void> sendFriendRequest(UserModel target) async {
    if (currentUser == null) return;
    final me = currentUser!;

    if (target.uid == me.uid) {
      throw Exception('You cannot add yourself.');
    }

    // Already friends?
    final myDoc = await _firestore.collection('users').doc(me.uid).get();
    final myModel = myDoc.exists ? UserModel.fromMap(myDoc.data()!) : null;
    if (myModel != null && myModel.friends.contains(target.uid)) {
      throw Exception('You are already friends with ${target.displayName}.');
    }

    // A pending request already exists in either direction? Query each
    // direction scoped to the current user (so it satisfies the security
    // rules, which only permit reading requests you're part of).
    final outgoing =
        await _firestore
            .collection('friend_requests')
            .where('fromUserId', isEqualTo: me.uid)
            .where('toUserId', isEqualTo: target.uid)
            .get();
    final incoming =
        await _firestore
            .collection('friend_requests')
            .where('fromUserId', isEqualTo: target.uid)
            .where('toUserId', isEqualTo: me.uid)
            .get();
    bool isPending(QuerySnapshot<Map<String, dynamic>> snap) =>
        snap.docs.any((d) => d.data()['status'] == FriendRequestStatus.pending);
    if (isPending(outgoing) || isPending(incoming)) {
      throw Exception('A friend request is already pending.');
    }

    final request = FriendRequestModel(
      id: const Uuid().v4(),
      fromUserId: me.uid,
      fromName: me.displayName ?? me.email ?? 'Someone',
      fromEmail: (me.email ?? '').toLowerCase(),
      fromPhotoURL: me.photoURL,
      toUserId: target.uid,
      toName: target.displayName,
      toEmail: target.email,
      status: FriendRequestStatus.pending,
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection('friend_requests')
        .doc(request.id)
        .set(request.toMap());

    _outgoingFriendRequests = [request, ..._outgoingFriendRequests];
    notifyListeners();
  }

  Future<void> loadIncomingFriendRequests() async {
    if (currentUser == null) return;
    try {
      final query =
          await _firestore
              .collection('friend_requests')
              .where('toUserId', isEqualTo: currentUser!.uid)
              .where('status', isEqualTo: FriendRequestStatus.pending)
              .orderBy('createdAt', descending: true)
              .get();
      _incomingFriendRequests =
          query.docs
              .map((doc) => FriendRequestModel.fromMap(doc.data()))
              .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading incoming friend requests: $e');
    }
  }

  Future<void> loadOutgoingFriendRequests() async {
    if (currentUser == null) return;
    try {
      final query =
          await _firestore
              .collection('friend_requests')
              .where('fromUserId', isEqualTo: currentUser!.uid)
              .where('status', isEqualTo: FriendRequestStatus.pending)
              .orderBy('createdAt', descending: true)
              .get();
      _outgoingFriendRequests =
          query.docs
              .map((doc) => FriendRequestModel.fromMap(doc.data()))
              .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading outgoing friend requests: $e');
    }
  }

  Future<void> acceptFriendRequest(FriendRequestModel request) async {
    if (currentUser == null) return;
    try {
      await _firestore.collection('friend_requests').doc(request.id).update({
        'status': FriendRequestStatus.accepted,
      });

      // Form the friendship in both directions.
      await _firestore.collection('users').doc(currentUser!.uid).update({
        'friends': FieldValue.arrayUnion([request.fromUserId]),
      });
      await _firestore.collection('users').doc(request.fromUserId).update({
        'friends': FieldValue.arrayUnion([currentUser!.uid]),
      });

      _incomingFriendRequests.removeWhere((r) => r.id == request.id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error accepting friend request: $e');
      rethrow;
    }
  }

  Future<void> declineFriendRequest(FriendRequestModel request) async {
    try {
      await _firestore.collection('friend_requests').doc(request.id).update({
        'status': FriendRequestStatus.declined,
      });
      _incomingFriendRequests.removeWhere((r) => r.id == request.id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error declining friend request: $e');
      rethrow;
    }
  }

  Future<void> cancelFriendRequest(FriendRequestModel request) async {
    try {
      await _firestore.collection('friend_requests').doc(request.id).delete();
      _outgoingFriendRequests.removeWhere((r) => r.id == request.id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error canceling friend request: $e');
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
      debugPrint('Error getting friends: $e');
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
      debugPrint('Error getting user by ID: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      notifyListeners(); // <-- add this
    } catch (e) {
      debugPrint('Error signing out: $e');
      rethrow;
    }
  }
}
