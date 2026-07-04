import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:settlement/screens/invitations/invitations_screen.dart';
import 'package:settlement/services/invitation_service.dart';
import 'package:settlement/services/budget_service.dart';
import 'services/auth_service.dart';
import 'services/account_service.dart';
import 'services/expense_service.dart';
import 'services/recurring_service.dart';
import 'services/ai_service.dart';
import 'services/group_service.dart';
import 'services/notification_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Push notifications (FCM). The background handler must be registered before
  // runApp; token registration happens once the user is signed in.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await NotificationService.instance.init();
  NotificationService.instance.currentUidGetter =
      () => FirebaseAuth.instance.currentUser?.uid;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => AccountService()),
        // ExpenseService depends on AccountService to keep account balances in
        // sync as expenses change, so it's created via a proxy provider.
        ChangeNotifierProxyProvider<AccountService, ExpenseService>(
          create: (_) => ExpenseService(),
          update: (_, accountService, expenseService) {
            (expenseService ??= ExpenseService()).attachAccountService(
              accountService,
            );
            return expenseService;
          },
        ),
        // RecurringService generates expenses through ExpenseService, so it
        // depends on it.
        ChangeNotifierProxyProvider<ExpenseService, RecurringService>(
          create: (_) => RecurringService(),
          update: (_, expenseService, recurringService) {
            (recurringService ??= RecurringService()).attachExpenseService(
              expenseService,
            );
            return recurringService;
          },
        ),
        ChangeNotifierProvider(create: (_) => GroupService()),
        ChangeNotifierProvider(create: (_) => BudgetService()),
        ChangeNotifierProvider(create: (_) => InvitationService()),
        ChangeNotifierProvider(create: (_) => AiService()),
      ],
      child: MaterialApp(
        title: 'Settlement App',
        theme: ThemeData(
          primarySwatch: Colors.teal,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: Consumer<AuthService>(
          builder: (context, authService, _) {
            return authService.currentUser != null
                ? const HomeScreen()
                : const LoginScreen();
          },
        ),
        routes: {'/invitations': (context) => const InvitationsScreen()},
      ),
    );
  }
}
