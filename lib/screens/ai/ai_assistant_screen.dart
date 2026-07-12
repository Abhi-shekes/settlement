import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../models/expense_model.dart';
import '../../models/category_model.dart';
import '../../models/split_model.dart';
import '../../models/user_model.dart';
import '../../services/ai_service.dart';
import '../../services/expense_service.dart';
import '../../services/category_service.dart';
import '../../services/account_service.dart';
import '../../services/auth_service.dart';
import '../../services/budget_service.dart';
import '../../services/group_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/friend_match.dart';
import '../../utils/money.dart';
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
    this.splitDraft,
    this.isError = false,
  });

  final bool isUser;
  String text;
  final ParsedExpenseDraft? draft;
  final ParsedSplitDraft? splitDraft;
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

  /// The user's friends, loaded once so the model can be told who it may split
  /// with and so drafted splits can be resolved back to real accounts.
  List<UserModel> _friends = [];

  bool _sending = false;
  bool _speechAvailable = false;
  bool _listening = false;

  static const _suggestedPrompts = [
    ('What did I spend last week?', Icons.query_stats_rounded),
    ('Where can I cut back?', Icons.savings_rounded),
    ('Am I over any budgets?', Icons.account_balance_wallet_rounded),
    ('Split ₹1200 dinner equally with my friends', Icons.call_split_rounded),
    ('How do splits work in Settlement?', Icons.help_outline_rounded),
    ('Spent ₹450 on groceries today', Icons.add_circle_outline_rounded),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AccountService>().loadUserAccounts();
      context.read<ExpenseService>().loadUserExpenses();
      context.read<BudgetService>().loadUserBudgets();
      _loadFriends();
      if (widget.startVoice) _toggleListen();
    });
  }

  Future<void> _loadFriends() async {
    try {
      final friends = await context.read<AuthService>().getFriends();
      if (mounted) setState(() => _friends = friends);
    } catch (_) {
      // Non-fatal: without friends the model simply won't offer to split.
    }
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
          _ChatMessage(
            isUser: false,
            text: result.text,
            draft: result.draft,
            splitDraft: result.splitDraft,
          ),
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
                  DropdownButtonFormField<Category>(
                    initialValue: category,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: categoryDropdownItems(
                      context.read<CategoryService>().all,
                    ),
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
                            categoryId: category.id,
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

    if (_friends.isNotEmpty) {
      b.writeln('\nYour friends (you can split with these people):');
      for (final f in _friends) {
        final label =
            f.displayName.trim().isNotEmpty ? f.displayName.trim() : f.email;
        b.writeln('- $label');
      }
    } else {
      b.writeln(
        '\nYour friends: none yet. To split a cost, the user must first add a '
        'friend by their friend code.',
      );
    }

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
          'Ask about your spending, split a bill with friends, get saving '
          'ideas, learn how a Settlement feature works, or just say what you '
          'spent to log it — all from one box.',
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
            if (m.splitDraft != null) ...[
              const SizedBox(height: AppSpacing.xs),
              _buildSplitDraftCard(m),
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

  // ── Split draft ─────────────────────────────────────────────────────────────

  /// Resolves a drafted split against the user's real friends and works out
  /// each participant's share. Returns the matched friends, any names that
  /// couldn't be matched, the full participant id list (user first) and the
  /// amount owed per user id.
  ({
    List<UserModel> matched,
    List<String> unmatched,
    List<String> ids,
    Map<String, double> amounts,
  })
  _planSplit(ParsedSplitDraft draft) {
    final uid = context.read<AuthService>().currentUser?.uid ?? '';
    final res = resolveFriendNames(_friends, draft.participantNames);
    final ids = <String>[uid, ...res.matched.map((f) => f.uid)];

    Map<String, double> amounts;
    if (draft.splitType == SplitType.unequal && draft.shares != null) {
      final shares = draft.shares!;
      amounts = {for (final id in ids) id: 0.0};
      // The user may be named "You"/"Me" in the model's shares.
      for (final entry in shares.entries) {
        final k = entry.key.trim().toLowerCase();
        if (k == 'you' || k == 'me' || k == 'myself') {
          amounts[uid] = entry.value;
        }
      }
      // Map each remaining share to whichever matched friend it names.
      for (final f in res.matched) {
        for (final entry in shares.entries) {
          final k = entry.key.trim().toLowerCase();
          if (k == 'you' || k == 'me' || k == 'myself') continue;
          if (resolveFriendNames([f], [entry.key]).matched.isNotEmpty) {
            amounts[f.uid] = entry.value;
            break;
          }
        }
      }
    } else {
      amounts = splitEvenly(draft.totalAmount, ids);
    }

    return (
      matched: res.matched,
      unmatched: res.unmatched,
      ids: ids,
      amounts: amounts,
    );
  }

  Widget _buildSplitDraftCard(_ChatMessage m) {
    final c = context.colors;
    final theme = Theme.of(context);
    final draft = m.splitDraft!;
    final plan = _planSplit(draft);
    final canSave = plan.matched.isNotEmpty;

    Widget shareRow(String label, double amount, {bool isYou = false}) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xxs),
        child: Row(
          children: [
            Icon(
              isYou ? Icons.person_rounded : Icons.person_outline_rounded,
              size: 15,
              color: c.muted,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            MoneyText(amount, size: 13),
          ],
        ),
      );
    }

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
                  color: c.brand.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Icon(Icons.call_split_rounded, color: c.brand, size: 20),
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
                      '${draft.splitType == SplitType.unequal ? 'Unequal' : 'Equal'} split',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: c.muted,
                      ),
                    ),
                  ],
                ),
              ),
              MoneyText(draft.totalAmount, size: 16),
            ],
          ),
          if (canSave) ...[
            const Divider(height: AppSpacing.md),
            shareRow('You', plan.amounts[plan.ids.first] ?? 0, isYou: true),
            for (final f in plan.matched)
              shareRow(
                f.displayName.trim().isNotEmpty ? f.displayName : f.email,
                plan.amounts[f.uid] ?? 0,
              ),
          ],
          if (plan.unmatched.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                canSave
                    ? "I couldn't find ${plan.unmatched.join(', ')} in your friends — add them by friend code to include them."
                    : "You don't have ${plan.unmatched.join(', ')} as a friend yet. Add them by friend code first, then try again.",
                style: theme.textTheme.bodySmall?.copyWith(color: c.warning),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child:
                m.saved
                    ? OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: const Text('Split created'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.positive,
                      ),
                    )
                    : FilledButton.icon(
                      onPressed:
                          canSave ? () => _showSplitReviewSheet(m) : null,
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Review & save'),
                    ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSplitReviewSheet(_ChatMessage message) async {
    final draft = message.splitDraft!;
    final plan = _planSplit(draft);
    final uid = context.read<AuthService>().currentUser?.uid;
    if (uid == null) return;

    final titleController = TextEditingController(text: draft.title);
    final amountController = TextEditingController(
      text: draft.totalAmount.toStringAsFixed(
        draft.totalAmount.truncateToDouble() == draft.totalAmount ? 0 : 2,
      ),
    );
    final notesController = TextEditingController(text: draft.notes);

    var type = draft.splitType;
    final selectedIds = <String>{...plan.matched.map((f) => f.uid)};
    // Per-participant amount fields for unequal splits (keyed by user id).
    final shareControllers = <String, TextEditingController>{
      uid: TextEditingController(text: _fmtAmount(plan.amounts[uid] ?? 0)),
      for (final f in _friends)
        f.uid: TextEditingController(
          text: _fmtAmount(plan.amounts[f.uid] ?? 0),
        ),
    };

    String labelFor(String id) {
      if (id == uid) return 'You';
      for (final f in _friends) {
        if (f.uid == id) {
          return f.displayName.trim().isNotEmpty ? f.displayName : f.email;
        }
      }
      return id;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final c = context.colors;
        final theme = Theme.of(context);
        return StatefulBuilder(
          builder: (context, setSheet) {
            final participantIds = <String>[uid, ...selectedIds];
            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.md,
                right: AppSpacing.md,
                top: AppSpacing.md,
                bottom:
                    MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.call_split_rounded, color: c.brand),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Review split',
                          style: theme.textTheme.titleMedium,
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
                      decoration: const InputDecoration(
                        labelText: 'Total amount (₹)',
                      ),
                      onChanged: (_) => setSheet(() {}),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SegmentedButton<SplitType>(
                      segments: const [
                        ButtonSegment(
                          value: SplitType.equal,
                          label: Text('Equal'),
                          icon: Icon(Icons.balance_rounded),
                        ),
                        ButtonSegment(
                          value: SplitType.unequal,
                          label: Text('Unequal'),
                          icon: Icon(Icons.tune_rounded),
                        ),
                      ],
                      selected: {type},
                      onSelectionChanged: (s) => setSheet(() => type = s.first),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Split with',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: c.muted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    if (_friends.isEmpty)
                      Text(
                        'No friends yet — add friends by their friend code to '
                        'split with them.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: c.muted,
                        ),
                      )
                    else
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          for (final f in _friends)
                            FilterChip(
                              label: Text(
                                f.displayName.trim().isNotEmpty
                                    ? f.displayName
                                    : f.email,
                              ),
                              selected: selectedIds.contains(f.uid),
                              onSelected:
                                  (v) => setSheet(() {
                                    if (v) {
                                      selectedIds.add(f.uid);
                                    } else {
                                      selectedIds.remove(f.uid);
                                    }
                                  }),
                            ),
                        ],
                      ),
                    if (type == SplitType.unequal &&
                        selectedIds.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Each person owes',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: c.muted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      for (final id in participantIds)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: Row(
                            children: [
                              Expanded(child: Text(labelFor(id))),
                              SizedBox(
                                width: 120,
                                child: TextField(
                                  controller: shareControllers[id],
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    prefixText: '₹',
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Create split'),
                        onPressed: () async {
                          await _saveSplit(
                            message: message,
                            uid: uid,
                            title: titleController.text.trim(),
                            totalText: amountController.text.trim(),
                            notes: notesController.text.trim(),
                            type: type,
                            selectedIds: selectedIds.toList(),
                            shareControllers: shareControllers,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    titleController.dispose();
    amountController.dispose();
    notesController.dispose();
    for (final ctrl in shareControllers.values) {
      ctrl.dispose();
    }
  }

  Future<void> _saveSplit({
    required _ChatMessage message,
    required String uid,
    required String title,
    required String totalText,
    required String notes,
    required SplitType type,
    required List<String> selectedIds,
    required Map<String, TextEditingController> shareControllers,
  }) async {
    final total = double.tryParse(totalText);
    if (total == null || total <= 0) {
      AppSnackbar.error(context, 'Enter a valid total amount.');
      return;
    }
    if (selectedIds.isEmpty) {
      AppSnackbar.error(context, 'Pick at least one friend to split with.');
      return;
    }

    final participants = <String>[uid, ...selectedIds];
    Map<String, double> splitAmounts;
    if (type == SplitType.unequal) {
      splitAmounts = {
        for (final id in participants)
          id: double.tryParse(shareControllers[id]?.text.trim() ?? '') ?? 0.0,
      };
      final sum = splitAmounts.values.fold<double>(0, (s, v) => s + v);
      if ((sum - total).abs() > 0.01) {
        AppSnackbar.error(
          context,
          'Individual amounts must add up to the total (₹${total.toInt()}).',
        );
        return;
      }
    } else {
      splitAmounts = splitEvenly(total, participants);
    }

    final groupService = context.read<GroupService>();
    final navigator = Navigator.of(context);
    final split = SplitModel(
      id: const Uuid().v4(),
      title: title.isEmpty ? 'Split' : title,
      description: 'Added via AI',
      totalAmount: total,
      paidBy: uid,
      participants: participants,
      splitType: type,
      splitAmounts: splitAmounts,
      createdAt: DateTime.now(),
      notes: notes,
    );

    try {
      await groupService.createSplit(split);
      navigator.pop();
      if (mounted) {
        setState(() => message.saved = true);
        AppSnackbar.success(context, 'Split created');
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, 'Could not create split: $e');
    }
  }

  String _fmtAmount(double v) =>
      v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2);

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
