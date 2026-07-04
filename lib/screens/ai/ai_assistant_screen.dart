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

class AiAssistantScreen extends StatefulWidget {
  /// When true (e.g. opened from the "Voice add" home-screen widget), starts
  /// listening as soon as the screen is ready.
  final bool startVoice;

  const AiAssistantScreen({super.key, this.startVoice = false});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  static const _teal = Color(0xFF008080);
  static const _coral = Color(0xFFFF7F50);

  final _nlController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  String? _insights;
  bool _loadingInsights = false;
  bool _parsing = false;
  bool _speechAvailable = false;
  bool _listening = false;

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
    _speech.cancel();
    super.dispose();
  }

  Future<void> _toggleListen() async {
    final messenger = ScaffoldMessenger.of(context);
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
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Microphone/speech not available on this device.'),
          backgroundColor: _coral,
        ),
      );
      return;
    }

    setState(() => _listening = true);
    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() => _nlController.text = result.recognizedWords);
        // Once the recogniser finalises the phrase, parse it automatically.
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

  Future<void> _parseAndReview() async {
    final text = _nlController.text.trim();
    if (text.isEmpty) return;

    final ai = context.read<AiService>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _parsing = true);
    try {
      final draft = await ai.parseNaturalLanguage(text);
      if (!mounted) return;
      if (draft == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text("Couldn't find an expense in that sentence."),
            backgroundColor: _coral,
          ),
        );
        return;
      }
      await _showReviewSheet(draft);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('AI error: ${_friendlyError(e)}'),
          backgroundColor: _coral,
        ),
      );
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: _teal),
                      const SizedBox(width: 8),
                      const Text(
                        'Review expense',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Amount (₹)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ExpenseCategory>(
                    initialValue: category,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
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
                  const SizedBox(height: 12),
                  if (accountService.accounts.isNotEmpty)
                    DropdownButtonFormField<String?>(
                      initialValue: accountId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Paid from',
                        border: OutlineInputBorder(),
                      ),
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
                  const SizedBox(height: 12),
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
                      decoration: const InputDecoration(
                        labelText: 'Date',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(DateFormat('MMM d, y').format(date)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text('Save Expense'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
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
                        final rootMessenger = ScaffoldMessenger.of(context);
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
                        rootMessenger.showSnackBar(
                          const SnackBar(
                            content: Text('Expense added!'),
                            backgroundColor: _teal,
                          ),
                        );
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

  Future<void> _generateInsights() async {
    final expenseService = context.read<ExpenseService>();
    final budgetService = context.read<BudgetService>();
    final ai = context.read<AiService>();
    final messenger = ScaffoldMessenger.of(context);

    if (expenseService.expenses.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Add some expenses first to get insights.'),
        ),
      );
      return;
    }

    setState(() => _loadingInsights = true);
    try {
      final summary = _buildSummary(expenseService, budgetService);
      final result = await ai.generateInsights(summary);
      if (!mounted) return;
      setState(() => _insights = result);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('AI error: ${_friendlyError(e)}'),
          backgroundColor: _coral,
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingInsights = false);
    }
  }

  String _buildSummary(ExpenseService expenses, BudgetService budgets) {
    final now = DateTime.now();
    final buffer = StringBuffer();
    buffer.writeln('Spending summary for ${DateFormat('MMMM y').format(now)}:');
    buffer.writeln('Total spent: ₹${expenses.getTotalExpenseAmount().toInt()}');

    buffer.writeln('\nBy category:');
    final byCategory = expenses.getCategoryWiseExpenses();
    byCategory.forEach((category, amount) {
      if (amount > 0) {
        final budget = budgets.getBudgetForCategory(category);
        final budgetNote =
            (budget != null && budget.amount > 0)
                ? ' (budget ₹${budget.amount.toInt()})'
                : '';
        buffer.writeln(
          '- ${category.categoryDisplayName}: ₹${amount.toInt()}$budgetNote',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant'),
        backgroundColor: _teal,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildNaturalLanguageCard(),
          const SizedBox(height: 20),
          _buildInsightsCard(),
        ],
      ),
    );
  }

  Widget _buildNaturalLanguageCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.auto_awesome, color: _teal),
                SizedBox(width: 8),
                Text(
                  'Add expense by typing',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Type or speak it naturally and Gemini fills in the details.',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nlController,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'e.g. Spent ₹450 on groceries today',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _listening ? 'Stop' : 'Speak',
                  icon: Icon(
                    _listening ? Icons.mic : Icons.mic_none,
                    color: _listening ? _coral : _teal,
                  ),
                  onPressed: _toggleListen,
                ),
              ),
            ),
            if (_listening)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _coral,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Listening… speak now',
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _parsing ? null : _parseAndReview,
                icon:
                    _parsing
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Icon(Icons.auto_fix_high),
                label: Text(_parsing ? 'Thinking…' : 'Parse with AI'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.insights, color: _teal),
                SizedBox(width: 8),
                Text(
                  'Spending insights',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Let Gemini analyze your spending and suggest ways to save.',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            if (_insights != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _teal.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _teal.withValues(alpha: 0.2)),
                ),
                child: Text(_insights!, style: const TextStyle(height: 1.4)),
              ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _loadingInsights ? null : _generateInsights,
                icon:
                    _loadingInsights
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.analytics_outlined),
                label: Text(
                  _loadingInsights
                      ? 'Analyzing…'
                      : _insights == null
                      ? 'Analyze my spending'
                      : 'Refresh insights',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _teal,
                  side: const BorderSide(color: _teal),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
