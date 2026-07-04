import 'package:flutter_test/flutter_test.dart';
import 'package:settlement/utils/money.dart';

// Sums the returned shares in integer paise so assertions are exact (no
// floating-point tolerance needed).
int _totalPaise(Map<String, double> shares) =>
    shares.values.fold(0, (sum, v) => sum + (v * 100).round());

void main() {
  group('splitEvenly', () {
    test('divides an evenly divisible amount into equal shares', () {
      final shares = splitEvenly(100, ['a', 'b', 'c', 'd']);
      expect(shares, {'a': 25.0, 'b': 25.0, 'c': 25.0, 'd': 25.0});
      expect(_totalPaise(shares), 10000);
    });

    test('shares always sum back to the exact total (no lost rupees)', () {
      // ₹100 across 3 people does not divide evenly.
      final shares = splitEvenly(100, ['a', 'b', 'c']);
      expect(_totalPaise(shares), 10000);
    });

    test('distributes the indivisible remainder to the earliest ids', () {
      final shares = splitEvenly(100, ['a', 'b', 'c']);
      expect(shares['a'], 33.34);
      expect(shares['b'], 33.33);
      expect(shares['c'], 33.33);
    });

    test('handles amounts with paise', () {
      final shares = splitEvenly(10.00, ['a', 'b', 'c']);
      expect(_totalPaise(shares), 1000);
      expect(shares['a'], 3.34);
      expect(shares['b'], 3.33);
      expect(shares['c'], 3.33);
    });

    test('a single participant owes the whole amount', () {
      expect(splitEvenly(99.99, ['a']), {'a': 99.99});
    });

    test('returns an empty map when there are no participants', () {
      expect(splitEvenly(100, []), <String, double>{});
    });

    test('handles a zero total', () {
      final shares = splitEvenly(0, ['a', 'b']);
      expect(shares, {'a': 0.0, 'b': 0.0});
      expect(_totalPaise(shares), 0);
    });
  });
}
