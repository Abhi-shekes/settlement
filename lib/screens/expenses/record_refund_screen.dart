import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'package:provider/provider.dart';
import '../../models/expense_model.dart';
import '../../services/expense_service.dart';
import '../../services/account_service.dart';

/// Records a refund or reversal against an existing [original] expense. The
/// original is never modified; a linked credit is created that adjusts balances
/// and reports.
class RecordRefundScreen extends StatefulWidget {
  final ExpenseModel original;

  const RecordRefundScreen({super.key, required this.original});

  @override
  State<RecordRefundScreen> createState() => _RecordRefundScreenState();
}

class _RecordRefundScreenState extends State<RecordRefundScreen> {
  static const _teal = Color(0xFF0F766E);
  static const _coral = Color(0xFFF97316);

  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _selectedAccountId;

  late final double _alreadyRefunded;
  late final double _refundable;

  @override
  void initState() {
    super.initState();
    final service = context.read<ExpenseService>();
    _alreadyRefunded = service.totalRefundedFor(widget.original.id);
    _refundable = widget.original.amount - _alreadyRefunded;
    // Default to a full refund of the remaining refundable amount.
    if (_refundable > 0) {
      _amountController.text = _refundable.toStringAsFixed(
        _refundable.truncateToDouble() == _refundable ? 0 : 2,
      );
    }
    _selectedAccountId = widget.original.accountId;
    context.read<AccountService>().loadUserAccounts();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final service = context.read<ExpenseService>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await service.recordRefund(
        widget.original,
        amount: double.parse(_amountController.text.trim()),
        accountId: _selectedAccountId,
        note: _noteController.text,
      );
      if (!mounted) return;
      navigator.pop(true);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Refund recorded!'),
          backgroundColor: _teal,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: _coral),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Refund'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryCard(),
              const SizedBox(height: 20),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Refund Amount (₹)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter an amount';
                  }
                  final amount = double.tryParse(value.trim());
                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid amount';
                  }
                  if (amount > _refundable + 0.001) {
                    return 'Cannot exceed refundable ₹${_refundable.toStringAsFixed(2)}';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Consumer<AccountService>(
                builder: (context, accountService, child) {
                  if (accountService.accounts.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  if (_selectedAccountId != null &&
                      accountService.getAccountById(_selectedAccountId) ==
                          null) {
                    _selectedAccountId = null;
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: DropdownButtonFormField<String?>(
                      initialValue: _selectedAccountId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Credit to account',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.account_balance_wallet),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('None'),
                        ),
                        ...accountService.accounts.map(
                          (a) => DropdownMenuItem<String?>(
                            value: a.id,
                            child: Row(
                              children: [
                                Icon(a.icon, size: 18, color: a.color),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${a.name} (${a.formattedBalance})',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      onChanged:
                          (value) => setState(() => _selectedAccountId = value),
                    ),
                  );
                },
              ),
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Reason / Note (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _refundable > 0 ? _submit : null,
                  icon: const Icon(Icons.replay),
                  label: const Text(
                    'Record Refund',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surfaceSunken,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.original.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          _row('Original amount', '₹${widget.original.amount.toInt()}'),
          if (_alreadyRefunded > 0)
            _row('Already refunded', '₹${_alreadyRefunded.toInt()}'),
          _row(
            'Refundable',
            '₹${_refundable.toStringAsFixed(_refundable.truncateToDouble() == _refundable ? 0 : 2)}',
            highlight: true,
          ),
          if (_refundable <= 0)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'This expense has been fully refunded.',
                style: TextStyle(color: _coral),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: context.colors.muted)),
          Text(
            value,
            style: TextStyle(
              fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
              color: highlight ? _teal : context.colors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
