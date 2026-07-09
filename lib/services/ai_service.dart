import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_ai/firebase_ai.dart';
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

/// One turn of the running conversation, sent back to the model so it has
/// memory of what was said earlier in the chat.
class AiChatTurn {
  final bool isUser;
  final String text;
  const AiChatTurn({required this.isUser, required this.text});
}

/// The outcome of a single [AiService.chat] turn. [text] is the assistant's
/// reply to show in the thread; [draft] is present when the user asked to log
/// an expense, so the UI can offer a review-and-save card.
class AiChatResult {
  final String text;
  final ParsedExpenseDraft? draft;
  const AiChatResult({required this.text, this.draft});
}

/// AI features powered by Gemini through Firebase AI Logic (the Gemini Developer
/// API backend — `FirebaseAI.googleAI()` — which has a no-billing free tier and
/// reuses the app's existing Firebase project, so there's no API key to embed).
///
/// The app talks to one conversational assistant through a single chat box
/// (like ChatGPT/Gemini): [chat] answers questions, gives insights and advice,
/// and logs expenses — deciding what to do from the message itself, using the
/// `log_expense` tool when the user wants to record spending. [suggestCategory]
/// remains a small structured helper used by the manual add-expense form.
///
/// Uses `gemini-2.5-flash` for low latency and cost. Requires "Firebase AI
/// Logic" to be enabled once in the Firebase console.
class AiService extends ChangeNotifier {
  static const _modelName = 'gemini-2.5-flash';

  bool _isBusy = false;
  bool get isBusy => _isBusy;

  final List<String> _categoryNames =
      ExpenseCategory.values.map((c) => c.categoryDisplayName).toList();

  GenerativeModel? _categoryModel;

  static const _agentPersona =
      'You are the built-in AI money assistant for "Settlement", a personal-'
      'finance app for an Indian user. All amounts are in INR (₹).\n\n'
      'You handle everything from a single chat box:\n'
      '1. Answer questions about the user\'s money using ONLY the financial '
      'context provided (their transactions, budgets and account balances). If '
      "the answer isn't in the context, say you don't have that data rather "
      'than guessing. Never invent numbers.\n'
      '2. Give insights and advice when asked — spending patterns, unusual or '
      'high spending, concrete ways to save, and beginner-friendly, general '
      'investment ideas for any surplus (emergency fund, SIPs into index or '
      'mutual funds, PPF, fixed deposits, NPS). Investment ideas are general '
      'education, not personalised advice — add a one-line disclaimer when you '
      'give them.\n'
      '3. Log expenses: when the user says they spent, paid for or bought '
      'something and wants it recorded, call the log_expense tool with the '
      'details instead of only replying. Keep your reply to one short '
      'confirming sentence — the app shows a review card for the user to '
      'confirm and save.\n\n'
      'Style: concise and friendly. Use short paragraphs or bullet points, and '
      'show relevant totals. The current date and all figures are in the '
      'context below.';

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

  FunctionDeclaration get _logExpenseFn => FunctionDeclaration(
    'log_expense',
    'Records a new expense in the user\'s tracker. Call this whenever the user '
        'says they spent, paid for or bought something and wants it logged '
        '(e.g. "spent ₹450 on groceries", "add ₹1200 dinner yesterday"). Do '
        'NOT call it for questions about past spending.',
    parameters: {
      'title': Schema.string(
        description: 'Short label for the expense, e.g. "Groceries", "Dinner".',
      ),
      'amount': Schema.number(description: 'Amount in rupees (INR).'),
      'category': Schema.enumString(enumValues: _categoryNames),
      'date': Schema.string(
        description:
            'ISO 8601 date (yyyy-MM-dd). Resolve relative words like '
            '"today"/"yesterday" against the current date given in the context.',
        nullable: true,
      ),
    },
    optionalParameters: ['date'],
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

  /// The single entry point for the assistant chat. Sends the running [history]
  /// plus the new [message] to Gemini, primed with the user's financial
  /// [context]. Returns the assistant's reply, and — when the user asked to log
  /// spending — a [ParsedExpenseDraft] for the UI to review and save.
  Future<AiChatResult> chat({
    required String message,
    required String context,
    List<AiChatTurn> history = const [],
  }) async {
    _setBusy(true);
    try {
      final model = FirebaseAI.googleAI().generativeModel(
        model: _modelName,
        systemInstruction: Content.system(
          '$_agentPersona\n\nFinancial context (use only this for facts and '
          'figures):\n$context',
        ),
        tools: [
          Tool.functionDeclarations([_logExpenseFn]),
        ],
      );

      final contents = <Content>[
        for (final turn in history)
          if (turn.isUser)
            Content.text(turn.text)
          else
            Content.model([TextPart(turn.text)]),
        Content.text(message),
      ];

      final response = await model.generateContent(contents);

      FunctionCall? logCall;
      for (final call in response.functionCalls) {
        if (call.name == 'log_expense') {
          logCall = call;
          break;
        }
      }

      if (logCall != null) {
        final draft = _draftFromArgs(logCall.args);
        final reply = response.text?.trim();
        return AiChatResult(
          text:
              (reply != null && reply.isNotEmpty)
                  ? reply
                  : (draft != null
                      ? "Here's the expense I picked up — review and save it below."
                      : "I couldn't catch the amount. Try including how much you spent."),
          draft: draft,
        );
      }

      final reply = response.text?.trim();
      return AiChatResult(
        text:
            (reply != null && reply.isNotEmpty)
                ? reply
                : "I couldn't work that out. Please try rephrasing.",
      );
    } catch (e) {
      debugPrint('AI chat error: $e');
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  ParsedExpenseDraft? _draftFromArgs(Map<String, Object?> args) {
    final amount = (args['amount'] as num?)?.toDouble();
    if (amount == null || amount <= 0) return null;

    DateTime date = DateTime.now();
    final dateStr = args['date'] as String?;
    if (dateStr != null && dateStr.isNotEmpty) {
      date = DateTime.tryParse(dateStr) ?? date;
    }

    final title = (args['title'] as String?)?.trim();
    return ParsedExpenseDraft(
      title: (title != null && title.isNotEmpty) ? title : 'Expense',
      amount: amount,
      category: _categoryFromName(args['category'] as String?),
      date: date,
    );
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
