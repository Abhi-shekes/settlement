import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_ai/firebase_ai.dart';
import '../models/category_model.dart';
import '../models/split_model.dart';

/// A transaction drafted by the AI from a natural-language sentence, ready for
/// the user to review before saving.
class ParsedExpenseDraft {
  final String title;
  final double amount;
  final Category category;
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

/// A split drafted by the AI from a natural-language sentence, ready for the
/// user to review before it is created. [participantNames] are the friends the
/// user wants to split with (excluding the user), named exactly as they appear
/// in the financial context; the UI resolves them to real friend accounts.
/// [shares] maps a participant name to their amount for unequal splits (null
/// for equal splits, where the UI divides the total evenly).
class ParsedSplitDraft {
  final String title;
  final double totalAmount;
  final SplitType splitType;
  final List<String> participantNames;
  final Map<String, double>? shares;
  final String notes;

  ParsedSplitDraft({
    required this.title,
    required this.totalAmount,
    required this.splitType,
    required this.participantNames,
    this.shares,
    this.notes = '',
  });
}

/// The outcome of a single [AiService.chat] turn. [text] is the assistant's
/// reply to show in the thread. [draft] is present when the user asked to log
/// an expense, and [splitDraft] when they asked to split a cost with friends —
/// either lets the UI offer a review-and-save card.
class AiChatResult {
  final String text;
  final ParsedExpenseDraft? draft;
  final ParsedSplitDraft? splitDraft;
  const AiChatResult({required this.text, this.draft, this.splitDraft});
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

  /// Category names offered to the model — includes the user's custom
  /// categories. Read live (not cached) so a category added mid-session is
  /// immediately available for suggestions and logging.
  List<String> get _categoryNames =>
      CategoryRegistry.instance.all.map((c) => c.name).toList();

  /// A concise, maintained guide to Settlement's real features, so the
  /// assistant can accurately answer "how do I…" questions about the app
  /// itself rather than refusing or inventing steps. Keep this in sync with
  /// the app's actual behaviour.
  static const _appGuide =
      "How Settlement works (use this to explain the app's own features):\n"
      '- Expenses: log spending under a category, optionally paid from an '
      'account. Track them on the Expenses tab; the dashboard and Analytics '
      'show totals and category breakdowns.\n'
      '- Friends: add someone by their friend code (Profile shows your own '
      'code; Friends screen has "Add friend"). You can only split with people '
      'who are already your friends.\n'
      '- Splits: on the Splits tab, "Add split" records a shared cost. Choose '
      'Equal (divided evenly) or Unequal (you set each share). The payer is '
      'auto-accepted; every other participant gets a request and must APPROVE '
      'their share before it becomes a real debt in balances.\n'
      '- Settlements: when someone pays you back (or you pay them), record a '
      'settlement. It only reduces the balance once the OTHER person confirms '
      'it.\n'
      '- Groups: create a group to organise splits among the same set of '
      'people (e.g. flatmates, a trip); group balances net out who owes whom.\n'
      '- Budgets: set a monthly budget per category; the app flags categories '
      'you are over.\n'
      '- Accounts: track balances across your cash/bank accounts; expenses can '
      'be paid from an account.\n'
      '- Recurring: schedule repeating transactions.\n'
      '- Appearance: light/dark theme toggle lives in Profile → Appearance.';

  static const _agentPersona =
      'You are the built-in AI money assistant for "Settlement", a personal-'
      'finance and expense-splitting app for an Indian user. All amounts are '
      'in INR (₹).\n\n'
      'SCOPE — read carefully:\n'
      '- You work only inside Settlement. Help the user with THEIR money and '
      'with using Settlement itself.\n'
      '- NEVER recommend, name, link to, or compare other apps, products, '
      'websites, banks or services (e.g. other expense/split/payment/'
      'budgeting apps). If the user asks about a competitor or an external '
      'tool, do not endorse it — explain how to do the same thing inside '
      'Settlement instead.\n'
      '- If asked something unrelated to the user\'s finances or to using '
      'Settlement, politely steer back to what you can help with here.\n\n'
      'You handle everything from a single chat box:\n'
      "1. Answer questions about the user's money using ONLY the financial "
      'context provided (their transactions, budgets, account balances and '
      "friends). If the answer isn't in the context, say you don't have that "
      'data rather than guessing. Never invent numbers.\n'
      '2. Explain how to use Settlement\'s features using the app guide below. '
      'Give clear, specific steps for this app.\n'
      '3. Give insights and advice when asked — spending patterns, unusual or '
      'high spending, and concrete ways to save. You may share beginner-'
      'friendly, GENERAL investment concepts for a surplus (emergency fund, '
      'SIPs into index or mutual funds, PPF, fixed deposits, NPS) as education '
      'only — add a one-line disclaimer, and never name a specific provider, '
      'fund or app.\n'
      '4. Log expenses: when the user says they spent, paid for or bought '
      'something (for themselves) and wants it recorded, call the log_expense '
      'tool.\n'
      '5. Split costs: when the user wants to split or share a cost with '
      'friends, call the create_split tool. Only use friends that appear in '
      "the \"Your friends\" list in the context, named exactly as listed.\n\n"
      'ASK, DON\'T GUESS: if a request to log or split is missing something '
      'essential — the amount, or (for a split) who to split with — or names a '
      'person who is NOT in the "Your friends" list, ask ONE short clarifying '
      'question and do NOT call a tool yet. For a tool call, keep your reply to '
      'one short confirming sentence; the app shows a review card to confirm '
      'and save.\n\n'
      'Style: concise and friendly. Use short paragraphs or bullet points, and '
      'show relevant totals. The current date and all figures are in the '
      'context below.\n\n'
      '$_appGuide';

