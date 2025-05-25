class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? photoURL;
  final String friendCode;
  final DateTime createdAt;
  final List<String> friends;
  final List<String> groups;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoURL,
    required this.friendCode,
    required this.createdAt,
    this.friends = const [],
    this.groups = const [],
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      photoURL: map['photoURL'],
      friendCode: map['friendCode'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      friends: List<String>.from(map['friends'] ?? []),
      groups: List<String>.from(map['groups'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'friendCode': friendCode,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'friends': friends,
      'groups': groups,
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoURL,
    String? friendCode,
    DateTime? createdAt,
    List<String>? friends,
    List<String>? groups,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      friendCode: friendCode ?? this.friendCode,
      createdAt: createdAt ?? this.createdAt,
      friends: friends ?? this.friends,
      groups: groups ?? this.groups,
    );
  }
}
