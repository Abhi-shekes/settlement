import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../models/expense_model.dart';
import '../../services/ai_service.dart';
import '../../services/expense_service.dart';
import '../../services/account_service.dart';
import '../../services/auth_service.dart';
import '../../services/budget_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/category_style.dart';
import '../../widgets/app_chip.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/markdown_text.dart';
import '../../widgets/money_text.dart';

/// A single bubble in the assistant thread. [draft] is set when the assistant
/// parsed an expense the user can review and save.
class _ChatMessage {
  _ChatMessage({
    required this.isUser,
    required this.text,
    this.draft,
    this.isError = false,
  });

  final bool isUser;
  String text;
  final ParsedExpenseDraft? draft;
  final bool isError;
  bool saved = false;
}

/// The AI assistant, reimagined as one chat surface (like ChatGPT/Gemini):
/// a single input handles questions, insights, advice, and logging expenses —
/// the model decides what to do from the message itself.
class AiAssistantScreen extends StatefulWidget {
  /// When true (e.g. opened from the "Voice add" home-screen widget), starts
  /// listening as soon as the screen is ready.
  final bool startVoice;

  const AiAssistantScreen({super.key, this.startVoice = false});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final stt.SpeechToText _speech = stt.SpeechToText();

  final List<_ChatMessage> _messages = [];

  bool _sending = false;
  bool _speechAvailable = false;
  bool _listening = false;

