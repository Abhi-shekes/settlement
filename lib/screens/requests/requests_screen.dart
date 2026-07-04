import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/friend_request_model.dart';
import '../../models/group_invitation_model.dart';
import '../../models/split_model.dart';
import '../../services/auth_service.dart';
import '../../services/group_service.dart';
import '../../services/invitation_service.dart';

const _teal = Color(0xFF008080);

/// One place to review and respond to every pending two-party handshake:
/// friend requests, group invitations, split-share approvals and settlement
/// confirmations.
class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  bool _isLoading = true;
  final Map<String, String> _names = {}; // userId -> display name

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final auth = context.read<AuthService>();
    final groups = context.read<GroupService>();
    final invites = context.read<InvitationService>();

    await Future.wait([
      auth.loadIncomingFriendRequests(),
      invites.loadReceivedInvitations(),
      groups.loadUserSplits(),
    ]);

    // Resolve the display names referenced by split/settlement cards.
    final me = auth.currentUser?.uid;
    final ids = <String>{};
    for (final s in groups.splitsAwaitingApprovalFrom(me ?? '')) {
      ids.add(s.paidBy);
    }
    for (final p in groups.pendingSettlementsToConfirm(me ?? '')) {
      ids.add(p.settlement.recordedBy ?? p.settlement.fromUserId);
    }
    for (final id in ids) {
      final u = await auth.getUserById(id);
      if (u != null) _names[id] = u.displayName;
    }

    if (mounted) setState(() => _isLoading = false);
  }

  String _nameFor(String userId) => _names[userId] ?? 'Someone';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Requests'),
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: _teal))
              : Consumer3<AuthService, GroupService, InvitationService>(
                builder: (context, auth, groups, invites, _) {
                  final me = auth.currentUser?.uid ?? '';
                  final friendReqs = auth.incomingFriendRequests;
                  final groupInvites = invites.receivedInvitations;
                  final splitApprovals = groups.splitsAwaitingApprovalFrom(me);
                  final settlementConfirms = groups.pendingSettlementsToConfirm(
                    me,
                  );

                  final total =
                      friendReqs.length +
                      groupInvites.length +
                      splitApprovals.length +
                      settlementConfirms.length;

                  if (total == 0) {
                    return _emptyState();
                  }

                  return RefreshIndicator(
                    onRefresh: _load,
                    color: _teal,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (friendReqs.isNotEmpty)
                          _section('Friend Requests', Icons.person_add, [
                            for (final r in friendReqs) _friendCard(r),
                          ]),
                        if (splitApprovals.isNotEmpty)
                          _section('Split Approvals', Icons.call_split, [
                            for (final s in splitApprovals) _splitCard(s, me),
                          ]),
                        if (settlementConfirms.isNotEmpty)
                          _section('Confirm Payments', Icons.handshake, [
                            for (final p in settlementConfirms)
                              _settlementCard(p),
                          ]),
                        if (groupInvites.isNotEmpty)
                          _section('Group Invitations', Icons.groups, [
                            for (final inv in groupInvites) _inviteCard(inv),
                          ]),
                      ],
                    ),
                  );
                },
              ),
    );
  }

  Widget _emptyState() {
    return LayoutBuilder(
      builder:
          (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 120),
                  Icon(
                    Icons.check_circle_outline,
                    size: 72,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'You\'re all caught up',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No pending requests to confirm',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _section(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: _teal, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _teal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _card({
    required Widget avatar,
    required String title,
    required String subtitle,
    required VoidCallback onAccept,
    required VoidCallback onDecline,
    String acceptLabel = 'Accept',
    String declineLabel = 'Decline',
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                avatar,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDecline,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: Text(declineLabel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _teal,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(acceptLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleAvatar(String label, {String? photoUrl, Color? color}) {
    final c = color ?? _teal;
    return CircleAvatar(
      radius: 20,
      backgroundColor: c.withValues(alpha: 0.12),
      backgroundImage:
          (photoUrl != null && photoUrl.isNotEmpty)
              ? NetworkImage(photoUrl)
              : null,
      child:
          (photoUrl == null || photoUrl.isEmpty)
              ? Text(
                label.isNotEmpty ? label[0].toUpperCase() : '?',
                style: TextStyle(color: c, fontWeight: FontWeight.bold),
              )
              : null,
    );
  }

  void _run(Future<void> Function() action, String success) async {
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success), backgroundColor: _teal),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _friendCard(FriendRequestModel r) {
    final auth = context.read<AuthService>();
    return _card(
      avatar: _circleAvatar(r.fromName, photoUrl: r.fromPhotoURL),
      title: r.fromName,
      subtitle: 'wants to be your friend',
      onAccept:
          () => _run(
            () => auth.acceptFriendRequest(r),
            '${r.fromName} is now your friend',
          ),
      onDecline: () => _run(() => auth.declineFriendRequest(r), 'Declined'),
    );
  }

  Widget _splitCard(SplitModel s, String me) {
    final groups = context.read<GroupService>();
    final share = s.getAmountOwedBy(me);
    return _card(
      avatar: _circleAvatar(_nameFor(s.paidBy), color: const Color(0xFFFF7F50)),
      title: s.title,
      subtitle:
          '${_nameFor(s.paidBy)} split this — your share is ₹${share.toInt()}',
      acceptLabel: 'Approve',
      onAccept:
          () => _run(() => groups.acceptSplitShare(s.id, me), 'Share approved'),
      onDecline:
          () => _run(() => groups.declineSplitShare(s.id, me), 'Declined'),
    );
  }

  Widget _settlementCard(PendingSettlement p) {
    final groups = context.read<GroupService>();
    final recorder = p.settlement.recordedBy ?? p.settlement.fromUserId;
    return _card(
      avatar: _circleAvatar(_nameFor(recorder), color: Colors.green),
      title: '${_nameFor(recorder)} recorded a payment',
      subtitle:
          '₹${p.settlement.amount.toInt()} for "${p.split.title}" — confirm it happened?',
      acceptLabel: 'Confirm',
      onAccept:
          () => _run(
            () => groups.confirmSettlement(p.split.id, p.settlement.id),
            'Payment confirmed',
          ),
      onDecline:
          () => _run(
            () => groups.rejectSettlement(p.split.id, p.settlement.id),
            'Payment rejected',
          ),
    );
  }

  Widget _inviteCard(GroupInvitationModel inv) {
    final invites = context.read<InvitationService>();
    return _card(
      avatar: _circleAvatar(inv.invitedByName, color: Colors.purple),
      title: inv.groupName,
      subtitle: '${inv.invitedByName} invited you to this group',
      acceptLabel: 'Join',
      onAccept:
          () => _run(
            () => invites.acceptInvitation(inv.id),
            'Joined ${inv.groupName}',
          ),
      onDecline:
          () => _run(() => invites.declineInvitation(inv.id), 'Declined'),
    );
  }
}

/// Total number of pending items, for badges. Callers should have already
/// loaded the underlying lists.
int pendingRequestCount(
  AuthService auth,
  GroupService groups,
  InvitationService invites,
) {
  final me = auth.currentUser?.uid ?? '';
  return auth.incomingFriendRequests.length +
      invites.receivedInvitations.length +
      groups.splitsAwaitingApprovalFrom(me).length +
      groups.pendingSettlementsToConfirm(me).length;
}

/// A small notification-style badge wrapper.
class RequestBadge extends StatelessWidget {
  final Widget child;
  final int count;
  const RequestBadge({super.key, required this.child, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -4,
          top: -4,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Color(0xFFFF7F50),
              shape: BoxShape.circle,
            ),
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            child: Text(
              count > 9 ? '9+' : '$count',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
