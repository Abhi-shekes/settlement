import 'package:flutter_test/flutter_test.dart';
import 'package:settlement/models/user_model.dart';
import 'package:settlement/utils/friend_match.dart';

UserModel _friend(String uid, String name, {String email = ''}) => UserModel(
  uid: uid,
  email: email.isEmpty ? '$name@x.com'.toLowerCase() : email,
  displayName: name,
  friendCode: uid,
  createdAt: DateTime(2024),
);

void main() {
  final friends = [
    _friend('1', 'Rahul Sharma'),
    _friend('2', 'Priya'),
    _friend('3', 'Sam Wilson', email: 'sam@work.com'),
  ];

  test('matches by first name, case-insensitively', () {
    final r = resolveFriendNames(friends, ['rahul', 'PRIYA']);
    expect(r.matched.map((f) => f.uid), ['1', '2']);
    expect(r.unmatched, isEmpty);
  });

  test('matches by full display name and by email', () {
    final r = resolveFriendNames(friends, ['Rahul Sharma', 'sam@work.com']);
    expect(r.matched.map((f) => f.uid), ['1', '3']);
  });

  test('reports names that do not resolve', () {
    final r = resolveFriendNames(friends, ['Rahul', 'Unknown Person']);
    expect(r.matched.map((f) => f.uid), ['1']);
    expect(r.unmatched, ['Unknown Person']);
  });

  test('never matches the same friend twice', () {
    final r = resolveFriendNames(friends, ['Rahul', 'Rahul Sharma']);
    expect(r.matched.map((f) => f.uid), ['1']);
    expect(r.unmatched, ['Rahul Sharma']);
  });
}
