import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/recurring_transaction_model.dart';
import '../../services/recurring_service.dart';
import 'add_recurring_screen.dart';

class RecurringScreen extends StatefulWidget {
  const RecurringScreen({super.key});

  @override
  State<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends State<RecurringScreen> {
  static const _teal = Color(0xFF0F766E);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RecurringService>().loadUserRecurring();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddRecurringScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New Rule'),
      ),
      body: Consumer<RecurringService>(
        builder: (context, service, _) {
          if (service.isLoading && service.rules.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: _teal));
          }
          if (service.rules.isEmpty) {
            return _buildEmptyState();
          }
          return RefreshIndicator(
            color: _teal,
            onRefresh: () => service.loadUserRecurring(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                ...service.rules.map((r) => _buildRuleCard(service, r)),
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
            Icon(Icons.autorenew, size: 72, color: context.colors.faint),
            const SizedBox(height: 16),
            const Text(
              'No recurring transactions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Set up salary, rent, subscriptions, EMIs, or bills once and the '
              'app records them automatically on schedule.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleCard(
    RecurringService service,
    RecurringTransactionModel rule,
  ) {
    final active = rule.isActive;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: (active ? _teal : Colors.grey).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.autorenew, color: active ? _teal : Colors.grey),
        ),
        title: Text(
          rule.title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Text(
          active
              ? '${rule.frequency.displayName} • Next ${DateFormat('MMM d, y').format(rule.nextDueDate)}'
              : '${rule.frequency.displayName} • Paused',
          style: TextStyle(color: context.colors.muted),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              rule.formattedAmount,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: _teal,
              ),
            ),
            Switch(
              value: active,
              activeThumbColor: _teal,
              onChanged: (_) => service.toggleActive(rule),
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddRecurringScreen(rule: rule),
            ),
          );
        },
      ),
    );
  }
}
