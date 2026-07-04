/// Splits [total] evenly across [ids], working in paise (integer hundredths)
/// so the returned shares always sum back to [total] exactly — no floating
/// point drift and no lost/created rupees. Any indivisible remainder (e.g.
/// ₹100 across 3 people) is distributed one paisa at a time to the first ids.
Map<String, double> splitEvenly(double total, List<String> ids) {
  if (ids.isEmpty) return {};

  final totalPaise = (total * 100).round();
  final base = totalPaise ~/ ids.length;
  var remainder = totalPaise - base * ids.length;

  final result = <String, double>{};
  for (final id in ids) {
    var paise = base;
    if (remainder > 0) {
      paise += 1;
      remainder -= 1;
    }
    result[id] = paise / 100;
  }
  return result;
}
