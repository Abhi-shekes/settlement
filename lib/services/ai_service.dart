import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:intl/intl.dart';
import '../models/expense_model.dart';

/// A transaction drafted by the AI from a natural-language sentence, ready for
/// the user to review before saving.
class ParsedExpenseDraft {
  final String title;
  final double amount;
  final ExpenseCategory category;
  final DateTime date;

  ParsedExpenseDraft({
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
  });
}

/// AI features powered by Gemini through Firebase AI Logic (the Gemini Developer
/// API backend — `FirebaseAI.googleAI()` — which has a no-billing free tier and
/// reuses the app's existing Firebase project, so there's no API key to embed).
///
/// Provides: category suggestion, natural-language expense entry, and spending
/// insights. Uses `gemini-2.5-flash` for low latency and cost; structured
/// features constrain the model to JSON via a response schema.
///
/// Requires "Firebase AI Logic" to be enabled once in the Firebase console.
class AiService extends ChangeNotifier {
  static const _modelName = 'gemini-2.5-flash';

  bool _isBusy = false;
  bool get isBusy => _isBusy;

  final List<String> _categoryNames =
      ExpenseCategory.values.map((c) => c.categoryDisplayName).toList();

  GenerativeModel? _categoryModel;
  GenerativeModel? _parseModel;
  GenerativeModel? _insightsModel;

