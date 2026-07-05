import 'package:intl/intl.dart';

final NumberFormat _inr = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

final NumberFormat _inrDecimal = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 2,
);

/// Formats [amount] as Indian-grouped rupees, e.g. `₹1,24,500`.
///
/// - [decimals] shows paise (`₹1,24,500.50`) when the value isn't whole.
/// - [compact] abbreviates large values to `₹1.2L` / `₹3.4Cr` for tight tiles.
/// - [signed] prefixes an explicit `+` for positive values (money always shows
///   `-` for negatives regardless).
String formatCurrency(
  double amount, {
  bool decimals = false,
  bool compact = false,
  bool signed = false,
}) {
  final abs = amount.abs();

  String body;
  if (compact && abs >= 100000) {
    if (abs >= 10000000) {
      body = '₹${(abs / 10000000).toStringAsFixed(abs % 10000000 == 0 ? 0 : 1)}Cr';
    } else {
      body = '₹${(abs / 100000).toStringAsFixed(abs % 100000 == 0 ? 0 : 1)}L';
    }
  } else {
    final useDecimals = decimals && abs.roundToDouble() != abs;
    body = (useDecimals ? _inrDecimal : _inr).format(abs);
  }

  if (amount < 0) return '-$body';
  if (signed && amount > 0) return '+$body';
  return body;
}

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
