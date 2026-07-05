import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'package:provider/provider.dart';
import '../../models/account_model.dart';
import '../../services/account_service.dart';

/// Creates a new account, or edits/deletes an existing one when [account] is
/// provided.
class AddAccountScreen extends StatefulWidget {
  final AccountModel? account;

  const AddAccountScreen({super.key, this.account});

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  static const _teal = Color(0xFF0F766E);
  static const _coral = Color(0xFFF97316);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _balanceController;
  late AccountType _selectedType;

  bool get _isEditing => widget.account != null;

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _nameController = TextEditingController(text: a?.name ?? '');
    _balanceController = TextEditingController(
      text: a != null ? a.balance.toString() : '',
    );
    _selectedType = a?.type ?? AccountType.cash;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final service = context.read<AccountService>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final balance = double.tryParse(_balanceController.text.trim()) ?? 0;

    try {
      if (_isEditing) {
        await service.updateAccount(
          widget.account!.copyWith(
            name: _nameController.text.trim(),
            type: _selectedType,
            balance: balance,
          ),
        );
      } else {
        await service.addAccount(
          name: _nameController.text.trim(),
          type: _selectedType,
          openingBalance: balance,
        );
      }
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Account updated!' : 'Account added!'),
          backgroundColor: _teal,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: _coral),
      );
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Account'),
            content: const Text(
              'Delete this account? Expenses already recorded against it are '
              'kept, but will no longer be linked to an account.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirm != true || !mounted) return;

    final service = context.read<AccountService>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await service.deleteAccount(widget.account!.id);
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Account deleted')));
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
        title: Text(_isEditing ? 'Edit Account' : 'Add Account'),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Account Name',
                  hintText: 'e.g. HDFC Savings, Paytm, Wallet',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              const Text(
                'Account Type',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    AccountType.values.map((type) {
                      final selected = type == _selectedType;
                      return ChoiceChip(
                        selected: selected,
                        onSelected: (_) {
                          setState(() => _selectedType = type);
                        },
                        avatar: Icon(
                          type.icon,
                          size: 18,
                          color: selected ? Colors.white : type.color,
                        ),
                        label: Text(type.displayName),
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : context.colors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                        selectedColor: type.color,
                        backgroundColor: type.color.withValues(alpha: 0.10),
                      );
                    }).toList(),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _balanceController,
                decoration: InputDecoration(
                  labelText:
                      _isEditing
                          ? 'Current Balance (₹)'
                          : 'Opening Balance (₹)',
                  helperText:
                      _selectedType == AccountType.creditCard
                          ? 'Use a negative value for outstanding dues'
                          : null,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.currency_rupee),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  if (double.tryParse(value.trim()) == null) {
                    return 'Enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    _isEditing ? 'Save Changes' : 'Add Account',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
