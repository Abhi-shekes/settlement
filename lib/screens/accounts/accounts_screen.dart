import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'package:provider/provider.dart';
import '../../models/account_model.dart';
import '../../services/account_service.dart';
import 'add_account_screen.dart';
import 'transfer_screen.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  static const _teal = Color(0xFF0F766E);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AccountService>().loadUserAccounts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          Consumer<AccountService>(
            builder: (context, service, _) {
              if (service.accounts.length < 2) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Transfer',
                icon: const Icon(Icons.swap_horiz),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TransferScreen(),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddAccountScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Account'),
      ),
      body: Consumer<AccountService>(
        builder: (context, service, _) {
          if (service.isLoading && service.accounts.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: _teal));
          }
          if (service.accounts.isEmpty) {
            return _buildEmptyState();
          }
          return RefreshIndicator(
            color: _teal,
            onRefresh: () => service.loadUserAccounts(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                _buildNetWorthCard(service.getTotalBalance()),
                const SizedBox(height: 16),
                ...service.accounts.map((a) => _buildAccountCard(a)),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 72,
              color: context.colors.faint,
            ),
            const SizedBox(height: 16),
            const Text(
              'No accounts yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Add cash, bank, credit card, or wallet accounts to track balances '
              'and attribute expenses to a payment source.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetWorthCard(double total) {
    final rounded = total.round();
    final sign = rounded < 0 ? '-' : '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_teal, Color(0xFF14B8A6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Balance',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$sign₹${rounded.abs()}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(AccountModel account) {
    final negative = account.balance < 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: account.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(account.icon, color: account.color),
        ),
        title: Text(
          account.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Text(account.type.displayName),
        trailing: Text(
          account.formattedBalance,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: negative ? const Color(0xFFF97316) : _teal,
          ),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddAccountScreen(account: account),
            ),
          );
        },
      ),
    );
  }
}
