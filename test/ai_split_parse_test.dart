import 'package:flutter_test/flutter_test.dart';
import 'package:settlement/models/split_model.dart';
import 'package:settlement/services/ai_service.dart';

void main() {
  final ai = AiService();

  test('parses an equal split', () {
    final draft = ai.parseSplitArgs({
      'title': 'Dinner',
      'amount': 1200,
      'splitType': 'equal',
      'participants': ['Rahul', 'Priya'],
    });
    expect(draft, isNotNull);
    expect(draft!.title, 'Dinner');
    expect(draft.totalAmount, 1200);
    expect(draft.splitType, SplitType.equal);
    expect(draft.participantNames, ['Rahul', 'Priya']);
    expect(draft.shares, isNull);
  });

  test('parses an unequal split with shares', () {
    final draft = ai.parseSplitArgs({
      'title': 'Trip',
      'amount': 900,
      'splitType': 'unequal',
      'participants': ['Sam'],
      'shares': [
        {'name': 'You', 'amount': 600},
        {'name': 'Sam', 'amount': 300},
      ],
    });
    expect(draft, isNotNull);
    expect(draft!.splitType, SplitType.unequal);
    expect(draft.shares, {'You': 600.0, 'Sam': 300.0});
  });

  test('falls back to equal when unequal has no usable shares', () {
    final draft = ai.parseSplitArgs({
      'title': 'Cab',
      'amount': 300,
      'splitType': 'unequal',
      'participants': ['Sam'],
      'shares': <Object?>[],
    });
    expect(draft!.splitType, SplitType.equal);
    expect(draft.shares, isNull);
  });

  test('returns null without an amount or without participants', () {
    expect(
      ai.parseSplitArgs({
        'title': 'X',
        'participants': ['Rahul'],
      }),
      isNull,
    );
    expect(
      ai.parseSplitArgs({
        'title': 'X',
        'amount': 500,
        'participants': <Object?>[],
      }),
      isNull,
    );
  });
}
