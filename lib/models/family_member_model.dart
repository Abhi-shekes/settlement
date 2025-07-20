class FamilyMemberModel {
  final String id;
  final String userId;
  final String name;
  final String email;
  final String? phone;
  final FamilyRole role;
  final DateTime addedAt;
  final String? photoUrl;
  final bool isActive;

  FamilyMemberModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
    required this.addedAt,
    this.photoUrl,
    this.isActive = true,
  });

  factory FamilyMemberModel.fromMap(Map<String, dynamic> map) {
    return FamilyMemberModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'],
      role: FamilyRole.values.firstWhere(
        (e) => e.toString() == 'FamilyRole.${map['role']}',
        orElse: () => FamilyRole.member,
      ),
      addedAt: DateTime.fromMillisecondsSinceEpoch(map['addedAt'] ?? 0),
      photoUrl: map['photoUrl'],
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role.toString().split('.').last,
      'addedAt': addedAt.millisecondsSinceEpoch,
      'photoUrl': photoUrl,
      'isActive': isActive,
    };
  }

  String get roleDisplayName {
    switch (role) {
      case FamilyRole.parent:
        return 'Parent';
      case FamilyRole.spouse:
        return 'Spouse';
      case FamilyRole.child:
        return 'Child';
      case FamilyRole.sibling:
        return 'Sibling';
      case FamilyRole.grandparent:
        return 'Grandparent';
      case FamilyRole.other:
        return 'Other';
      case FamilyRole.member:
        return 'Member';
    }
  }
}

enum FamilyRole { parent, spouse, child, sibling, grandparent, other, member }
