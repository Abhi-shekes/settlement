import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:settlement/theme/app_theme.dart';
import 'package:settlement/theme/app_colors.dart';
import 'package:settlement/utils/money.dart';
import 'package:settlement/widgets/money_text.dart';
import 'package:settlement/widgets/stat_card.dart';
import 'package:settlement/widgets/app_chip.dart';
import 'package:settlement/widgets/empty_state.dart';
import 'package:settlement/widgets/section_header.dart';

Widget _host(ThemeData theme, Widget child) {
  return MaterialApp(
    theme: theme,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

Widget _sampleScreen() {
  return Builder(
    builder: (context) {
      final c = context.colors; // exercises the ThemeExtension lookup
      return Column(
        children: [
          const SectionHeader('Overview'),
          const MoneyText(1250, colored: true),
          const MoneyText(-980, colored: true),
          StatCard(
            label: 'Spent',
            icon: Icons.receipt_long_rounded,
            accent: c.brand,
            amount: 4200,
          ),
          const AppChip(label: 'Food'),
          const EmptyState(
            icon: Icons.inbox_rounded,
            title: 'Nothing here',
            message: 'Add something to get started.',
          ),
        ],
      );
    },
  );
}

void main() {
  // Keep font resolution offline in tests; falls back to bundled defaults.
  GoogleFonts.config.allowRuntimeFetching = false;

  group('formatCurrency', () {
    test('groups rupees the Indian way', () {
      expect(formatCurrency(124500), '₹1,24,500');
    });
    test('prefixes a minus for negatives', () {
      expect(formatCurrency(-250), '-₹250');
    });
    test('compact renders lakhs and crores', () {
      expect(formatCurrency(150000, compact: true), '₹1.5L');
      expect(formatCurrency(20000000, compact: true), '₹2Cr');
    });
    test('signed prefixes a plus for positives', () {
      expect(formatCurrency(500, signed: true), '+₹500');
    });
  });

  testWidgets('design-system components render in light theme', (tester) async {
    await tester.pumpWidget(_host(AppTheme.light, _sampleScreen()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('₹1,250'), findsOneWidget);
    expect(find.text('-₹980'), findsOneWidget);
  });

  testWidgets('design-system components render in dark theme', (tester) async {
    await tester.pumpWidget(_host(AppTheme.dark, _sampleScreen()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Overview'), findsOneWidget);
  });
}
