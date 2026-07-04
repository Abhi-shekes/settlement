import 'package:flutter_test/flutter_test.dart';
import 'package:settlement/models/expense_model.dart';
import 'package:settlement/utils/transaction_parser.dart';

void main() {
  group('TransactionParser', () {
    test('parses a typical debit SMS with amount, merchant, date, category', () {
      final r = TransactionParser.parse(
        'Rs.2,000.00 debited from A/c XX1234 on 04-Jul-25 at AMAZON. Avl Bal Rs.5000',
      );
      expect(r.isTransaction, isTrue);
      expect(r.amount, 2000.00);
      expect(r.direction, TransactionDirection.debit);
      expect(r.merchant, 'Amazon');
      expect(r.category, ExpenseCategory.shopping);
      expect(r.date, DateTime(2025, 7, 4));
    });

    test('parses a credit-card spend with INR and slash date', () {
      final r = TransactionParser.parse(
        'INR 450 spent on your HDFC Credit Card at SWIGGY on 03/07/2026',
      );
      expect(r.amount, 450);
      expect(r.direction, TransactionDirection.debit);
      expect(r.merchant, 'Swiggy');
      expect(r.category, ExpenseCategory.food);
      expect(r.date, DateTime(2026, 7, 3));
    });

    test('recognises a credit message', () {
      final r = TransactionParser.parse(
        'Your a/c XX9876 credited with Rs 10000 on 2026-07-01',
      );
      expect(r.amount, 10000);
      expect(r.direction, TransactionDirection.credit);
      expect(r.isDebit, isFalse);
      expect(r.date, DateTime(2026, 7, 1));
    });

    test('parses a UPI payment with ₹ symbol', () {
      final r = TransactionParser.parse('Paid ₹199 to NETFLIX via UPI');
      expect(r.amount, 199);
      expect(r.merchant, 'Netflix');
      expect(r.category, ExpenseCategory.entertainment);
    });

    test('returns non-transaction for unrelated text', () {
      final r = TransactionParser.parse('Your OTP is 123456. Do not share it.');
      expect(r.isTransaction, isFalse);
      expect(r.amount, isNull);
    });

    test('handles missing date by leaving it null', () {
      final r = TransactionParser.parse('Rs 300 debited at Uber');
      expect(r.amount, 300);
      expect(r.merchant, 'Uber');
      expect(r.category, ExpenseCategory.travel);
      expect(r.date, isNull);
    });
  });
}
