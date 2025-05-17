import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String id;
  final String email;
  final String name;
  final String? photoUrl;
  final List<String> groups;
  final List<String> friends;

  UserProfile({
    required this.id,
    required this.email,
    required this.name,
    this.photoUrl,
    required this.groups,
    required this.friends,
  });

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return UserProfile(
      id: doc.id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      photoUrl: data['photoUrl'],
      groups: List<String>.from(data['groups'] ?? []),
      friends: List<String>.from(data['friends'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'photoUrl': photoUrl,
      'groups': groups,
      'friends': friends,
    };
  }
}
