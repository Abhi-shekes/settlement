import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:settlement/screens/invitations/invitations_screen.dart';
import 'package:settlement/services/invitation_service.dart';
import 'package:settlement/services/budget_service.dart';
import 'services/auth_service.dart';
import 'services/expense_service.dart';
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
        ChangeNotifierProvider(create: (_) => ExpenseService()),
        ChangeNotifierProvider(create: (_) => GroupService()),
        ChangeNotifierProvider(create: (_) => BudgetService()),
        ChangeNotifierProvider(create: (_) => InvitationService()),
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
