import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/split_model.dart';
import '../../services/group_service.dart';
import '../../services/auth_service.dart';
import 'add_split_screen.dart';
import 'split_detail_screen.dart';

class SplitsScreen extends StatefulWidget {
  const SplitsScreen({super.key});

  @override
  State<SplitsScreen> createState() => _SplitsScreenState();
}

class _SplitsScreenState extends State<SplitsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _refreshSplits();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshSplits() async {
    await context.read<GroupService>().loadUserSplits();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Splits'),
        backgroundColor: const Color(0xFF008080),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'You Owe'),
            Tab(text: 'Owed to You'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search splits...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _searchController.clear();
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF008080)),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSplitsList(SplitListType.all),
                _buildSplitsList(SplitListType.youOwe),
                _buildSplitsList(SplitListType.owedToYou),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddSplitScreen()),
          );
          // Refresh splits when returning from add screen
          _refreshSplits();
        },
        backgroundColor: const Color(0xFF008080),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSplitsList(SplitListType type) {
    return Consumer2<GroupService, AuthService>(
      builder: (context, groupService, authService, child) {
        if (groupService.isLoading) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF008080)));
        }
        
        final currentUserId = authService.currentUser?.uid ?? '';
        List<SplitModel> splits;
        
        switch (type) {
          case SplitListType.all:
            splits = groupService.splits;
            break;
          case SplitListType.youOwe:
            splits = groupService.getUserOwedSplits(currentUserId);
            break;
          case SplitListType.owedToYou:
            splits = groupService.getUserOwingSplits(currentUserId);
            break;
        }
        
        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          splits = splits.where((split) {
            return split.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                   split.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                   split.tags.any((tag) => tag.toLowerCase().contains(_searchQuery.toLowerCase()));
          }).toList();
        }
        
        if (splits.isEmpty) {
          return _buildEmptyState(type);
        }
        
        return RefreshIndicator(
          onRefresh: _refreshSplits,
          color: const Color(0xFF008080),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: splits.length,
            itemBuilder: (context, index) {
              final split = splits[index];
              return _buildSplitCard(split, currentUserId);
            },
          ),
        );
      },
    );
  }

  Widget _buildSplitCard(SplitModel split, String currentUserId) {
    final isGroupSplit = split.groupId != null;
    final isPayer = split.paidBy == currentUserId;
    
    // Calculate amount for current user
    double amount = 0;
    String amountText = '';
    Color amountColor = Colors.black;
    
    if (isPayer) {
      // You paid, others owe you
      amount = split.participants
          .where((p) => p != currentUserId)
          .fold(0.0, (sum, p) => sum + split.getRemainingAmount(p));
      
      if (amount > 0) {
        amountText = '+₹${amount.toStringAsFixed(2)}';
        amountColor = Colors.green;
      } else {
        amountText = '₹${amount.toStringAsFixed(2)}';
        amountColor = Colors.grey;
      }
    } else {
      // Someone else paid, you owe
      amount = split.getRemainingAmount(currentUserId);
      
      if (amount > 0) {
        amountText = '-₹${amount.toStringAsFixed(2)}';
        amountColor = const Color(0xFFFF7F50);
      } else {
        amountText = '₹${amount.toStringAsFixed(2)}';
        amountColor = Colors.grey;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SplitDetailScreen(split: split),
            ),
          ).then((_) => _refreshSplits());
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Split Type Icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isGroupSplit 
                          ? Colors.purple.withOpacity(0.1) 
                          : const Color(0xFFFF7F50).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isGroupSplit ? Icons.groups : Icons.person,
                      color: isGroupSplit ? Colors.purple : const Color(0xFFFF7F50),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Title and Description
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          split.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          split.description.isEmpty 
                              ? (isPayer ? 'You paid' : 'You owe ${_getPayerName(split, context)}')
                              : split.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Total: ${split.formattedTotalAmount}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Amount
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        amountText,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: amountColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM d, y').format(split.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: split.isFullySettled 
                              ? Colors.green.withOpacity(0.1) 
                              : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          split.isFullySettled ? 'Settled' : 'Pending',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: split.isFullySettled ? Colors.green : Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              // Tags
              if (split.tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: split.tags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isGroupSplit 
                              ? Colors.purple.withOpacity(0.1) 
                              : const Color(0xFFFF7F50).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 12,
                            color: isGroupSplit ? Colors.purple : const Color(0xFFFF7F50),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getPayerName(SplitModel split, BuildContext context) {
    // In a real app, you would fetch the user's name from the database
    // For now, we'll just return a placeholder
    return 'Someone';
  }

  Widget _buildEmptyState(SplitListType type) {
    String message;
    String subMessage;
    IconData icon;
    
    switch (type) {
      case SplitListType.all:
        message = 'No splits found';
        subMessage = _searchQuery.isNotEmpty 
            ? 'Try changing your search query' 
            : 'Start by splitting a bill with friends';
        icon = Icons.call_split;
        break;
      case SplitListType.youOwe:
        message = 'You don\'t owe anyone';
        subMessage = _searchQuery.isNotEmpty 
            ? 'Try changing your search query' 
            : 'All your debts are settled';
        icon = Icons.check_circle;
        break;
      case SplitListType.owedToYou:
        message = 'No one owes you';
        subMessage = _searchQuery.isNotEmpty 
            ? 'Try changing your search query' 
            : 'All your friends have settled up';
        icon = Icons.account_balance_wallet;
        break;
    }
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subMessage,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          if (_searchQuery.isEmpty && type == SplitListType.all)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddSplitScreen()),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Split a Bill'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF008080),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum SplitListType {
  all,
  youOwe,
  owedToYou,
}
