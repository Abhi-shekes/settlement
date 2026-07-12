import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/account_service.dart';
import '../../services/recurring_service.dart';
import '../../services/expense_service.dart';
import '../../services/category_service.dart';
import '../../services/group_service.dart';
import '../../services/budget_service.dart';
import '../../services/invitation_service.dart';
import '../../services/notification_service.dart';
import '../../services/notification_center_service.dart';
import '../../services/theme_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/section_header.dart';
import 'friends_screen.dart';
import '../accounts/accounts_screen.dart';
import '../recurring/recurring_screen.dart';
import 'notification_settings_screen.dart';

import '../ai/ai_assistant_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = await context.read<AuthService>().getCurrentUserModel();
      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Sign Out'),
            content: const Text('Are you sure you want to sign out?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final messenger = ScaffoldMessenger.of(context);
                  // Clear cached account data before signing out; the auth gate
                  // in main.dart handles navigation back to the login screen.
                  context.read<ExpenseService>().reset();
                  context.read<AccountService>().reset();
                  context.read<RecurringService>().reset();
                  context.read<CategoryService>().reset();
                  context.read<GroupService>().reset();
                  context.read<BudgetService>().reset();
                  context.read<InvitationService>().reset();
                  context.read<NotificationCenterService>().stop();
                  final authService = context.read<AuthService>();
                  final uid = authService.currentUser?.uid;
                  if (uid != null) {
                    await NotificationService.instance.unregisterDevice(uid);
                  }
                  authService.reset();
                  try {
                    await authService.signOut();
                  } catch (e) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Could not sign out. Please try again.'),
                      ),
                    );
                  }
                },
                style: TextButton.styleFrom(
                  foregroundColor: context.colors.negative,
                ),
                child: const Text('Sign Out'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.surface,
      appBar: AppBar(title: const Text('Profile')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _loadUserData,
                color: c.brand,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Header
                      _buildProfileHeader(),
                      const SizedBox(height: AppSpacing.xl),

                      const SectionHeader('Manage'),
                      const SizedBox(height: AppSpacing.sm),

                      // Menu Items
                      _buildMenuItem(
                        icon: Icons.auto_awesome,
                        title: 'AI Assistant',
                        subtitle: 'Natural-language entry & insights',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AiAssistantScreen(),
                            ),
                          );
                        },
                      ),

                      _buildMenuItem(
                        icon: Icons.account_balance_wallet,
                        title: 'Accounts',
                        subtitle: 'Cash, bank, cards & wallets',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AccountsScreen(),
                            ),
                          );
                        },
                      ),

                      _buildMenuItem(
                        icon: Icons.autorenew,
                        title: 'Recurring',
                        subtitle: 'Salary, rent, subscriptions & bills',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RecurringScreen(),
                            ),
                          );
                        },
                      ),

                      _buildMenuItem(
                        icon: Icons.people,
                        title: 'Friends',
                        subtitle: 'Manage your friends list',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const FriendsScreen(),
                            ),
                          );
                        },
                      ),

                      _buildMenuItem(
                        icon: Icons.notifications_active_outlined,
                        title: 'Notifications',
                        subtitle: 'Choose what you get notified about',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) =>
                                      const NotificationSettingsScreen(),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: AppSpacing.lg),
                      const SectionHeader('Appearance'),
                      const SizedBox(height: AppSpacing.sm),
                      _buildThemeSelector(),

                      // _buildMenuItem(
                      //   icon: Icons.security,
                      //   title: 'Privacy & Security',
                      //   subtitle: 'Manage your privacy settings',
                      //   onTap: () {
                      //     ScaffoldMessenger.of(context).showSnackBar(
                      //       const SnackBar(content: Text('Privacy settings feature coming soon!')),
                      //     );
                      //   },
                      // ),
                      // _buildMenuItem(
                      //   icon: Icons.security,
                      //   title: 'Privacy & Security',
                      //   subtitle: 'Manage your privacy settings',
                      //   onTap: () {
                      //     ScaffoldMessenger.of(context).showSnackBar(
                      //       const SnackBar(content: Text('Privacy settings feature coming soon!')),
                      //     );
                      //   },
                      // ),
                      // _buildMenuItem(
                      //   icon: Icons.help,
                      //   title: 'Help & Support',
                      //   subtitle: 'Get help and contact support',
                      //   onTap: () {
                      //     ScaffoldMessenger.of(context).showSnackBar(
                      //       const SnackBar(content: Text('Help & Support feature coming soon!')),
                      //     );
                      //   },
                      // ),
                      // _buildMenuItem(
                      //   icon: Icons.info,
                      //   title: 'About',
                      //   subtitle: 'App version and information',
                      //   onTap: () {
                      //     showAboutDialog(
                      //       context: context,
                      //       applicationName: 'Settlement',
                      //       applicationVersion: '1.0.0',
                      //       applicationIcon: Container(
                      //         width: 60,
                      //         height: 60,
                      //         decoration: BoxDecoration(
                      //           color: const Color(0xFF008080),
                      //           borderRadius: BorderRadius.circular(15),
                      //         ),
                      //         child: const Icon(
                      //           Icons.account_balance_wallet,
                      //           size: 30,
                      //           color: Colors.white,
                      //         ),
                      //       ),
                      //       children: [
                      //         const Text('Track expenses, split bills, and settle up with friends easily.'),
                      //       ],
                      //     );
                      //   },
                      // ),
                      const SizedBox(height: AppSpacing.xl),

                      // Sign Out Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _signOut,
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text('Sign out'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: c.negative,
                            side: BorderSide(
                              color: c.negative.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildProfileHeader() {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.heroGradientStart, c.heroGradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: AppShadows.glow(c.brand),
      ),
      child: Column(
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: c.onBrand.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: c.onBrand.withValues(alpha: 0.3)),
            ),
            child:
                _currentUser?.photoURL != null
                    ? ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.network(
                        _currentUser!.photoURL!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.person,
                            size: 46,
                            color: c.onBrand.withValues(alpha: 0.85),
                          );
                        },
                      ),
                    )
                    : Icon(
                      Icons.person,
                      size: 46,
                      color: c.onBrand.withValues(alpha: 0.85),
                    ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            _currentUser?.displayName ?? 'User',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: c.onBrand),
          ),
          const SizedBox(height: 2),
          Text(
            _currentUser?.email ?? '',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: c.onBrand.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: _copyFriendCode,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: c.onBrand.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.qr_code_rounded, color: c.onBrand, size: 18),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Friend code · ${_currentUser?.friendCode ?? '—'}',
                    style: TextStyle(
                      color: c.onBrand,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(Icons.copy_rounded, color: c.onBrand, size: 15),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyFriendCode() async {
    final friendCode = _currentUser?.friendCode ?? '';
    if (friendCode.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: friendCode));
      if (mounted) AppSnackbar.success(context, 'Friend code copied');
    } else if (mounted) {
      AppSnackbar.info(context, 'No friend code yet');
    }
  }

  Widget _buildThemeSelector() {
    final c = context.colors;
    final theme = context.watch<ThemeService>();
    final options = [
      (ThemeMode.system, 'System', Icons.brightness_auto_rounded),
      (ThemeMode.light, 'Light', Icons.light_mode_rounded),
      (ThemeMode.dark, 'Dark', Icons.dark_mode_rounded),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: AppRadii.card,
        border: Border.all(color: c.cardBorder),
      ),
      child: Row(
        children: [
          for (final o in options)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadii.md),
                onTap: () => context.read<ThemeService>().setMode(o.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color:
                        theme.mode == o.$1 ? c.brandSoft : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        o.$3,
                        size: 22,
                        color: theme.mode == o.$1 ? c.brand : c.muted,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        o.$2,
                        style: Theme.of(
                          context,
                        ).textTheme.labelMedium?.copyWith(
                          color: theme.mode == o.$1 ? c.brand : c.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: AppRadii.card,
        border: Border.all(color: c.cardBorder),
      ),
      child: ListTile(
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.card),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: c.brandSoft,
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: Icon(icon, color: c.brand, size: 22),
        ),
        title: Text(title, style: Theme.of(context).textTheme.titleSmall),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.chevron_right_rounded, color: c.faint),
        onTap: onTap,
      ),
    );
  }
}
