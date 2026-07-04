import '../models/expense_model.dart';

/// The direction of money implied by a transaction message.
enum TransactionDirection { debit, credit, unknown }

/// A transaction extracted from a bank/card/wallet SMS or email. Any field may
/// be null when the message didn't contain it; [amount] being null means the
/// message wasn't recognisably a transaction.
class ParsedTransaction {
  final double? amount;
  final String? merchant;
  final DateTime? date;
  final TransactionDirection direction;
  final ExpenseCategory category;

  /// The raw message this was parsed from, kept for the review UI.
  final String source;

  ParsedTransaction({
    required this.amount,
    required this.merchant,
    required this.date,
    required this.direction,
    required this.category,
    required this.source,
  });

  bool get isTransaction => amount != null && amount! > 0;
  bool get isDebit => direction == TransactionDirection.debit;
}

/// Extracts structured transaction data from the free-text of a bank, credit
/// card, or wallet SMS/email. Tuned for common Indian message formats but
/// tolerant of variations. Pure Dart, so it runs on every platform and is
/// unit-testable — the same logic serves both pasted messages and (on Android)
/// auto-scanned SMS.
class TransactionParser {
  // Rs. 1,234.56  /  INR 1234  /  ₹ 999.00
  static final RegExp _amountRe = RegExp(
    r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  static final RegExp _debitRe = RegExp(
    r'\b(debited|spent|paid|withdrawn|purchase|debit|sent|deducted)\b',
    caseSensitive: false,
  );
  static final RegExp _creditRe = RegExp(
    r'\b(credited|received|refund|credit|deposited|cashback)\b',
    caseSensitive: false,
  );

  // Merchant after "at X", "to X", "at VPA X", "info: X". The terminator uses
  // word boundaries so a keyword like "on" can't match inside the merchant name
  // (e.g. "AMAZON").
  static final RegExp _merchantRe = RegExp(
    r'(?:\bat\b|\bto\b|\bvpa\b|\btowards\b|\binfo[:\-]?)\s+'
    r'([A-Za-z0-9][A-Za-z0-9 &._@/-]{1,40}?)'
    r'(?=\s+(?:on|via|for|ref|upi|txn|dated)\b|\s*[.,;:]|\s*$)',
    caseSensitive: false,
  );

  // 04-Jul-25, 04/07/2026, 2026-07-04, 4 Jul 2026
  static final RegExp _dateNumeric = RegExp(
    r'\b(\d{1,2})[-/](\d{1,2})[-/](\d{2,4})\b',
  );
  static final RegExp _dateIso = RegExp(r'\b(\d{4})-(\d{2})-(\d{2})\b');
  static final RegExp _dateNamed = RegExp(
    r'\b(\d{1,2})[-\s]([A-Za-z]{3})[-\s](\d{2,4})\b',
  );

  static const Map<String, int> _months = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };

  /// Keyword → category, checked against the merchant and whole message.
  static const Map<String, ExpenseCategory> _categoryKeywords = {
    'swiggy': ExpenseCategory.food,
    'zomato': ExpenseCategory.food,
    'dominos': ExpenseCategory.food,
    'restaurant': ExpenseCategory.food,
    'cafe': ExpenseCategory.food,
    'amazon': ExpenseCategory.shopping,
    'flipkart': ExpenseCategory.shopping,
    'myntra': ExpenseCategory.shopping,
    'ajio': ExpenseCategory.shopping,
    'store': ExpenseCategory.shopping,
    'mart': ExpenseCategory.shopping,
    'uber': ExpenseCategory.travel,
    'ola': ExpenseCategory.travel,
    'irctc': ExpenseCategory.travel,
    'petrol': ExpenseCategory.travel,
    'fuel': ExpenseCategory.travel,
    'indigo': ExpenseCategory.travel,
    'netflix': ExpenseCategory.entertainment,
    'spotify': ExpenseCategory.entertainment,
    'hotstar': ExpenseCategory.entertainment,
    'prime': ExpenseCategory.entertainment,
    'bookmyshow': ExpenseCategory.entertainment,
    'electricity': ExpenseCategory.utilities,
    'recharge': ExpenseCategory.utilities,
    'airtel': ExpenseCategory.utilities,
    'jio': ExpenseCategory.utilities,
    'gas': ExpenseCategory.utilities,
    'water': ExpenseCategory.utilities,
    'broadband': ExpenseCategory.utilities,
    'pharmacy': ExpenseCategory.healthcare,
    'hospital': ExpenseCategory.healthcare,
    'apollo': ExpenseCategory.healthcare,
    'medical': ExpenseCategory.healthcare,
    'college': ExpenseCategory.education,
    'school': ExpenseCategory.education,
    'course': ExpenseCategory.education,
    'udemy': ExpenseCategory.education,
  };

  /// Parses [message]; returns a [ParsedTransaction] (with a null amount when
  /// the text isn't recognisably a transaction).
  static ParsedTransaction parse(String message) {
    final text = message.trim();

    final amountMatch = _amountRe.firstMatch(text);
    final amount =
        amountMatch != null
            ? double.tryParse(amountMatch.group(1)!.replaceAll(',', ''))
            : null;

    final direction =
        _debitRe.hasMatch(text)
            ? TransactionDirection.debit
            : _creditRe.hasMatch(text)
            ? TransactionDirection.credit
            : TransactionDirection.unknown;

    final merchant = _extractMerchant(text);
    final date = _extractDate(text);
    final category = _guessCategory(merchant, text);

    return ParsedTransaction(
      amount: amount,
      merchant: merchant,
      date: date,
      direction: direction,
      category: category,
      source: text,
    );
  }

  static String? _extractMerchant(String text) {
    final m = _merchantRe.firstMatch(text);
    if (m == null) return null;
    var name = m.group(1)!.trim();
    // Trim trailing account-ish noise.
    name = name.replaceAll(RegExp(r'[\s.,;:-]+$'), '');
    if (name.isEmpty) return null;
    // Title-case a shouty merchant name for nicer display.
    return name
        .split(RegExp(r'\s+'))
        .map(
          (w) =>
              w.isEmpty
                  ? w
                  : (w == w.toUpperCase()
                      ? w[0] + w.substring(1).toLowerCase()
                      : w),
        )
        .join(' ');
  }

  static DateTime? _extractDate(String text) {
    final iso = _dateIso.firstMatch(text);
    if (iso != null) {
      return _safeDate(
        int.parse(iso.group(1)!),
        int.parse(iso.group(2)!),
        int.parse(iso.group(3)!),
      );
    }
    final named = _dateNamed.firstMatch(text);
    if (named != null) {
      final month = _months[named.group(2)!.toLowerCase()];
      if (month != null) {
        return _safeDate(
          _fullYear(int.parse(named.group(3)!)),
          month,
          int.parse(named.group(1)!),
        );
      }
    }
    final numeric = _dateNumeric.firstMatch(text);
    if (numeric != null) {
      // Assume day-month-year (Indian convention).
      return _safeDate(
        _fullYear(int.parse(numeric.group(3)!)),
        int.parse(numeric.group(2)!),
        int.parse(numeric.group(1)!),
      );
    }
    return null;
  }

  static int _fullYear(int y) => y < 100 ? 2000 + y : y;

  static DateTime? _safeDate(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return DateTime(year, month, day);
  }

  static ExpenseCategory _guessCategory(String? merchant, String text) {
    final haystack = '${merchant ?? ''} $text'.toLowerCase();
    for (final entry in _categoryKeywords.entries) {
      if (haystack.contains(entry.key)) return entry.value;
    }
    return ExpenseCategory.other;
  }
}
