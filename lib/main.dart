import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/expense_service.dart';
import 'services/group_service.dart';
import 'services/budget_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
      ],
      child: MaterialApp(
        title: 'Overview Settlement',
        theme: ThemeData(
          primaryColor: const Color(0xFF008080),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF008080),
            primary: const Color(0xFF008080),
            secondary: const Color(0xFFFF7F50),
          ),
          useMaterial3: true,
        ),
        home: Consumer<AuthService>(
          builder: (context, authService, _) {
            return authService.currentUser != null
                ? const HomeScreen()
                : const LoginScreen();
          },
        ),
        routes: {
          '/budgets': (context) => const BudgetScreen(),
        },
      ),
    );
  }
}
