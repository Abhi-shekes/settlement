import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:settlement/theme/app_theme.dart';
import 'package:settlement/widgets/markdown_text.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('MarkdownText strips markers and renders clean text', (
    tester,
  ) async {
    const sample = '## Summary\n'
        'You spent **a lot** on *food*.\n'
        '- First point\n'
        '- Second point\n'
        '1. Do this\n';

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: MarkdownText(sample)),
      ),
    );
    await tester.pumpAndSettle();

    // Heading and inline markers are gone from the rendered output.
    expect(find.textContaining('##'), findsNothing);
    expect(find.textContaining('**'), findsNothing);
    expect(find.text('Summary'), findsOneWidget);
    // Bullets get a "•" marker; numbered item keeps "1.".
    expect(find.text('•'), findsNWidgets(2));
    expect(find.text('1.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
