enum GroupRole { admin, member }

class GroupModel {
  final String id;
  final String name;
  final String description;
  final String adminId;
  final List<String> memberIds;
  final DateTime createdAt;
  final String? imageUrl;
  final List<String> expenseIds;
  final Map<String, double> balances; // User ID -> Balance (positive = owed to them, negative = they owe)

  GroupModel({
    required this.id,
    required this.name,
    required this.description,
    required this.adminId,
    required this.memberIds,
    required this.createdAt,
    this.imageUrl,
    this.expenseIds = const [],
    this.balances = const {},
  });

  factory GroupModel.fromMap(Map<String, dynamic> map) {
    return GroupModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      adminId: map['adminId'] ?? '',
      memberIds: List<String>.from(map['memberIds'] ?? []),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      imageUrl: map['imageUrl'],
      expenseIds: List<String>.from(map['expenseIds'] ?? []),
      balances: Map<String, double>.from(
        (map['balances'] ?? {}).map(
          (key, value) => MapEntry(key, (value ?? 0).toDouble()),
        ),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'adminId': adminId,
      'memberIds': memberIds,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'imageUrl': imageUrl,
      'expenseIds': expenseIds,
      'balances': balances,
    };
  }

  List<String> get allMemberIds => [adminId, ...memberIds];

  GroupRole getUserRole(String userId) {
    return userId == adminId ? GroupRole.admin : GroupRole.member;
  }

  double getUserBalance(String userId) {
    return balances[userId] ?? 0.0;
  }

  String getFormattedBalance(String userId) {
    final balance = getUserBalance(userId);
    if (balance > 0) {
      return 'Gets back ₹${balance.toStringAsFixed(2)}';
    } else if (balance < 0) {
      return 'Owes ₹${(-balance).toStringAsFixed(2)}';
    } else {
      return 'Settled up';
    }
  }
}
