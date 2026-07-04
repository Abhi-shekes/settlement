class FriendRequestStatus {
  static const String pending = 'pending';
  static const String accepted = 'accepted';
  static const String declined = 'declined';
}

class FriendRequestModel {
  final String id;
  final String fromUserId;
  final String fromName;
  final String fromEmail;
  final String? fromPhotoURL;
  final String toUserId;
  final String toName;
  final String toEmail;
  final String status;
  final DateTime createdAt;

  FriendRequestModel({
    required this.id,
    required this.fromUserId,
    required this.fromName,
    required this.fromEmail,
    this.fromPhotoURL,
    required this.toUserId,
    this.toName = '',
    this.toEmail = '',
    this.status = FriendRequestStatus.pending,
    required this.createdAt,
  });

  factory FriendRequestModel.fromMap(Map<String, dynamic> map) {
    return FriendRequestModel(
      id: map['id'] ?? '',
      fromUserId: map['fromUserId'] ?? '',
      fromName: map['fromName'] ?? '',
      fromEmail: map['fromEmail'] ?? '',
      fromPhotoURL: map['fromPhotoURL'],
      toUserId: map['toUserId'] ?? '',
      toName: map['toName'] ?? '',
      toEmail: map['toEmail'] ?? '',
      status: map['status'] ?? FriendRequestStatus.pending,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fromUserId': fromUserId,
      'fromName': fromName,
      'fromEmail': fromEmail,
      'fromPhotoURL': fromPhotoURL,
      'toUserId': toUserId,
      'toName': toName,
      'toEmail': toEmail,
      'status': status,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }
}
