import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/group_model.dart';
import '../../models/split_model.dart';
import '../../models/user_model.dart';
import '../../services/group_service.dart';
import '../../services/auth_service.dart';
import 'package:uuid/uuid.dart';

class GroupSettleScreen extends StatefulWidget {
  final GroupModel group;

  const GroupSettleScreen({super.key, required this.group});

  @override
  State<GroupSettleScreen> createState() => _GroupSettleScreenState();
}

class _GroupSettleScreenState extends State<GroupSettleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _amountController = TextEditingController();
  bool _isLoading = false;
  List<SplitModel> _groupSplits = [];
  final Map<String, UserModel> _memberDetails = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMemberDetails();
    _loadGroupSplits();
  }

  Future<void> _loadMemberDetails() async {
    final authService = context.read<AuthService>();
    for (final memberId in widget.group.allMemberIds) {
      final user = await authService.getUserById(memberId);
      if (user != null && mounted) {
        setState(() => _memberDetails[memberId] = user);
      }
    }
  }

  String _nameFor(String userId) {
    final currentUserId = context.read<AuthService>().currentUser?.uid;
    if (userId == currentUserId) return 'You';
    return _memberDetails[userId]?.displayName ?? 'Member';
  }

  String _initialFor(String userId) {
    final name = _nameFor(userId);
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadGroupSplits() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final groupService = context.read<GroupService>();
      await groupService.loadUserSplits();
      final allSplits = groupService.splits;
      _groupSplits =
          allSplits.where((split) => split.groupId == widget.group.id).toList();
    } catch (e) {
      debugPrint('Error loading group splits: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _settleSplitAmount(SplitModel split) async {
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an amount'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final currentUserId = context.read<AuthService>().currentUser!.uid;
    final remainingAmount = split.getRemainingAmount(currentUserId);

    if (amount > remainingAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Amount cannot exceed ₹${remainingAmount.toInt()}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final settlement = SettlementModel(
        id: const Uuid().v4(),
        splitId: split.id,
        fromUserId: currentUserId,
        toUserId: split.paidBy,
        amount: amount,
        settledAt: DateTime.now(),
        notes: 'Split settlement',
        status: SettlementStatus.pending,
        recordedBy: currentUserId,
      );

      await context.read<GroupService>().recordSettlement(split.id, settlement);
      await _loadGroupSplits(); // Refresh splits

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Payment recorded — waiting for the other person to confirm.',
            ),
            backgroundColor: Color(0xFF0F766E),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error settling split: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthService>().currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settle Up'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'You Owe'), Tab(text: 'Owed to You')],
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                controller: _tabController,
                children: [
                  _buildYouOweTab(currentUserId),
                  _buildOwedToYouTab(currentUserId),
                ],
              ),
    );
  }

  Widget _buildYouOweTab(String currentUserId) {
    final userOwedSplits =
        _groupSplits
            .where(
              (split) =>
                  split.participants.contains(currentUserId) &&
                  split.paidBy != currentUserId &&
                  split.hasAcceptedShare(currentUserId) &&
                  split.getRemainingAmount(currentUserId) > 0,
            )
            .toList();

    final totalOwedAmount = userOwedSplits.fold(
      0.0,
      (sum, split) => sum + split.getRemainingAmount(currentUserId),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total Owed Summary
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color:
                  totalOwedAmount > 0 ? const Color(0xFFF97316) : Colors.green,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text(
                  'Total Amount Owed from Splits',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '₹${totalOwedAmount.toInt()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${userOwedSplits.length} outstanding splits',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (userOwedSplits.isEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'All Splits Settled!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You have no outstanding amounts from group splits',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.colors.muted, fontSize: 16),
                  ),
                ],
              ),
            ),
          ] else ...[
            const Text(
              'Outstanding Splits',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F766E),
              ),
            ),
            const SizedBox(height: 16),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: userOwedSplits.length,
              itemBuilder: (context, index) {
                final split = userOwedSplits[index];
                return _buildSplitCard(split, currentUserId);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSplitCard(SplitModel split, String currentUserId) {
    final remainingAmount = split.getRemainingAmount(currentUserId);
    final totalOwed = split.getAmountOwedBy(currentUserId);
    final settledAmount = split.getTotalSettledAmount(currentUserId);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.receipt,
                    color: Color(0xFFF97316),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        split.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        DateFormat('MMM d, y').format(split.createdAt),
                        style: TextStyle(
                          color: context.colors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${remainingAmount.toInt()}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFFF97316),
                      ),
                    ),
                    Text(
                      'remaining',
                      style: TextStyle(
                        color: context.colors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            if (split.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                split.description,
                style: TextStyle(color: context.colors.muted, fontSize: 14),
              ),
            ],

            const SizedBox(height: 12),

            // Settlement Progress
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Paid: ₹${settledAmount.toInt()}',
                            style: TextStyle(
                              color: context.colors.muted,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'Total: ₹${totalOwed.toInt()}',
                            style: TextStyle(
                              color: context.colors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: totalOwed > 0 ? settledAmount / totalOwed : 0,
                        backgroundColor: context.colors.cardBorder,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF0F766E),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Settle Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        () => _showSettleSplitDialog(split, currentUserId),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF0F766E)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Settle Partial',
                      style: TextStyle(color: Color(0xFF0F766E)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        () => _settleFullSplitAmount(split, currentUserId),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Settle Full'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSettleSplitDialog(SplitModel split, String currentUserId) {
    showDialog(
      context: context,
      builder: (context) {
        final remainingAmount = split.getRemainingAmount(currentUserId);
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Settle Partial Amount'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Enter amount to settle (max ₹${remainingAmount.toInt()}):'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixIcon: Icon(Icons.currency_rupee),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(controller.text);
                if (amount == null || amount <= 0 || amount > remainingAmount) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Please enter a valid amount (max ₹${remainingAmount.toInt()})',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.pop(context);
                _amountController.text = amount.toString();
                _settleSplitAmount(split);
              },
              style: ElevatedButton.styleFrom(),
              child: const Text('Settle'),
            ),
          ],
        );
      },
    );
  }

  void _settleFullSplitAmount(SplitModel split, String currentUserId) {
    final remainingAmount = split.getRemainingAmount(currentUserId);
    if (remainingAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No remaining amount to settle.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    _amountController.text = remainingAmount.toString();
    _settleSplitAmount(split);
  }

  Widget _buildOwedToYouTab(String currentUserId) {
    final splitsOwedToUser =
        _groupSplits
            .where(
              (split) =>
                  split.paidBy == currentUserId &&
                  split.participants.any(
                    (p) =>
                        p != currentUserId &&
                        split.hasAcceptedShare(p) &&
                        split.getRemainingAmount(p) > 0,
                  ),
            )
            .toList();

    final totalOwedToUser = splitsOwedToUser.fold(
      0.0,
      (sum, split) =>
          sum +
          split.participants
              .where((p) => p != currentUserId)
              .fold(0.0, (pSum, p) => pSum + split.getRemainingAmount(p)),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total Owed to User Summary
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: totalOwedToUser > 0 ? Colors.green : Colors.grey,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text(
                  'Total Amount Owed to You',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '₹${totalOwedToUser.toInt()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${splitsOwedToUser.length} pending splits',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (splitsOwedToUser.isEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    color: context.colors.faint,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Outstanding Amounts',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: context.colors.faint,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No one owes you money from group splits',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.colors.muted, fontSize: 16),
                  ),
                ],
              ),
            ),
          ] else ...[
            const Text(
              'Amounts Owed to You',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F766E),
              ),
            ),
            const SizedBox(height: 16),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: splitsOwedToUser.length,
              itemBuilder: (context, index) {
                final split = splitsOwedToUser[index];
                return _buildOwedToYouSplitCard(split, currentUserId);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOwedToYouSplitCard(SplitModel split, String currentUserId) {
    final participantsWhoOwe =
        split.participants
            .where(
              (p) =>
                  p != currentUserId &&
                  split.hasAcceptedShare(p) &&
                  split.getRemainingAmount(p) > 0,
            )
            .toList();

    final totalOwedForThisSplit = participantsWhoOwe.fold(
      0.0,
      (sum, p) => sum + split.getRemainingAmount(p),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.trending_up,
                    color: Colors.green,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        split.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        DateFormat('MMM d, y').format(split.createdAt),
                        style: TextStyle(
                          color: context.colors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${totalOwedForThisSplit.toInt()}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.green,
                      ),
                    ),
                    Text(
                      'owed to you',
                      style: TextStyle(
                        color: context.colors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            if (split.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                split.description,
                style: TextStyle(color: context.colors.muted, fontSize: 14),
              ),
            ],

            const SizedBox(height: 12),

            // Show who owes money
            const Text(
              'Outstanding from:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Color(0xFF0F766E),
              ),
            ),
            const SizedBox(height: 8),

            ...participantsWhoOwe.map((participantId) {
              final owedAmount = split.getRemainingAmount(participantId);
              final totalOwedByParticipant = split.getAmountOwedBy(
                participantId,
              );
              final settledByParticipant = split.getTotalSettledAmount(
                participantId,
              );

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.colors.surfaceSunken,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.colors.surfaceSunken),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.green.withValues(alpha: 0.1),
                      child: Text(
                        _initialFor(participantId),
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _nameFor(participantId),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Paid: ₹${settledByParticipant.toInt()} / ₹${totalOwedByParticipant.toInt()}',
                            style: TextStyle(
                              color: context.colors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${owedAmount.toInt()}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'remaining',
                          style: TextStyle(
                            color: context.colors.muted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 16),

            // Action Buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _markAsReceived(split, participantsWhoOwe),
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Mark as Received'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _markAsReceived(SplitModel split, List<String> participantIds) {
    showDialog(
      context: context,
      builder: (context) {
        Map<String, bool> selectedParticipants = {};
        Map<String, TextEditingController> amountControllers = {};

        for (String participantId in participantIds) {
          selectedParticipants[participantId] = false;
          amountControllers[participantId] = TextEditingController(
            text: split.getRemainingAmount(participantId).toInt().toString(),
          );
        }

        return StatefulBuilder(
          builder:
              (context, setState) => AlertDialog(
                title: const Text('Mark Payment as Received'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select who has paid you and enter the amount:',
                      ),
                      const SizedBox(height: 16),
                      ...participantIds.map((participantId) {
                        final owedAmount = split.getRemainingAmount(
                          participantId,
                        );
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color:
                                  selectedParticipants[participantId]!
                                      ? const Color(0xFF0F766E)
                                      : context.colors.cardBorder,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            color:
                                selectedParticipants[participantId]!
                                    ? const Color(
                                      0xFF0F766E,
                                    ).withValues(alpha: 0.1)
                                    : null,
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Checkbox(
                                    value: selectedParticipants[participantId],
                                    onChanged: (value) {
                                      setState(() {
                                        selectedParticipants[participantId] =
                                            value ?? false;
                                      });
                                    },
                                    activeColor: const Color(0xFF0F766E),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _nameFor(participantId),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          'Owes: ₹${owedAmount.toInt()}',
                                          style: TextStyle(
                                            color: context.colors.muted,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (selectedParticipants[participantId]!) ...[
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: amountControllers[participantId],
                                  decoration: InputDecoration(
                                    labelText: 'Amount Received (₹)',
                                    border: const OutlineInputBorder(),
                                    prefixIcon: const Icon(
                                      Icons.currency_rupee,
                                    ),
                                    helperText: 'Max: ₹${owedAmount.toInt()}',
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final selectedCount =
                          selectedParticipants.values.where((v) => v).length;
                      if (selectedCount == 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select at least one member'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      Navigator.pop(context);
                      await _processReceivedPayments(
                        split,
                        selectedParticipants,
                        amountControllers,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Mark Received'),
                  ),
                ],
              ),
        );
      },
    );
  }

  Future<void> _processReceivedPayments(
    SplitModel split,
    Map<String, bool> selectedParticipants,
    Map<String, TextEditingController> amountControllers,
  ) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUserId = context.read<AuthService>().currentUser!.uid;
      List<String> processedMembers = [];

      for (String participantId in selectedParticipants.keys) {
        if (selectedParticipants[participantId]!) {
          final amountText = amountControllers[participantId]!.text;
          final amount = double.tryParse(amountText);
          final maxAmount = split.getRemainingAmount(participantId);

          final memberName = _nameFor(participantId);

          if (amount == null || amount <= 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Invalid amount for $memberName'),
                backgroundColor: Colors.red,
              ),
            );
            continue;
          }

          if (amount > maxAmount) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Amount cannot exceed ₹${maxAmount.toInt()} for $memberName',
                ),
                backgroundColor: Colors.red,
              ),
            );
            continue;
          }

          final settlement = SettlementModel(
            id: const Uuid().v4(),
            splitId: split.id,
            fromUserId: participantId,
            toUserId: currentUserId,
            amount: amount,
            settledAt: DateTime.now(),
            notes: 'Payment received and marked by $currentUserId',
            status: SettlementStatus.pending,
            recordedBy: currentUserId,
          );

          await context.read<GroupService>().recordSettlement(
            split.id,
            settlement,
          );
          processedMembers.add(memberName);
        }
      }

      await _loadGroupSplits(); // Refresh splits

      setState(() {
        _isLoading = false;
      });

      if (mounted && processedMembers.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Recorded — waiting for ${processedMembers.join(', ')} to confirm.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing payments: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