  GenerativeModel get _category =>
      _categoryModel ??= FirebaseAI.googleAI().generativeModel(
        model: _modelName,
        systemInstruction: Content.text(
          'You categorize personal expenses. Respond only with the JSON schema.',
        ),
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          responseSchema: Schema.object(
            properties: {
              'category': Schema.enumString(enumValues: _categoryNames),
            },
          ),
        ),
      );

  GenerativeModel get _parse =>
      _parseModel ??= FirebaseAI.googleAI().generativeModel(
        model: _modelName,
        systemInstruction: Content.text(
          'You extract a single expense from a short natural-language sentence '
          'for an Indian personal-finance app. Amounts are in INR (₹). Respond '
          'only with the JSON schema.',
        ),
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          responseSchema: Schema.object(
            properties: {
              'title': Schema.string(
                description: 'Short label for the expense, e.g. "Groceries".',
              ),
              'amount': Schema.number(description: 'Amount in rupees.'),
              'category': Schema.enumString(enumValues: _categoryNames),
              'date': Schema.string(
                description:
                    'ISO 8601 date (yyyy-MM-dd). Resolve relative words like '
                    '"today"/"yesterday" against the provided current date.',
                nullable: true,
              ),
            },
            optionalProperties: ['date'],
          ),
        ),
      );

  GenerativeModel get _insights =>
      _insightsModel ??= FirebaseAI.googleAI().generativeModel(
        model: _modelName,
        systemInstruction: Content.text(
          'You are a friendly personal-finance assistant for an Indian user. '
          'Amounts are in INR (₹). Given a spending summary, give brief, '
          'practical insights: notable patterns, any unusual or high spending, '
          'and 2-3 concrete ways to save. Use short paragraphs or bullet '
          'points. Do not invent numbers beyond the summary.',
        ),
      );

  void _setBusy(bool value) {
    _isBusy = value;
    notifyListeners();
  }

  ExpenseCategory _categoryFromName(String? name) {
    return ExpenseCategory.values.firstWhere(
      (c) => c.categoryDisplayName.toLowerCase() == (name ?? '').toLowerCase(),
      orElse: () => ExpenseCategory.other,
    );
  }

  /// Suggests a category for an expense from its [title] and [description].
  Future<ExpenseCategory?> suggestCategory({
    required String title,
    String description = '',
  }) async {
    if (title.trim().isEmpty) return null;
    _setBusy(true);
    try {
      final response = await _category.generateContent([
        Content.text(
          'Expense title: "$title"\nDescription: "$description"\n'
          'Pick the single best category.',
        ),
      ]);
      final map = _decode(response.text);
      return map == null ? null : _categoryFromName(map['category'] as String?);
    } catch (e) {
      debugPrint('AI suggestCategory error: $e');
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  /// Parses a natural-language sentence like "Spent ₹450 on groceries today"
  /// into a draft expense for review. Returns null if no amount could be found.
  Future<ParsedExpenseDraft?> parseNaturalLanguage(String text) async {
    if (text.trim().isEmpty) return null;
    _setBusy(true);
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final response = await _parse.generateContent([
        Content.text('Current date: $today\nSentence: "$text"'),
      ]);
      final map = _decode(response.text);
      if (map == null) return null;

      final amount = (map['amount'] as num?)?.toDouble();
      if (amount == null || amount <= 0) return null;

      DateTime date = DateTime.now();
      final dateStr = map['date'] as String?;
      if (dateStr != null && dateStr.isNotEmpty) {
        date = DateTime.tryParse(dateStr) ?? date;
      }

      return ParsedExpenseDraft(
        title:
            (map['title'] as String?)?.trim().isNotEmpty == true
                ? (map['title'] as String).trim()
                : 'Expense',
        amount: amount,
        category: _categoryFromName(map['category'] as String?),
        date: date,
      );
    } catch (e) {
      debugPrint('AI parseNaturalLanguage error: $e');
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  /// Generates free-text spending insights from a pre-built [summary].
  Future<String> generateInsights(String summary) async {
    _setBusy(true);
    try {
      final response = await _insights.generateContent([Content.text(summary)]);
      return response.text?.trim() ??
          'No insights available right now. Please try again.';
    } catch (e) {
      debugPrint('AI generateInsights error: $e');
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  /// Builds a Gemini model with a one-off [systemInstruction]. Used for the
  /// advice and free-form Q&A features that each want their own persona.
  GenerativeModel _textModel(String systemInstruction) =>
      FirebaseAI.googleAI().generativeModel(
        model: _modelName,
        systemInstruction: Content.text(systemInstruction),
      );

  /// Saving or investment tips grounded in a pre-built spending [summary].
  Future<String> generateTips(
    String summary, {
    required bool investment,
  }) async {
    _setBusy(true);
    try {
      final model = _textModel(
        investment
            ? 'You are a cautious financial-education assistant for an Indian '
                  'user. Amounts are in INR (₹). From their spending/savings '
                  'summary, suggest general, beginner-friendly ways to put any '
                  'surplus to work — e.g. an emergency fund, SIPs into index or '
                  'mutual funds, PPF, fixed deposits, or NPS — and briefly say '
                  'why each fits. This is general education, not personalised '
                  'financial advice: end with a one-line disclaimer. Use short '
                  'bullet points. Do not invent numbers beyond the summary.'
            : 'You are a friendly personal-finance assistant for an Indian '
                  'user. Amounts are in INR (₹). From their spending summary, '
                  'give 4-6 concrete, practical ways to save money that '
                  'reference their actual spending categories. Use short bullet '
                  'points. Do not invent numbers beyond the summary.',
      );
      final response = await model.generateContent([Content.text(summary)]);
      return response.text?.trim() ??
          'No tips available right now. Please try again.';
    } catch (e) {
      debugPrint('AI generateTips error: $e');
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  /// Answers a free-form [question] using only the provided financial
  /// [context] (recent transactions, budgets, account balances).
  Future<String> answerQuery(String question, String context) async {
    _setBusy(true);
    try {
      final model = _textModel(
        'You are a helpful personal-finance assistant for an Indian user. '
        'Amounts are in INR (₹). Answer the question using ONLY the provided '
        'financial context (their transactions, budgets and accounts). If the '
        "answer isn't in the context, say you don't have that data rather than "
        'guessing. Be concise — use short paragraphs or bullet points, and '
        'show relevant totals. Do not invent numbers.',
      );
      final response = await model.generateContent([
        Content.text('Financial context:\n$context\n\nQuestion: $question'),
      ]);
      return response.text?.trim() ??
          "I couldn't work that out. Please try rephrasing.";
    } catch (e) {
      debugPrint('AI answerQuery error: $e');
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  Map<String, dynamic>? _decode(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(text);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}
