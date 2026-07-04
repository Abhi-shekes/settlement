import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/expense_model.dart';
import '../../services/expense_service.dart';
import '../../services/account_service.dart';
import '../../services/auth_service.dart';
import '../../services/sms_import_service.dart';
import '../../utils/transaction_parser.dart';

/// Editable, user-reviewable draft of a parsed transaction.
class _Candidate {
  final TextEditingController titleController;
  final TextEditingController amountController;
  ExpenseCategory category;
  DateTime date;
  bool selected = true;

  _Candidate({
    required String title,
    required double amount,
    required this.category,
    required this.date,
  }) : titleController = TextEditingController(text: title),
       amountController = TextEditingController(
         text: amount.toStringAsFixed(
           amount.truncateToDouble() == amount ? 0 : 2,
         ),
       );

  void dispose() {
    titleController.dispose();
    amountController.dispose();
  }
}

class ScanMessagesScreen extends StatefulWidget {
  const ScanMessagesScreen({super.key});

  @override
  State<ScanMessagesScreen> createState() => _ScanMessagesScreenState();
}

class _ScanMessagesScreenState extends State<ScanMessagesScreen> {
  static const _teal = Color(0xFF008080);
  static const _coral = Color(0xFFFF7F50);

  final _smsImport = SmsImportService();
  final _pasteController = TextEditingController();
  final List<_Candidate> _candidates = [];

  String? _accountId;
  bool _scanning = false;
  bool _scannedEmpty = false;

  @override
  void initState() {
    super.initState();
    final accountService = context.read<AccountService>();
    accountService.loadUserAccounts();
    if (accountService.accounts.isNotEmpty) {
      _accountId = accountService.accounts.first.id;
    }
  }

  @override
  void dispose() {
    _pasteController.dispose();
    for (final c in _candidates) {
      c.dispose();
    }
    super.dispose();
  }

  void _addCandidate(ParsedTransaction p) {
    _candidates.insert(
      0,
      _Candidate(
        title: p.merchant ?? 'Expense',
        amount: p.amount!,
        category: p.category,
        date: p.date ?? DateTime.now(),
      ),
    );
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _scannedEmpty = false;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final parsed = await _smsImport.scanInbox();
      if (!mounted) return;
      setState(() {
        for (final p in parsed) {
          _addCandidate(p);
        }
        _scannedEmpty = parsed.isEmpty;
      });
    } on SmsPermissionDeniedException {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('SMS permission is needed to scan messages.'),
          backgroundColor: _coral,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Scan failed: $e'), backgroundColor: _coral),
      );
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _parsePasted() {
    final text = _pasteController.text.trim();
    if (text.isEmpty) return;
    final parsed = TransactionParser.parse(text);
    final messenger = ScaffoldMessenger.of(context);
    if (!parsed.isTransaction) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Couldn't find a transaction in that message."),
          backgroundColor: _coral,
        ),
      );
      return;
    }
    setState(() {
      _addCandidate(parsed);
      _pasteController.clear();
    });
  }

  Future<void> _import() async {
    final selected = _candidates.where((c) => c.selected).toList();
    if (selected.isEmpty) return;

    final expenseService = context.read<ExpenseService>();
    final uid = context.read<AuthService>().currentUser?.uid;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (uid == null) return;

    var added = 0;
    for (final c in selected) {
      final amount = double.tryParse(c.amountController.text.trim());
      if (amount == null || amount <= 0) continue;
      await expenseService.addExpense(
        ExpenseModel(
          id: const Uuid().v4(),
          userId: uid,
          title:
              c.titleController.text.trim().isEmpty
                  ? 'Expense'
                  : c.titleController.text.trim(),
          description: 'Imported from message',
          amount: amount,
          category: c.category,
          createdAt: c.date,
          accountId: _accountId,
        ),
      );
      added++;
    }

    if (!mounted) return;
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text('$added expense${added == 1 ? '' : 's'} imported!'),
        backgroundColor: _teal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _candidates.where((c) => c.selected).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import from Messages'),
        backgroundColor: _teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildAccountSelector(),
                const SizedBox(height: 12),
                _buildActions(),
                const SizedBox(height: 12),
                _buildPasteBox(),
                const SizedBox(height: 16),
                if (_candidates.isEmpty)
                  _buildHint()
                else ...[
                  Text(
                    'Review ${_candidates.length} transaction'
                    '${_candidates.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._candidates.asMap().entries.map(
                    (e) => _buildCandidateCard(e.key, e.value),
                  ),
                ],
              ],
            ),
          ),
          if (_candidates.isNotEmpty)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: selectedCount > 0 ? _import : null,
                    icon: const Icon(Icons.download_done),
                    label: Text(
                      'Import $selectedCount Expense${selectedCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAccountSelector() {
    return Consumer<AccountService>(
      builder: (context, accountService, _) {
        if (accountService.accounts.isEmpty) return const SizedBox.shrink();
        if (_accountId != null &&
            accountService.getAccountById(_accountId) == null) {
          _accountId = null;
        }
        return DropdownButtonFormField<String?>(
          initialValue: _accountId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Import into account',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.account_balance_wallet),
          ),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('None')),
            ...accountService.accounts.map(
              (a) => DropdownMenuItem<String?>(
                value: a.id,
                child: Row(
                  children: [
                    Icon(a.icon, size: 18, color: a.color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(a.name, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            ),
          ],
          onChanged: (value) => setState(() => _accountId = value),
        );
      },
    );
  }

  Widget _buildActions() {
    if (!_smsImport.isSupported) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _scanning ? null : _scan,
        icon:
            _scanning
                ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : const Icon(Icons.sms),
        label: Text(_scanning ? 'Scanning…' : 'Scan phone SMS'),
        style: OutlinedButton.styleFrom(
          foregroundColor: _teal,
          side: const BorderSide(color: _teal),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildPasteBox() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _pasteController,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: 'Paste a bank SMS or email',
            hintText: 'e.g. Rs.499 debited at SWIGGY on 04-Jul-26 via UPI',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.add_circle, color: _teal),
              tooltip: 'Parse',
              onPressed: _parsePasted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHint() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Icon(
            Icons.mark_email_read_outlined,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 8),
          Text(
            _scannedEmpty
                ? 'No transaction messages found in your recent SMS.'
                : _smsImport.isSupported
                ? 'Scan your SMS inbox or paste a bank/card message to '
                    'auto-create expenses.'
                : 'Paste a bank/card SMS or email to auto-create an expense. '
                    '(SMS scanning is available on Android.)',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildCandidateCard(int index, _Candidate c) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 12, 12),
        child: Column(
          children: [
            Row(
              children: [
                Checkbox(
                  value: c.selected,
                  activeColor: _teal,
                  onChanged: (v) => setState(() => c.selected = v ?? false),
                ),
                Expanded(
                  child: TextField(
                    controller: c.titleController,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: 'Remove',
                  onPressed: () {
                    setState(() {
                      c.dispose();
                      _candidates.removeAt(index);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: c.amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Amount (₹)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<ExpenseCategory>(
                    initialValue: c.category,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items:
                        ExpenseCategory.values
                            .map(
                              (cat) => DropdownMenuItem(
                                value: cat,
                                child: Text(
                                  cat.categoryDisplayName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                    onChanged:
                        (v) => setState(() => c.category = v ?? c.category),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                DateFormat('MMM d, y').format(c.date),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
