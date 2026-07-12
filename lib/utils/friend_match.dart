import '../models/user_model.dart';

/// Outcome of resolving AI-drafted participant names to real friend accounts.
class FriendMatchResult {
  /// Friends resolved from the given names, in the order the names appeared,
  /// de-duplicated (a friend is never matched twice).
  final List<UserModel> matched;

  /// Names that did not resolve to any friend (unknown or ambiguous).
  final List<String> unmatched;

  const FriendMatchResult({required this.matched, required this.unmatched});
}

/// Resolves free-text participant [names] (as produced by the assistant) to the
/// user's [friends]. Matching is forgiving so the model's phrasing lines up
/// with stored accounts: it tries, in order, an exact display-name/email match,
/// then a first-name match, then a substring match — all case-insensitive.
///
/// Pure and side-effect free so it can be unit-tested without Firebase.
FriendMatchResult resolveFriendNames(
  List<UserModel> friends,
  List<String> names,
) {
  final matched = <UserModel>[];
  final usedIds = <String>{};
  final unmatched = <String>[];

  String norm(String s) => s.trim().toLowerCase();
  String firstName(String s) => norm(s).split(RegExp(r'\s+')).first;

  for (final rawName in names) {
    final name = norm(rawName);
    if (name.isEmpty) continue;

    UserModel? hit;
    for (final f in friends) {
      if (usedIds.contains(f.uid)) continue;
      if (norm(f.displayName) == name || norm(f.email) == name) {
        hit = f;
        break;
      }
    }
    hit ??= friends
        .where((f) => !usedIds.contains(f.uid))
        .where((f) => firstName(f.displayName) == name)
        .fold<UserModel?>(null, (prev, f) => prev ?? f);
    hit ??= friends
        .where((f) => !usedIds.contains(f.uid))
        .where(
          (f) =>
              norm(f.displayName).contains(name) ||
              name.contains(firstName(f.displayName)),
        )
        .fold<UserModel?>(null, (prev, f) => prev ?? f);

    if (hit != null) {
      matched.add(hit);
      usedIds.add(hit.uid);
    } else {
      unmatched.add(rawName.trim());
    }
  }

  return FriendMatchResult(matched: matched, unmatched: unmatched);
}