  /// Built fresh per call (rather than cached) so the category enum reflects any
  /// custom categories added since the service started.
  GenerativeModel
  _buildCategoryModel() => FirebaseAI.googleAI().generativeModel(
    model: _modelName,
    systemInstruction: Content.text(
      'You categorize personal expenses. Respond only with the JSON schema.',
    ),
    generationConfig: GenerationConfig(
      responseMimeType: 'application/json',
      responseSchema: Schema.object(
        properties: {'category': Schema.enumString(enumValues: _categoryNames)},
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

  FunctionDeclaration get _createSplitFn => FunctionDeclaration(
    'create_split',
    'Drafts a shared expense split among the user and their friends. Call this '
        'when the user wants to split, share or divide a cost with other '
        'people (e.g. "split ₹1200 dinner with Rahul and Priya", "divide the '
        '₹900 cab 3 ways with Sam"). The user is always the payer and is '
        'included automatically — do NOT list the user in participants. Use '
        'friend names EXACTLY as they appear in the "Your friends" list in the '
        'context. If a named person is not in that list, or the user did not '
        'say who to split with, do NOT call this — ask them first.',
    parameters: {
      'title': Schema.string(
        description: 'Short label for the split, e.g. "Dinner", "Cab".',
      ),
      'amount': Schema.number(
        description: 'Total amount of the shared cost in rupees (INR).',
      ),
      'splitType': Schema.enumString(
        enumValues: ['equal', 'unequal'],
        description:
            'Use "equal" to divide the total evenly across everyone '
            '(the user + participants). Use "unequal" only when the user '
            'gives specific per-person amounts, then fill "shares".',
      ),
      'participants': Schema.array(
        description:
            'Friend names to split with, EXCLUDING the user, exactly as they '
            'appear in the "Your friends" list.',
        items: Schema.string(),
      ),
      'shares': Schema.array(
        description:
            'For unequal splits only: each person\'s amount. Include the user '
            'as "You" if they owe a share. Amounts must sum to the total.',
        items: Schema.object(
          properties: {
            'name': Schema.string(
              description: 'Participant name, or "You" for the user.',
            ),
            'amount': Schema.number(description: 'Their share in rupees.'),
          },
        ),
        nullable: true,
      ),
      'notes': Schema.string(description: 'Optional note.', nullable: true),
    },
    optionalParameters: ['shares', 'notes'],
  );

  void _setBusy(bool value) {
    _isBusy = value;
    notifyListeners();
  }

  Category _categoryFromName(String? name) {
    final lower = (name ?? '').toLowerCase();
    final all = CategoryRegistry.instance.all;
    return all.firstWhere(
      (c) => c.name.toLowerCase() == lower,
      orElse: () => kOtherCategory,
    );
  }

  /// Suggests a category for an expense from its [title] and [description].
  Future<Category?> suggestCategory({
    required String title,
    String description = '',
  }) async {
    if (title.trim().isEmpty) return null;
    _setBusy(true);
    try {
      final response = await _buildCategoryModel().generateContent([
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
          Tool.functionDeclarations([_logExpenseFn, _createSplitFn]),
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

      // The model calls at most one tool per turn (log or split); take the
      // first recognised call.
      FunctionCall? logCall;
      FunctionCall? splitCall;
      for (final call in response.functionCalls) {
        if (call.name == 'log_expense') {
          logCall = call;
          break;
        }
        if (call.name == 'create_split') {
          splitCall = call;
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

      if (splitCall != null) {
        final splitDraft = _splitDraftFromArgs(splitCall.args);
        final reply = response.text?.trim();
        return AiChatResult(
          text:
              (reply != null && reply.isNotEmpty)
                  ? reply
                  : (splitDraft != null
                      ? "Here's the split I set up — review and save it below."
                      : "I couldn't set up that split — tell me the amount and who to split with."),
          splitDraft: splitDraft,
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

  /// Test seam for the private [_splitDraftFromArgs] parser.
  @visibleForTesting
  ParsedSplitDraft? parseSplitArgs(Map<String, Object?> args) =>
      _splitDraftFromArgs(args);

  ParsedSplitDraft? _splitDraftFromArgs(Map<String, Object?> args) {
    final amount = (args['amount'] as num?)?.toDouble();
    if (amount == null || amount <= 0) return null;

    final participants = <String>[
      for (final p in (args['participants'] as List<Object?>? ?? const []))
        if ((p as String?)?.trim().isNotEmpty ?? false) (p as String).trim(),
    ];
    // A split needs at least one other person besides the user.
    if (participants.isEmpty) return null;

    final isUnequal = (args['splitType'] as String?) == 'unequal';

    Map<String, double>? shares;
    if (isUnequal) {
      final raw = args['shares'] as List<Object?>?;
      if (raw != null && raw.isNotEmpty) {
        shares = {};
        for (final entry in raw) {
          if (entry is Map) {
            final name = (entry['name'] as String?)?.trim();
            final value = (entry['amount'] as num?)?.toDouble();
            if (name != null && name.isNotEmpty && value != null) {
              shares[name] = value;
            }
          }
        }
        if (shares.isEmpty) shares = null;
      }
    }

    final title = (args['title'] as String?)?.trim();
    return ParsedSplitDraft(
      title: (title != null && title.isNotEmpty) ? title : 'Split',
      totalAmount: amount,
      // Fall back to equal if the model asked for unequal but gave no usable
      // shares — the review sheet will divide evenly.
      splitType:
          (isUnequal && shares != null) ? SplitType.unequal : SplitType.equal,
      participantNames: participants,
      shares: (isUnequal && shares != null) ? shares : null,
      notes: (args['notes'] as String?)?.trim() ?? '',
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
