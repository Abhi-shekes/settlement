import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/split_model.dart';
import '../../services/auth_service.dart';
import '../../services/group_service.dart';

class SplitDetailScreen extends StatefulWidget {
  final SplitModel split;

  const SplitDetailScreen({super.key, required this.split});

  @override
  State<SplitDetailScreen> createState() => _SplitDetailScreenState();
}

class _SplitDetailScreenState extends State<SplitDetailScreen> {
  bool _isLoading = false;
  final _settlementAmountController = TextEditingController();
  final _settlementNotesController = TextEditingController();

  @override
  void dispose() {
    _settlementAmountController.dispose();
    _settlementNotesController.dispose();
    super.dispose();
  }

  void _showSettleUpDialog(String participantId, double remainingAmount) {
    _settlementAmountController.text = remainingAmount.toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Settle Up',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _settlementAmountController,
                decoration: const InputDecoration(
                  labelText: 'Amount (₹)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter an amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null ||
                      amount <= 0 ||
                      amount > remainingAmount) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _settlementNotesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final amount =
                            double.tryParse(_settlementAmountController.text) ??
                            0.0;
                        if (amount <= 0 || amount > remainingAmount) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a valid amount'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        Navigator.pop(context);
                        _settleUp(participantId, amount);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF008080),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Settle Up'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _settleUp(String participantId, double amount) async {
    final settlement = SettlementModel(
      id: const Uuid().v4(),
      splitId: widget.split.id,
      fromUserId: participantId,
      toUserId: widget.split.paidBy,
      amount: amount,
      settledAt: DateTime.now(),
      notes: _settlementNotesController.text.trim(),
    );

    setState(() {
      _isLoading = true;
    });

    try {
      await context.read<GroupService>().addSettlement(
        widget.split.id,
        settlement,
      );

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settlement recorded successfully!'),
            backgroundColor: Color(0xFF008080),
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
            content: Text('Error recording settlement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthService>().currentUser!.uid;
    final isGroupSplit = widget.split.groupId != null;
    final isPayer = widget.split.paidBy == currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Split Details'),
        backgroundColor: const Color(0xFF008080),
        foregroundColor: Colors.white,
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF008080)),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Amount Card
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors:
                                isGroupSplit
                                    ? [Colors.purple, Colors.deepPurple]
                                    : [
                                      const Color(0xFFFF7F50),
                                      Colors.deepOrange,
                                    ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Text(
                              isPayer ? 'You paid' : 'You owe',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.split.formattedTotalAmount,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                widget.split.splitType == SplitType.equal
                                    ? 'Equal Split'
                                    : 'Unequal Split',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Split Details
                    const Text(
                      'Split Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF008080),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDetailCard([
                      _buildDetailRow('Title', widget.split.title),
                      _buildDetailRow(
                        'Date',
                        DateFormat(
                          'EEEE, MMMM d, y',
                        ).format(widget.split.createdAt),
                      ),
                      _buildDetailRow(
                        'Time',
                        DateFormat('h:mm a').format(widget.split.createdAt),
                      ),
                      if (widget.split.description.isNotEmpty)
                        _buildDetailRow(
                          'Description',
                          widget.split.description,
                        ),
                      if (widget.split.notes.isNotEmpty)
                        _buildDetailRow('Notes', widget.split.notes),
                      _buildDetailRow(
                        'Status',
                        widget.split.isFullySettled
                            ? 'Fully Settled'
                            : 'Pending',
                      ),
                    ]),

                    const SizedBox(height: 24),

                    // Participants
                    const Text(
                      'Participants',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF008080),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: widget.split.participants.length,
                      itemBuilder: (context, index) {
                        final participantId = widget.split.participants[index];
                        final isPayer = participantId == widget.split.paidBy;
                        final isCurrentUser = participantId == currentUserId;

                        // Skip the current user if they are the payer
                        if (isPayer && !isCurrentUser) {
                          return _buildParticipantCard(
                            participantId,
                            isPayer,
                            isCurrentUser,
                            0.0,
                            0.0,
                          );
                        }

                        // Skip other participants if current user is not the payer
                        if (!isPayer &&
                            !isCurrentUser &&
                            currentUserId != widget.split.paidBy) {
                          return const SizedBox.shrink();
                        }

                        final amountOwed = widget.split.getAmountOwedBy(
                          participantId,
                        );

                        final remainingAmount = widget.split.getRemainingAmount(
                          participantId,
                        );

                        return _buildParticipantCard(
                          participantId,
                          isPayer,
                          isCurrentUser,
                          amountOwed,
                          remainingAmount,
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Settlement History
                    if (widget.split.settlements.isNotEmpty) ...[
                      const Text(
                        'Settlement History',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF008080),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: widget.split.settlements.length,
                        itemBuilder: (context, index) {
                          final settlement = widget.split.settlements[index];
                          return _buildSettlementCard(settlement);
                        },
                      ),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
    );
  }

  Widget _buildDetailCard(List<Widget> children) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantCard(
    String participantId,
    bool isPayer,
    bool isCurrentUser,
    double amountOwed,
    double remainingAmount,
  ) {
    final currentUserId = context.read<AuthService>().currentUser!.uid;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor:
                  isPayer
                      ? Colors.green.withOpacity(0.1)
                      : const Color(0xFFFF7F50).withOpacity(0.1),
              child: Icon(
                isPayer ? Icons.check_circle : Icons.person,
                color: isPayer ? Colors.green : const Color(0xFFFF7F50),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCurrentUser
                        ? 'You'
                        : 'Friend', // Replace with actual name in real app
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isPayer
                        ? 'Paid ${widget.split.formattedTotalAmount}'
                        : 'Owes ₹${amountOwed.toInt()}',
                    style: TextStyle(
                      color: isPayer ? Colors.green : Colors.grey[600],
                    ),
                  ),
                  if (!isPayer && remainingAmount > 0)
                    Text(
                      'Remaining: ₹${remainingAmount.toInt()}',
                      style: const TextStyle(
                        color: Color(0xFFFF7F50),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            if (!isPayer &&
                remainingAmount > 0 &&
                (isCurrentUser || currentUserId == widget.split.paidBy))
              ElevatedButton(
                onPressed:
                    () => _showSettleUpDialog(participantId, remainingAmount),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF008080),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Settle Up'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettlementCard(SettlementModel settlement) {
    final currentUserId = context.read<AuthService>().currentUser!.uid;
    final isFromCurrentUser = settlement.fromUserId == currentUserId;
    final isToCurrentUser = settlement.toUserId == currentUserId;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.green.withOpacity(0.1),
              child: const Icon(Icons.check_circle, color: Colors.green),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isFromCurrentUser
                        ? 'You paid'
                        : isToCurrentUser
                        ? 'You received'
                        : 'Settlement',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${settlement.amount.toInt()}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat(
                      'MMM d, y • h:mm a',
                    ).format(settlement.settledAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  if (settlement.notes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      settlement.notes,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
