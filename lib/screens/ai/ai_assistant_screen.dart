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
import '../../widgets/app_chip.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/markdown_text.dart';

class AiAssistantScreen extends StatefulWidget {
  /// When true (e.g. opened from the "Voice add" home-screen widget), starts
  /// listening as soon as the screen is ready.
  final bool startVoice;

  const AiAssistantScreen({super.key, this.startVoice = false});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _nlController = TextEditingController();
  final _askController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();

  String? _answer;
  String? _insights;
  String? _savingTips;
  String? _investmentTips;

  bool _loadingAnswer = false;
  bool _loadingInsights = false;
  bool _loadingSaving = false;
  bool _loadingInvestment = false;
  bool _parsing = false;
  bool _speechAvailable = false;
  bool _listening = false;

  static const _suggestedPrompts = [
    'What did I spend last week?',
    'My biggest expenses this month',
    'Where can I cut back?',
    'How much did I spend on food?',
    'Am I over any budgets?',
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
    _nlController.dispose();
    _askController.dispose();
    _speech.cancel();
    super.dispose();
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
        setState(() => _nlController.text = result.recognizedWords);
        if (result.finalResult) {
          setState(() => _listening = false);
          if (result.recognizedWords.trim().isNotEmpty) _parseAndReview();
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

  // ── Natural-language expense entry ──────────────────────────────────────────

  Future<void> _parseAndReview() async {
    final text = _nlController.text.trim();
    if (text.isEmpty) return;

    final ai = context.read<AiService>();
    setState(() => _parsing = true);
    try {
      final draft = await ai.parseNaturalLanguage(text);
      if (!mounted) return;
      if (draft == null) {
        AppSnackbar.info(context, "Couldn't find an expense in that sentence.");
        return;
      }
      await _showReviewSheet(draft);
    } catch (e) {
      if (mounted) AppSnackbar.error(context, 'AI error: ${_friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _parsing = false);
    }
  }

  Future<void> _showReviewSheet(ParsedExpenseDraft draft) async {
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
                        await expenseService.addExpense(
                          ExpenseModel(
                            id: const Uuid().v4(),
                            userId: uid,
                            title:
                                titleController.text.trim().isEmpty
                                    ? 'Expense'
                                    : titleController.text.trim(),
                            description: 'Added via AI',
                            amount: amount,
                            category: category,
                            createdAt: date,
                            accountId: accountId,
                          ),
                        );
                        navigator.pop();
                        _nlController.clear();
                        if (mounted) {
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

  // ── Free-form Q&A + advisors ────────────────────────────────────────────────

  Future<void> _ask([String? preset]) async {
    if (preset != null) _askController.text = preset;
    final question = _askController.text.trim();
    if (question.isEmpty) return;
    FocusScope.of(context).unfocus();

    final ai = context.read<AiService>();
    final ctx = _buildDetailedContext();
    setState(() => _loadingAnswer = true);
    try {
      final answer = await ai.answerQuery(question, ctx);
      if (mounted) setState(() => _answer = answer);
    } catch (e) {
      if (mounted) AppSnackbar.error(context, 'AI error: ${_friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _loadingAnswer = false);
    }
  }

  Future<void> _generateInsights() async {
    final expenseService = context.read<ExpenseService>();
    if (expenseService.expenses.isEmpty) {
      AppSnackbar.info(context, 'Add some expenses first to get insights.');
      return;
    }
    final ai = context.read<AiService>();
    final summary = _buildSummary(
      expenseService,
      context.read<BudgetService>(),
    );
    setState(() => _loadingInsights = true);
    try {
      final result = await ai.generateInsights(summary);
      if (mounted) setState(() => _insights = result);
    } catch (e) {
      if (mounted) AppSnackbar.error(context, 'AI error: ${_friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _loadingInsights = false);
    }
  }

  Future<void> _generateTips({required bool investment}) async {
    final expenseService = context.read<ExpenseService>();
    if (expenseService.expenses.isEmpty) {
      AppSnackbar.info(context, 'Add some expenses first to get tips.');
      return;
    }
    final ai = context.read<AiService>();
    final summary = _buildSummary(
      expenseService,
      context.read<BudgetService>(),
    );
    setState(() {
      if (investment) {
        _loadingInvestment = true;
      } else {
        _loadingSaving = true;
      }
    });
    try {
      final result = await ai.generateTips(summary, investment: investment);
      if (mounted) {
        setState(() {
          if (investment) {
            _investmentTips = result;
          } else {
            _savingTips = result;
          }
        });
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, 'AI error: ${_friendlyError(e)}');
    } finally {
      if (mounted) {
        setState(() {
          _loadingInvestment = false;
          _loadingSaving = false;
        });
      }
    }
  }

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

  /// Richer context for free-form questions — recent dated transactions plus
  /// account balances, so questions like "last week" can be answered.
  String _buildDetailedContext() {
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
      appBar: AppBar(title: const Text('AI Assistant')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _buildAskCard(),
          const SizedBox(height: AppSpacing.md),
          _buildAdvisor(
            icon: Icons.insights_rounded,
            accent: c.brand,
            title: 'Spending insights',
            subtitle: 'Patterns and where your money goes',
            buttonLabel: 'Analyze my spending',
            refreshLabel: 'Refresh insights',
            output: _insights,
            loading: _loadingInsights,
            onGenerate: _generateInsights,
          ),
          const SizedBox(height: AppSpacing.md),
          _buildAdvisor(
            icon: Icons.savings_rounded,
            accent: c.positive,
            title: 'Saving tips',
            subtitle: 'Practical ways to cut back',
            buttonLabel: 'Get saving tips',
            refreshLabel: 'Refresh tips',
            output: _savingTips,
            loading: _loadingSaving,
            onGenerate: () => _generateTips(investment: false),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildAdvisor(
            icon: Icons.trending_up_rounded,
            accent: c.info,
            title: 'Investment tips',
            subtitle: 'Ideas to grow any surplus',
            buttonLabel: 'Get investment ideas',
            refreshLabel: 'Refresh ideas',
            output: _investmentTips,
            loading: _loadingInvestment,
            onGenerate: () => _generateTips(investment: true),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildNaturalLanguageCard(),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: AppRadii.card,
        border: Border.all(color: c.cardBorder),
      ),
      child: child,
    );
  }

  Widget _cardHeader(IconData icon, Color accent, String title, String sub) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: Icon(icon, color: accent, size: 22),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleSmall),
              Text(
                sub,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.colors.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAskCard() {
    final c = context.colors;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            Icons.auto_awesome_rounded,
            c.brand,
            'Ask your finances',
            'Question your transactions in plain English',
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _askController,
            minLines: 1,
            maxLines: 3,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _ask(),
            decoration: InputDecoration(
              hintText: 'e.g. What did I spend last week?',
              suffixIcon: IconButton(
                tooltip: 'Ask',
                icon: Icon(Icons.send_rounded, color: c.brand),
                onPressed: _loadingAnswer ? null : () => _ask(),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final p in _suggestedPrompts)
                AppChip(
                  label: p,
                  icon: Icons.bolt_rounded,
                  onTap: _loadingAnswer ? null : () => _ask(p),
                ),
            ],
          ),
          if (_loadingAnswer) ...[
            const SizedBox(height: AppSpacing.md),
            _thinking('Thinking…'),
          ],
          if (_answer != null && !_loadingAnswer) ...[
            const SizedBox(height: AppSpacing.md),
            _outputBox(_answer!, c.brand),
          ],
        ],
      ),
    );
  }

  Widget _buildAdvisor({
    required IconData icon,
    required Color accent,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required String refreshLabel,
    required String? output,
    required bool loading,
    required VoidCallback onGenerate,
  }) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(icon, accent, title, subtitle),
          if (output != null && !loading) ...[
            const SizedBox(height: AppSpacing.md),
            _outputBox(output, accent),
          ],
          if (loading) ...[
            const SizedBox(height: AppSpacing.md),
            _thinking('Analyzing…'),
          ],
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: loading ? null : onGenerate,
              icon: Icon(
                output == null
                    ? Icons.auto_awesome_rounded
                    : Icons.refresh_rounded,
              ),
              label: Text(output == null ? buttonLabel : refreshLabel),
              style: OutlinedButton.styleFrom(foregroundColor: accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thinking(String label) {
    final c = context.colors;
    return Row(
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: c.brand),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: c.muted),
        ),
      ],
    );
  }

  Widget _outputBox(String markdown, Color accent) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: AppRadii.card,
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: MarkdownText(
        markdown,
        baseStyle: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(height: 1.45, color: c.muted),
      ),
    );
  }

  Widget _buildNaturalLanguageCard() {
    final c = context.colors;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            Icons.mic_none_rounded,
            c.accent,
            'Add expense by voice or text',
            'Say it naturally and Gemini fills the details',
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _nlController,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'e.g. Spent ₹450 on groceries today',
              suffixIcon: IconButton(
                tooltip: _listening ? 'Stop' : 'Speak',
                icon: Icon(
                  _listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                  color: _listening ? c.negative : c.accent,
                ),
                onPressed: _toggleListen,
              ),
            ),
          ),
          if (_listening) ...[
            const SizedBox(height: AppSpacing.xs),
            _thinking('Listening… speak now'),
          ],
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _parsing ? null : _parseAndReview,
              icon:
                  _parsing
                      ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: c.onBrand,
                        ),
                      )
                      : const Icon(Icons.auto_fix_high_rounded),
              label: Text(_parsing ? 'Thinking…' : 'Parse with AI'),
            ),
          ),
        ],
      ),
    );
  }
}
