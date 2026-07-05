import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'package:provider/provider.dart';
import '../../models/account_model.dart';
import '../../services/account_service.dart';

/// Moves money between two of the user's own accounts. Does not affect spending
/// totals or budgets.
class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  static const _teal = Color(0xFF0F766E);
  static const _coral = Color(0xFFF97316);

  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String? _fromId;
  String? _toId;

  @override
  void initState() {
    super.initState();
    final accounts = context.read<AccountService>().accounts;
    if (accounts.isNotEmpty) _fromId = accounts.first.id;
    if (accounts.length > 1) _toId = accounts[1].id;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fromId == null || _toId == null) return;

    final service = context.read<AccountService>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await service.transfer(
        fromAccountId: _fromId!,
        toAccountId: _toId!,
        amount: double.parse(_amountController.text.trim()),
        note: _noteController.text.trim(),
      );
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Transfer complete!'),
          backgroundColor: _teal,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: _coral,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = context.watch<AccountService>().accounts;

    return Scaffold(
      appBar: AppBar(title: const Text('Transfer')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAccountDropdown(
                label: 'From',
                value: _fromId,
                accounts: accounts,
                onChanged: (v) => setState(() => _fromId = v),
              ),
              const SizedBox(height: 16),
              Center(
                child: Icon(Icons.arrow_downward, color: context.colors.faint),
              ),
              const SizedBox(height: 16),
              _buildAccountDropdown(
                label: 'To',
                value: _toId,
                accounts: accounts,
                onChanged: (v) => setState(() => _toId = v),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount (₹)',
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
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Note (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
              const SizedBox(height: 8),
              if (_fromId != null && _fromId == _toId)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Pick two different accounts.',
                    style: TextStyle(color: _coral),
                  ),
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed:
                      (_fromId != null && _toId != null && _fromId != _toId)
                          ? _submit
                          : null,
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text(
                    'Transfer',
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

  Widget _buildAccountDropdown({
    required String label,
    required String? value,
    required List<AccountModel> accounts,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.account_balance_wallet),
      ),
      items:
          accounts.map((a) {
            return DropdownMenuItem(
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
            );
          }).toList(),
      onChanged: onChanged,
    );
  }
}
