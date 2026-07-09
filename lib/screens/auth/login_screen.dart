import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/feature_row.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: c.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),

              // Brand hero
              Column(
                children: [
                  Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [c.heroGradientStart, c.heroGradientEnd],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: AppShadows.glow(c.brand),
                        ),
                        padding: const EdgeInsets.all(18),
                        child: Image.asset(
                          'assets/images/handshake-color.png',
                          fit: BoxFit.contain,
                        ),
                      )
                      .animate()
                      .scale(
                        duration: 500.ms,
                        curve: Curves.easeOutBack,
                        begin: const Offset(0.8, 0.8),
                      )
                      .fadeIn(),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Settlement',
                    style: AppTypography.money(
                      fontSize: 34,
                      color: theme.colorScheme.onSurface,
                    ),
                  ).animate(delay: 150.ms).fadeIn().slideY(begin: 0.2, end: 0),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Track expenses, split bills, settle up',
                    style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
                    textAlign: TextAlign.center,
                  ).animate(delay: 250.ms).fadeIn(),
                ],
              ),

              const Spacer(flex: 2),

              // Feature list
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: c.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  border: Border.all(color: c.cardBorder),
                ),
                child: Column(
                  children: const [
                    FeatureRow(
                      icon: Icons.receipt_long_rounded,
                      title: 'Track personal expenses',
                      description:
                          'Categorize daily spending and stay on budget',
                    ),
                    SizedBox(height: AppSpacing.md),
                    FeatureRow(
                      icon: Icons.groups_rounded,
                      title: 'Split bills with friends',
                      description: 'Equal or custom splits with easy settle-up',
                    ),
                    SizedBox(height: AppSpacing.md),
                    FeatureRow(
                      icon: Icons.insights_rounded,
                      title: 'Understand your money',
                      description: 'Visual insights into where it goes',
                    ),
                  ],
                ),
              ).animate(delay: 350.ms).fadeIn().slideY(begin: 0.15, end: 0),

              const SizedBox(height: AppSpacing.xl),

              // Google sign-in
              Consumer<AuthService>(
                builder: (context, authService, child) {
                  return SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed:
                          authService.isLoading
                              ? null
                              : () async {
                                try {
                                  await authService.signInWithGoogle();
                                } catch (e) {
                                  // The most common cause in the field is a
                                  // flaky connection (Google/Firestore hosts
                                  // fail to resolve), so call that out; keep a
                                  // generic fallback for everything else.
                                  final msg = e.toString().toLowerCase();
                                  final isNetwork =
                                      msg.contains('network') ||
                                      msg.contains('unavailable') ||
                                      msg.contains('resolve host') ||
                                      msg.contains('timeout') ||
                                      msg.contains('unknownhost');
                                  if (context.mounted) {
                                    AppSnackbar.error(
                                      context,
                                      isNetwork
                                          ? 'Sign in failed — check your internet connection and try again.'
                                          : 'Sign in failed. Please try again.',
                                    );
                                  }
                                }
                              },
                      icon:
                          authService.isLoading
                              ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: c.onBrand,
                                ),
                              )
                              : Image.asset(
                                'assets/images/google_logo.png',
                                width: 20,
                                height: 20,
                              ),
                      label: Text(
                        authService.isLoading
                            ? 'Signing in…'
                            : 'Continue with Google',
                      ),
                    ),
                  );
                },
              ).animate(delay: 450.ms).fadeIn(),

              const SizedBox(height: AppSpacing.md),
              Text(
                'By continuing you agree to our Terms & Privacy Policy',
                style: theme.textTheme.labelSmall?.copyWith(color: c.faint),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
