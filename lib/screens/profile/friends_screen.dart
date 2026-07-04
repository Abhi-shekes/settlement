import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../models/friend_request_model.dart';
import '../../services/auth_service.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<UserModel> _friends = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadFriends();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    final auth = context.read<AuthService>();
    await Future.wait([
      auth.loadIncomingFriendRequests(),
      auth.loadOutgoingFriendRequests(),
    ]);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final friends = await context.read<AuthService>().getFriends();
      setState(() {
        _friends = friends;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading friends: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<UserModel> _getFilteredFriends() {
    if (_searchQuery.isEmpty) return _friends;

    return _friends.where((friend) {
      return friend.displayName.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          friend.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          friend.friendCode.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredFriends = _getFilteredFriends();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        backgroundColor: const Color(0xFF008080),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            const Tab(text: 'Friends'),
            Consumer<AuthService>(
              builder: (context, auth, _) {
                final n = auth.incomingFriendRequests.length;
                return Tab(text: n > 0 ? 'Requests ($n)' : 'Requests');
              },
            ),
            const Tab(text: 'Add Friend'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Friends List Tab
          Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search friends...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon:
                        _searchQuery.isNotEmpty
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

              // Friends List
              Expanded(
                child:
                    _isLoading
                        ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF008080),
                          ),
                        )
                        : filteredFriends.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                          onRefresh: _loadFriends,
                          color: const Color(0xFF008080),
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: filteredFriends.length,
                            itemBuilder: (context, index) {
                              final friend = filteredFriends[index];
                              return _buildFriendCard(friend);
                            },
                          ),
                        ),
              ),
            ],
          ),

          // Requests Tab
          _buildRequestsTab(),

          // Add Friend Tab
          const AddFriendTab(),
        ],
      ),
      //   floatingActionButton:
      //       _tabController.index == 0
      //           ? FloatingActionButton(
      //             onPressed: () {
      //               _tabController.animateTo(1);
      //             },
      //             backgroundColor: const Color(0xFF008080),
      //             foregroundColor: Colors.white,
      //             child: const Icon(Icons.person_add),
      //           )
      //           : null,
    );
  }

  Widget _buildRequestsTab() {
    return Consumer<AuthService>(
      builder: (context, auth, _) {
        final incoming = auth.incomingFriendRequests;
        final outgoing = auth.outgoingFriendRequests;

        if (incoming.isEmpty && outgoing.isEmpty) {
          return RefreshIndicator(
            onRefresh: _loadRequests,
            color: const Color(0xFF008080),
            child: ListView(
              children: [
                const SizedBox(height: 120),
                Icon(
                  Icons.mark_email_read_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'No friend requests',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadRequests,
          color: const Color(0xFF008080),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (incoming.isNotEmpty) ...[
                const Text(
                  'Received',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF008080),
                  ),
                ),
                const SizedBox(height: 8),
                ...incoming.map((r) => _incomingRequestCard(r)),
                const SizedBox(height: 16),
              ],
              if (outgoing.isNotEmpty) ...[
                const Text(
                  'Sent',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF008080),
                  ),
                ),
                const SizedBox(height: 8),
                ...outgoing.map((r) => _outgoingRequestCard(r)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _incomingRequestCard(FriendRequestModel r) {
    final auth = context.read<AuthService>();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF008080).withValues(alpha: 0.1),
          backgroundImage:
              (r.fromPhotoURL != null && r.fromPhotoURL!.isNotEmpty)
                  ? NetworkImage(r.fromPhotoURL!)
                  : null,
          child:
              (r.fromPhotoURL == null || r.fromPhotoURL!.isEmpty)
                  ? Text(
                    r.fromName.isNotEmpty ? r.fromName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Color(0xFF008080),
                      fontWeight: FontWeight.bold,
                    ),
                  )
                  : null,
        ),
        title: Text(r.fromName),
        subtitle: Text(r.fromEmail),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check_circle, color: Colors.green),
              tooltip: 'Accept',
              onPressed: () async {
                try {
                  await auth.acceptFriendRequest(r);
                  await _loadFriends();
                } catch (_) {}
              },
            ),
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.red),
              tooltip: 'Decline',
              onPressed: () => auth.declineFriendRequest(r),
            ),
          ],
        ),
      ),
    );
  }

  Widget _outgoingRequestCard(FriendRequestModel r) {
    final auth = context.read<AuthService>();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.hourglass_top)),
        title: Text(r.toName.isNotEmpty ? r.toName : r.toEmail),
        subtitle: const Text('Pending'),
        trailing: TextButton(
          onPressed: () => auth.cancelFriendRequest(r),
          child: const Text('Cancel', style: TextStyle(color: Colors.red)),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? 'No friends found' : 'No friends yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try changing your search query'
                : 'Add friends to start splitting expenses',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (_searchQuery.isEmpty)
            ElevatedButton.icon(
              onPressed: () => _tabController.animateTo(1),
              icon: const Icon(Icons.person_add),
              label: const Text('Add Friend'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF008080),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFriendCard(UserModel friend) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFF008080).withValues(alpha: 0.1),
              backgroundImage:
                  friend.photoURL != null
                      ? NetworkImage(friend.photoURL!)
                      : null,
              child:
                  friend.photoURL == null
                      ? Text(
                        friend.displayName.isNotEmpty
                            ? friend.displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Color(0xFF008080),
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      )
                      : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    friend.email,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Friend Code: ${friend.friendCode}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ),
            PopupMenuButton(
              itemBuilder:
                  (context) => [
                    const PopupMenuItem(
                      value: 'remove',
                      child: Text('Remove Friend'),
                    ),
                  ],
              onSelected: (value) {
                switch (value) {
                  case 'remove':
                    _showRemoveFriendDialog(friend);
                    break;
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRemoveFriendDialog(UserModel friend) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Remove Friend'),
            content: Text(
              'Are you sure you want to remove ${friend.displayName} from your friends list?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Remove friend feature coming soon!'),
                    ),
                  );
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Remove'),
              ),
            ],
          ),
    );
  }
}