  static const _suggestedPrompts = [
    ('What did I spend last week?', Icons.query_stats_rounded),
    ('Where can I cut back?', Icons.savings_rounded),
    ('Am I over any budgets?', Icons.account_balance_wallet_rounded),
    ('How should I invest my surplus?', Icons.trending_up_rounded),
    ('Spent ₹450 on groceries today', Icons.add_circle_outline_rounded),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AccountService>().loadUserAccounts();
      context.read<ExpenseService>().loadUserExpenses();
      context.read<BudgetService>().loadUserBudgets();
      if (widget.startVoice) _toggleListen();
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _speech.cancel();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: AppDurations.fast,
        curve: Curves.easeOut,
      );
    });
  }

  // ── Voice ──────────────────────────────────────────────────────────────────

  Future<void> _toggleListen() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }

    if (!_speechAvailable) {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          if ((status == 'done' || status == 'notListening') && mounted) {
            setState(() => _listening = false);
          }
        },
        onError: (_) {
          if (mounted) setState(() => _listening = false);
        },
      );
    }
    if (!_speechAvailable) {
      if (mounted) {
        AppSnackbar.error(context, 'Microphone or speech not available.');
      }
      return;
    }

    setState(() => _listening = true);
    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() => _inputController.text = result.recognizedWords);
        if (result.finalResult) {
          setState(() => _listening = false);
          if (result.recognizedWords.trim().isNotEmpty) _send();
        }
      },
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  // ── Sending a message ───────────────────────────────────────────────────────

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _inputController.text).trim();
    if (text.isEmpty || _sending) return;

    // Capture everything that needs `context` before any async gap.
    FocusScope.of(context).unfocus();
    final ai = context.read<AiService>();
    final ctx = _buildContext();

    // History from the turns already on screen, before the new user message.
    final history = [
      for (final m in _messages)
        if (!m.isError) AiChatTurn(isUser: m.isUser, text: m.text),
    ];

    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
    }

    setState(() {
      _inputController.clear();
      _messages.add(_ChatMessage(isUser: true, text: text));
      _sending = true;
    });
    _scrollToBottom();

    try {
      final result = await ai.chat(
        message: text,
        context: ctx,
        history: history,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(isUser: false, text: result.text, draft: result.draft),
        );
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(
            _ChatMessage(
              isUser: false,
              text: 'AI error: ${_friendlyError(e)}',
              isError: true,
            ),
          );
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  void _resetChat() {
    setState(() {
      _messages.clear();
      _sending = false;
    });
  }

  // ── Expense review sheet ────────────────────────────────────────────────────

  Future<void> _showReviewSheet(_ChatMessage message) async {
    final draft = message.draft!;
    final titleController = TextEditingController(text: draft.title);
    final amountController = TextEditingController(
      text: draft.amount.toStringAsFixed(
        draft.amount.truncateToDouble() == draft.amount ? 0 : 2,
      ),
    );
    var category = draft.category;
    var date = draft.date;
    final accountService = context.read<AccountService>();
    String? accountId =
        accountService.accounts.isNotEmpty
            ? accountService.accounts.first.id
            : null;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final c = context.colors;
        return StatefulBuilder(
          builder: (context, setSheet) {
            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.md,
                right: AppSpacing.md,
                top: AppSpacing.md,
                bottom:
                    MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded, color: c.brand),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Review expense',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Amount (₹)'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<ExpenseCategory>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items:
                        ExpenseCategory.values
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(c.categoryDisplayName),
                              ),
                            )
                            .toList(),
                    onChanged: (v) => setSheet(() => category = v ?? category),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (accountService.accounts.isNotEmpty)
                    DropdownButtonFormField<String?>(
                      initialValue: accountId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Paid from'),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('None'),
                        ),
                        ...accountService.accounts.map(
                          (a) => DropdownMenuItem<String?>(
                            value: a.id,
                            child: Text(a.name),
                          ),
                        ),
                      ],
                      onChanged: (v) => setSheet(() => accountId = v),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setSheet(() => date = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Date'),
                      child: Text(DateFormat('MMM d, y').format(date)),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Save expense'),
                      onPressed: () async {
                        final amount = double.tryParse(
                          amountController.text.trim(),
                        );
                        if (amount == null || amount <= 0) return;
                        final uid =
                            context.read<AuthService>().currentUser?.uid;
                        if (uid == null) return;
                        final expenseService = context.read<ExpenseService>();
                        final navigator = Navigator.of(context);
                        final title =
                            titleController.text.trim().isEmpty
                                ? 'Expense'
                                : titleController.text.trim();
                        await expenseService.addExpense(
                          ExpenseModel(
                            id: const Uuid().v4(),
                            userId: uid,
                            title: title,
                            description: 'Added via AI',
                            amount: amount,
                            category: category,
                            createdAt: date,
                            accountId: accountId,
                          ),
                        );
                        navigator.pop();
                        if (mounted) {
                          setState(() => message.saved = true);
                          AppSnackbar.success(this.context, 'Expense added');
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    titleController.dispose();
    amountController.dispose();
  }

  // ── Context for the model ───────────────────────────────────────────────────

  String _buildSummary(ExpenseService expenses, BudgetService budgets) {
    final now = DateTime.now();
    final buffer = StringBuffer();
    buffer.writeln('Spending summary for ${DateFormat('MMMM y').format(now)}:');
    buffer.writeln('Total spent: ₹${expenses.getTotalExpenseAmount().toInt()}');

    buffer.writeln('\nBy category:');
    expenses.getCategoryWiseExpenses().forEach((category, amount) {
      if (amount > 0) {
        final budget = budgets.getBudgetForCategory(category);
        final note =
            (budget != null && budget.amount > 0)
                ? ' (budget ₹${budget.amount.toInt()})'
                : '';
        buffer.writeln(
          '- ${category.categoryDisplayName}: ₹${amount.toInt()}$note',
        );
      }
    });

    final top = expenses.getTopExpenses(5).where((e) => e.amount > 0).toList();
    if (top.isNotEmpty) {
      buffer.writeln('\nTop expenses:');
      for (final e in top) {
        buffer.writeln(
          '- ${e.title}: ₹${e.amount.toInt()} (${e.categoryDisplayName})',
        );
      }
    }
    return buffer.toString();
  }

  /// Full financial context: today's date, account balances, a spending
  /// summary, and recent dated transactions so time-relative questions work.
  String _buildContext() {
    final expenses = context.read<ExpenseService>();
    final accounts = context.read<AccountService>();
    final budgets = context.read<BudgetService>();
    final now = DateTime.now();
    final b = StringBuffer();

    b.writeln('Today: ${DateFormat('EEEE, yyyy-MM-dd').format(now)}');

    if (accounts.accounts.isNotEmpty) {
      b.writeln('\nAccounts and balances:');
      for (final a in accounts.accounts) {
        b.writeln('- ${a.name}: ${a.formattedBalance}');
      }
    }

    b.writeln('\n${_buildSummary(expenses, budgets)}');

    final cutoff = now.subtract(const Duration(days: 90));
    final recent =
        expenses.expenses.where((e) => e.createdAt.isAfter(cutoff)).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (recent.isNotEmpty) {
      b.writeln('\nRecent transactions (newest first):');
      for (final e in recent.take(120)) {
        final tag = e.isRefund ? ' [refund]' : '';
        b.writeln(
          '- ${DateFormat('yyyy-MM-dd').format(e.createdAt)}: ${e.title} — '
          '₹${e.amount.toInt()} (${e.categoryDisplayName})$tag',
        );
      }
    }
    return b.toString();
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('403') ||
        msg.toLowerCase().contains('permission') ||
        msg.toLowerCase().contains('not enabled') ||
        msg.toLowerCase().contains('api')) {
      return 'Enable "Firebase AI Logic" in the Firebase console for this project.';
    }
    return msg.replaceFirst('Exception: ', '');
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.surface,
      appBar: AppBar(
        title: const Text('AI Assistant'),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              tooltip: 'New chat',
              icon: const Icon(Icons.edit_square),
              onPressed: _sending ? null : _resetChat,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child:
                  _messages.isEmpty ? _buildEmptyState() : _buildMessageList(),
            ),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: _messages.length + (_sending ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _messages.length) return _buildTypingBubble();
        return _buildBubble(_messages[index]);
      },
    );
  }

  Widget _buildEmptyState() {
    final c = context.colors;
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const SizedBox(height: AppSpacing.xl),
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: c.brand.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          child: Icon(Icons.auto_awesome_rounded, color: c.brand, size: 30),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Your money, in plain English', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Ask about your spending, get saving or investment ideas, or just '
          'say what you spent to log it — all from one box.',
          style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Try asking',
          style: theme.textTheme.labelMedium?.copyWith(color: c.muted),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final p in _suggestedPrompts)
              AppChip(
                label: p.$1,
                icon: p.$2,
                onTap: _sending ? null : () => _send(p.$1),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildBubble(_ChatMessage m) {
    final c = context.colors;
    final theme = Theme.of(context);

    if (m.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm, left: 40),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: c.brand,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppRadii.lg),
              topRight: Radius.circular(AppRadii.lg),
              bottomLeft: Radius.circular(AppRadii.lg),
              bottomRight: Radius.circular(AppRadii.sm),
            ),
          ),
          child: Text(
            m.text,
            style: theme.textTheme.bodyMedium?.copyWith(color: c.onBrand),
          ),
        ),
      );
    }

    final accent = m.isError ? c.negative : c.brand;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm, right: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, size: 15, color: accent),
                const SizedBox(width: 6),
                Text(
                  'Assistant',
                  style: theme.textTheme.labelSmall?.copyWith(color: c.muted),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm + 2),
              decoration: BoxDecoration(
                color:
                    m.isError
                        ? c.negative.withValues(alpha: 0.08)
                        : c.surfaceElevated,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadii.sm),
                  topRight: Radius.circular(AppRadii.lg),
                  bottomLeft: Radius.circular(AppRadii.lg),
                  bottomRight: Radius.circular(AppRadii.lg),
                ),
                border: Border.all(
                  color:
                      m.isError
                          ? c.negative.withValues(alpha: 0.25)
                          : c.cardBorder,
                ),
              ),
              child: MarkdownText(
                m.text,
                baseStyle: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                  color: m.isError ? c.negative : null,
                ),
              ),
            ),
            if (m.draft != null) ...[
              const SizedBox(height: AppSpacing.xs),
              _buildDraftCard(m),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDraftCard(_ChatMessage m) {
    final c = context.colors;
    final theme = Theme.of(context);
    final draft = m.draft!;
    final catColor = draft.category.color;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: AppRadii.card,
        border: Border.all(color: c.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Icon(draft.category.icon, color: catColor, size: 20),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      draft.title,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${draft.category.categoryDisplayName} · '
                      '${DateFormat('MMM d').format(draft.date)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: c.muted,
                      ),
                    ),
                  ],
                ),
              ),
              MoneyText(draft.amount, size: 16),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child:
                m.saved
                    ? OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: const Text('Saved'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.positive,
                      ),
                    )
                    : FilledButton.icon(
                      onPressed: () => _showReviewSheet(m),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Review & save'),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingBubble() {
    final c = context.colors;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.sm + 2),
        decoration: BoxDecoration(
          color: c.surfaceElevated,
          borderRadius: AppRadii.card,
          border: Border.all(color: c.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(strokeWidth: 2, color: c.brand),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Thinking…',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: c.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.cardBorder)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_listening)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: [
                  Icon(Icons.mic_rounded, size: 15, color: c.negative),
                  const SizedBox(width: 6),
                  Text(
                    'Listening… speak now',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: c.muted),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Ask anything or log an expense…',
                    filled: true,
                    fillColor: c.surfaceElevated,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.xl),
                      borderSide: BorderSide(color: c.cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.xl),
                      borderSide: BorderSide(color: c.cardBorder),
                    ),
                    suffixIcon: IconButton(
                      tooltip: _listening ? 'Stop' : 'Speak',
                      icon: Icon(
                        _listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                        color: _listening ? c.negative : c.muted,
                      ),
                      onPressed: _toggleListen,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              _buildSendButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton() {
    final c = context.colors;
    return Material(
      color: _sending ? c.surfaceSunken : c.brand,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _sending ? null : () => _send(),
        child: SizedBox(
          width: 46,
          height: 46,
          child:
              _sending
                  ? Padding(
                    padding: const EdgeInsets.all(13),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: c.muted,
                    ),
                  )
                  : Icon(Icons.arrow_upward_rounded, color: c.onBrand),
        ),
      ),
    );
  }
}
