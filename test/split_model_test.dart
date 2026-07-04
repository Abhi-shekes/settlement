import 'package:flutter_test/flutter_test.dart';
import 'package:settlement/models/split_model.dart';

SplitModel _split({
  Map<String, String> status = const {},
  List<SettlementModel> settlements = const [],
}) {
  return SplitModel(
    id: 's1',
    title: 'Dinner',
    description: '',
    totalAmount: 300,
    paidBy: 'payer',
    participants: const ['payer', 'a', 'b'],
    splitType: SplitType.equal,
    splitAmounts: const {'payer': 100, 'a': 100, 'b': 100},
    createdAt: DateTime(2026, 1, 1),
    participantStatus: status,
    settlements: settlements,
  );
}

SettlementModel _settlement({
  required String from,
  required String to,
  required double amount,
  required String status,
  String? recordedBy,
}) {
  return SettlementModel(
    id: 'set-$from-$to-$amount',
    fromUserId: from,
    toUserId: to,
    amount: amount,
    settledAt: DateTime(2026, 1, 2),
    status: status,
    recordedBy: recordedBy,
  );
}

void main() {
  group('SplitModel participant approval', () {
    test('the payer is always accepted', () {
      expect(_split().hasAcceptedShare('payer'), isTrue);
    });

    test('a pending participant has not accepted their share', () {
      final s = _split(status: {'a': ParticipantStatus.pending});
      expect(s.hasAcceptedShare('a'), isFalse);
      expect(s.isAwaitingApprovalFrom('a'), isTrue);
    });

    test('an accepted participant has accepted', () {
      final s = _split(status: {'a': ParticipantStatus.accepted});
      expect(s.hasAcceptedShare('a'), isTrue);
    });

    test('legacy splits (no status map) default participants to accepted', () {
      expect(_split().hasAcceptedShare('a'), isTrue);
    });

    test('pendingParticipants lists only unapproved non-payers', () {
      final s = _split(
        status: {
          'a': ParticipantStatus.pending,
          'b': ParticipantStatus.accepted,
        },
      );
      expect(s.pendingParticipants, ['a']);
    });
  });

  group('SplitModel settlement accounting', () {
    test('only confirmed settlements reduce what is owed', () {
      final s = _split(
        status: {'a': ParticipantStatus.accepted},
        settlements: [
          _settlement(
            from: 'a',
            to: 'payer',
            amount: 40,
            status: SettlementStatus.pending,
          ),
        ],
      );
      // Pending settlement does not count yet.
      expect(s.getTotalSettledAmount('a'), 0);
      expect(s.getRemainingAmount('a'), 100);
    });

    test('a confirmed settlement reduces the remaining amount', () {
      final s = _split(
        status: {'a': ParticipantStatus.accepted},
        settlements: [
          _settlement(
            from: 'a',
            to: 'payer',
            amount: 40,
            status: SettlementStatus.confirmed,
          ),
        ],
      );
      expect(s.getTotalSettledAmount('a'), 40);
      expect(s.getRemainingAmount('a'), 60);
    });
  });

  group('SettlementModel.confirmerId', () {
    test('the counterparty confirms when the ower records it', () {
      final st = _settlement(
        from: 'a',
        to: 'payer',
        amount: 50,
        status: SettlementStatus.pending,
        recordedBy: 'a',
      );
      expect(st.confirmerId, 'payer');
    });

    test('the counterparty confirms when the payee records it', () {
      final st = _settlement(
        from: 'a',
        to: 'payer',
        amount: 50,
        status: SettlementStatus.pending,
        recordedBy: 'payer',
      );
      expect(st.confirmerId, 'a');
    });

    test('falls back to the payee when recordedBy is unknown (legacy)', () {
      final st = _settlement(
        from: 'a',
        to: 'payer',
        amount: 50,
        status: SettlementStatus.confirmed,
      );
      expect(st.confirmerId, 'payer');
    });
  });
}
