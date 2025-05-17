import 'package:cloud_firestore/cloud_firestore.dart';

class Group {
  final String id;
  final String name;
  final String createdBy;
  final List<String> members;
  final DateTime createdAt;

  Group({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.members,
    required this.createdAt,
  });

  factory Group.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return Group(
      id: doc.id,
      name: data['name'] ?? '',
      createdBy: data['createdBy'] ?? '',
      members: List<String>.from(data['members'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'createdBy': createdBy,
      'members': members,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  @override
  bool operator ==(Object other) {
    return other is Group && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
