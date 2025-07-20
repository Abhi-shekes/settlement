import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:settlement/screens/Invitations/Invitations_screen.dart';
import 'package:settlement/screens/family/family_spllit_screen.dart';
import 'package:settlement/services/Invitation_service.dart';
import 'package:settlement/services/budget_service.dart';
import 'services/auth_service.dart';
import 'services/expense_service.dart';
import 'services/group_service.dart';
import 'services/family_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/family/add_family_member_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
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
        ChangeNotifierProvider(create: (_) => FamilyService()),
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
        routes: {
          '/add-family-member': (context) => const AddFamilyMemberScreen(),
          '/family-split': (context) => const FamilySplitScreen(),
          '/invitations': (context) => const InvitationsScreen(),
        },
      ),
    );
  }
}