class AddFriendTab extends StatefulWidget {
  const AddFriendTab({super.key});

  @override
  State<AddFriendTab> createState() => _AddFriendTabState();
}

class _AddFriendTabState extends State<AddFriendTab> {
  final _friendCodeController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _friendCodeController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _addFriendByCode() async {
    final friendCode = _friendCodeController.text.trim().toUpperCase();
    if (friendCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a friend code'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = context.read<AuthService>();
      final user = await authService.getUserByFriendCode(friendCode);

      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Friend not found with this code'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        await authService.sendFriendRequest(user);
        if (mounted) {
          _friendCodeController.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Friend request sent to ${user.displayName}.'),
              backgroundColor: const Color(0xFF008080),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding friend: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addFriendByEmail() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an email address'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = context.read<AuthService>();
      final user = await authService.getUserByEmail(email);

      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Friend not found with this email'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        await authService.sendFriendRequest(user);
        if (mounted) {
          _emailController.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Friend request sent to ${user.displayName}.'),
              backgroundColor: const Color(0xFF008080),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding friend: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add by Friend Code
          const Text(
            'Add by Friend Code',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF008080),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your friend\'s unique friend code to add them',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _friendCodeController,
                  decoration: const InputDecoration(
                    hintText: 'Enter friend code',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.qr_code),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isLoading ? null : _addFriendByCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF008080),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child:
                    _isLoading
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Text('Add'),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Divider
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey[300])),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'OR',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(child: Divider(color: Colors.grey[300])),
            ],
          ),

          const SizedBox(height: 32),

          // Add by Email
          const Text(
            'Add by Email',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF008080),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your friend\'s email address to send them a friend request',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    hintText: 'Enter email address',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isLoading ? null : _addFriendByEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF008080),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child:
                    _isLoading
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Text('Add'),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Tips
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF008080).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.lightbulb, color: Color(0xFF008080), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Tips',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF008080),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• Share your friend code from the profile screen\n'
                  '• Friend codes are unique 8-character identifiers\n'
                  '• Both users must add each other to become friends',
                  style: TextStyle(color: Colors.grey[700], fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AddFriendBottomSheet extends StatelessWidget {
  const AddFriendBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(padding: EdgeInsets.all(16), child: AddFriendTab());
  }
}
