import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:another_telephony/telephony.dart';
import '../utils/transaction_parser.dart';

/// Reads transaction SMS from the device inbox (Android only) and turns them
/// into [ParsedTransaction] candidates for the user to review. Email parsing
/// uses the same [TransactionParser] via pasted text — auto-reading email would
/// require account OAuth, so it's handled through the paste flow instead.
class SmsImportService {
  final Telephony _telephony = Telephony.instance;

  /// SMS reading is Android-only (iOS sandboxes messages).
  bool get isSupported => !kIsWeb && Platform.isAndroid;

  /// Requests SMS permission, reads recent inbox messages, and returns the ones
  /// that parse as debit transactions, most recent first. Returns an empty list
  /// if unsupported or permission is denied.
  ///
  /// [maxMessages] caps how many recent messages are inspected.
  Future<List<ParsedTransaction>> scanInbox({int maxMessages = 300}) async {
    if (!isSupported) return [];

    final granted = await _telephony.requestSmsPermissions ?? false;
    if (!granted) {
      throw const SmsPermissionDeniedException();
    }

    final messages = await _telephony.getInboxSms(
      columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
      sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
    );

    final results = <ParsedTransaction>[];
    for (final msg in messages.take(maxMessages)) {
      final body = msg.body;
      if (body == null || body.isEmpty) continue;

      final parsed = TransactionParser.parse(body);
      // Only surface actual debits; credits/OTPs/promos are skipped.
      if (parsed.isTransaction && parsed.isDebit) {
        // Prefer the SMS timestamp when the body didn't include a date.
        final withDate =
            parsed.date == null && msg.date != null
                ? ParsedTransaction(
                  amount: parsed.amount,
                  merchant: parsed.merchant,
                  date: DateTime.fromMillisecondsSinceEpoch(msg.date!),
                  direction: parsed.direction,
                  category: parsed.category,
                  source: parsed.source,
                )
                : parsed;
        results.add(withDate);
      }
    }
    return results;
  }
}

/// Thrown when the user declines the SMS permission prompt.
class SmsPermissionDeniedException implements Exception {
  const SmsPermissionDeniedException();
  @override
  String toString() => 'SMS permission was denied';
}
