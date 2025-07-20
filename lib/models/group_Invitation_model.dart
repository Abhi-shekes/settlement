class GroupInvitationModel {
  final String id;
  final String groupId;
  final String groupName;
  final String invitedBy;
  final String invitedByName;
  final String inviteeEmail;
  final String? inviteePhone;
  final DateTime createdAt;
  final DateTime expiresAt;
  final InvitationStatus status;
  final String? message;

  GroupInvitationModel({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.invitedBy,
    required this.invitedByName,
    required this.inviteeEmail,
    this.inviteePhone,
    required this.createdAt,
    required this.expiresAt,
    this.status = InvitationStatus.pending,
    this.message,
  });

  factory GroupInvitationModel.fromMap(Map<String, dynamic> map) {
    return GroupInvitationModel(
      id: map['id'] ?? '',
      groupId: map['groupId'] ?? '',
      groupName: map['groupName'] ?? '',
      invitedBy: map['invitedBy'] ?? '',
      invitedByName: map['invitedByName'] ?? '',
      inviteeEmail: map['inviteeEmail'] ?? '',
      inviteePhone: map['inviteePhone'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(map['expiresAt'] ?? 0),
      status: InvitationStatus.values.firstWhere(
        (e) => e.toString() == 'InvitationStatus.${map['status']}',
        orElse: () => InvitationStatus.pending,
      ),
      message: map['message'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groupId': groupId,
      'groupName': groupName,
      'invitedBy': invitedBy,
      'invitedByName': invitedByName,
      'inviteeEmail': inviteeEmail,
      'inviteePhone': inviteePhone,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'expiresAt': expiresAt.millisecondsSinceEpoch,
      'status': status.toString().split('.').last,
      'message': message,
    };
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isPending => status == InvitationStatus.pending && !isExpired;
}

enum InvitationStatus { pending, accepted, declined, expired }
