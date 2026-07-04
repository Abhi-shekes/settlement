enum SplitType { equal, unequal }

/// Per-participant approval of their share of a split. A share only becomes a
/// real debt (counted in balances) once that participant has `accepted` it.
class ParticipantStatus {
  static const String pending = 'pending';
  static const String accepted = 'accepted';
  static const String declined = 'declined';
}

/// Lifecycle of a recorded settlement. A settlement only affects balances once
/// the counterparty has `confirmed` it.
class SettlementStatus {
  static const String pending = 'pending';
  static const String confirmed = 'confirmed';
  static const String rejected = 'rejected';
}

class SplitModel {
  final String id;
  final String title;
  final String description;
  final double totalAmount; // Total amount in INR
  final String paidBy; // User ID who paid
  final List<String> participants; // User IDs
  final SplitType splitType;
  final Map<String, double> splitAmounts; // User ID -> Amount owed
  final DateTime createdAt;
  final String? groupId;
  final String notes;
  final bool isFullySettled;
  final List<SettlementModel> settlements;

  /// User ID -> ParticipantStatus. The payer is implicitly accepted; every
  /// other participant starts `pending` until they approve their share.
  final Map<String, String> participantStatus;

  SplitModel({
    required this.id,
    required this.title,
    required this.description,
    required this.totalAmount,
    required this.paidBy,
    required this.participants,
    required this.splitType,
    required this.splitAmounts,
    required this.createdAt,
    this.groupId,
    this.notes = '',
    this.isFullySettled = false,
    this.settlements = const [],
    this.participantStatus = const {},
  });

  factory SplitModel.fromMap(Map<String, dynamic> map) {
    return SplitModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      totalAmount: (map['totalAmount'] ?? 0).toDouble(),
      paidBy: map['paidBy'] ?? '',
      participants: List<String>.from(map['participants'] ?? []),
      splitType: SplitType.values.firstWhere(
        (e) => e.toString() == map['splitType'],
        orElse: () => SplitType.equal,
      ),
      splitAmounts: Map<String, double>.from(
        (map['splitAmounts'] ?? {}).map(
          (key, value) => MapEntry(key, (value ?? 0).toDouble()),
        ),
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      groupId: map['groupId'],
      notes: map['notes'] ?? '',
      isFullySettled: map['isFullySettled'] ?? false,
      settlements:
          (map['settlements'] as List<dynamic>? ?? [])
              .map((e) => SettlementModel.fromMap(e))
              .toList(),
      participantStatus: Map<String, String>.from(
        map['participantStatus'] ?? {},
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'totalAmount': totalAmount,
      'paidBy': paidBy,
      'participants': participants,
      'splitType': splitType.toString(),
      'splitAmounts': splitAmounts,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'groupId': groupId,
      'notes': notes,
      'isFullySettled': isFullySettled,
      'settlements': settlements.map((e) => e.toMap()).toList(),
      'participantStatus': participantStatus,
    };
  }

  String get formattedTotalAmount => '₹${totalAmount.toInt()}';

  /// The payer is always accepted. Legacy splits (no participantStatus map)
  /// default their participants to accepted so old data keeps working.
  String statusFor(String userId) {
    if (userId == paidBy) return ParticipantStatus.accepted;
    return participantStatus[userId] ?? ParticipantStatus.accepted;
  }

  bool hasAcceptedShare(String userId) =>
      statusFor(userId) == ParticipantStatus.accepted;

  bool isAwaitingApprovalFrom(String userId) =>
      statusFor(userId) == ParticipantStatus.pending;

  /// Participants (excluding the payer) who still need to approve their share.
  List<String> get pendingParticipants =>
      participants
          .where(
            (p) => p != paidBy && statusFor(p) == ParticipantStatus.pending,
          )
          .toList();

  double getAmountOwedBy(String userId) {
    return splitAmounts[userId] ?? 0.0;
  }

  /// Only settlements the counterparty has confirmed reduce what is owed.
  double getTotalSettledAmount(String userId) {
    return settlements
        .where(
          (s) =>
              s.fromUserId == userId && s.status == SettlementStatus.confirmed,
        )
        .fold(0.0, (sum, s) => sum + s.amount);
  }

  double getRemainingAmount(String userId) {
    return getAmountOwedBy(userId) - getTotalSettledAmount(userId);
  }
}

class SettlementModel {
  final String id;
  final String? splitId; // Make it nullable
  final String fromUserId;
  final String toUserId;
  final double amount;
  final DateTime settledAt;
  final String notes;
  final String status; // SettlementStatus
  final String? recordedBy; // who recorded it; the OTHER party confirms

  SettlementModel({
    required this.id,
    this.splitId, // Optional
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
    required this.settledAt,
    this.notes = '',
    this.status = SettlementStatus.confirmed,
    this.recordedBy,
  });

  factory SettlementModel.fromMap(Map<String, dynamic> map) {
    return SettlementModel(
      id: map['id'] ?? '',
      splitId: map['splitId'], // Handle nullable
      fromUserId: map['fromUserId'] ?? '',
      toUserId: map['toUserId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      settledAt: DateTime.fromMillisecondsSinceEpoch(map['settledAt'] ?? 0),
      notes: map['notes'] ?? '',
      // Legacy settlements (no status) are treated as already confirmed.
      status: map['status'] ?? SettlementStatus.confirmed,
      recordedBy: map['recordedBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'splitId': splitId, // Include even if null
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'amount': amount,
      'settledAt': settledAt.millisecondsSinceEpoch,
      'notes': notes,
      'status': status,
      'recordedBy': recordedBy,
    };
  }

  /// The party who must confirm this settlement: whichever side did NOT record
  /// it. Falls back to the payee when recordedBy is unknown (legacy).
  String get confirmerId =>
      recordedBy == null
          ? toUserId
          : (recordedBy == fromUserId ? toUserId : fromUserId);

  bool get isPending => status == SettlementStatus.pending;

  SettlementModel copyWith({String? status}) {
    return SettlementModel(
      id: id,
      splitId: splitId,
      fromUserId: fromUserId,
      toUserId: toUserId,
      amount: amount,
      settledAt: settledAt,
      notes: notes,
      status: status ?? this.status,
      recordedBy: recordedBy,
    );
  }

  String get formattedAmount => '₹${amount.toInt()}';
}
