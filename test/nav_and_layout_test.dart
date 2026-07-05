import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:settlement/theme/app_theme.dart';
import 'package:settlement/widgets/app_bottom_nav.dart';
import 'package:settlement/widgets/action_card.dart';

const _items = [
  AppNavItem(icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'Home'),
  AppNavItem(
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long,
    label: 'Expenses',
  ),
  AppNavItem(
    icon: Icons.groups_outlined,
    selectedIcon: Icons.groups,
    label: 'Groups',
  ),
];

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('AppBottomNav shows the selected label and reports taps', (
    tester,
  ) async {
    int tapped = -1;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          bottomNavigationBar: AppBottomNav(
            currentIndex: 0,
            onTap: (i) => tapped = i,
            items: _items,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Selected destination reveals its label; others are icon-only.
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Groups'), findsNothing);

    await tester.tap(find.byIcon(Icons.groups_outlined));
    await tester.pumpAndSettle();
    expect(tapped, 2);
  });

  testWidgets('AppBottomNav does not overflow on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          bottomNavigationBar: AppBottomNav(
            currentIndex: 1, // 'Expenses' — the longest label — selected
            onTap: (_) {},
            items: const [
              AppNavItem(
                icon: Icons.dashboard_outlined,
                selectedIcon: Icons.dashboard,
                label: 'Home',
              ),
              AppNavItem(
                icon: Icons.receipt_long_outlined,
                selectedIcon: Icons.receipt_long,
                label: 'Expenses',
              ),
              AppNavItem(
                icon: Icons.call_split_outlined,
                selectedIcon: Icons.call_split,
                label: 'Splits',
              ),
              AppNavItem(
                icon: Icons.groups_outlined,
                selectedIcon: Icons.groups,
                label: 'Groups',
              ),
              AppNavItem(
                icon: Icons.person_outline_rounded,
                selectedIcon: Icons.person,
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull); // no right-side RenderFlex overflow
    expect(find.text('Expenses'), findsOneWidget);
  });

  testWidgets('ActionCard fits a 116px quick-action cell without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 160,
              height: 116, // matches the dashboard grid mainAxisExtent
              child: ActionCard(
                title: 'Create group',
                subtitle: 'Track shared group expenses',
                icon: Icons.group_add_rounded,
                accent: const Color(0xFF0F766E),
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull); // no RenderFlex overflow
  });
}
