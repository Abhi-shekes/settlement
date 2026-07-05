import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A lightweight Markdown renderer for the short responses Gemini returns
/// (headings, bullet/numbered lists, and **bold**/*italic*/`code` inline).
///
/// The app can't pull in a full markdown package offline, and the model's
/// output is simple, so this covers the cases that actually show up instead of
/// dumping raw `**` and `#` at the user.
class MarkdownText extends StatelessWidget {
  const MarkdownText(this.data, {super.key, this.baseStyle});

  final String data;
  final TextStyle? baseStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.colors;
    final base =
        baseStyle ??
        theme.textTheme.bodyMedium!.copyWith(height: 1.45, color: c.muted);
    final strong = theme.colorScheme.onSurface;

    final lines = data.replaceAll('\r\n', '\n').split('\n');
    final widgets = <Widget>[];

    for (var raw in lines) {
      final line = raw.trimRight();
      final trimmed = line.trimLeft();

      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      // Headings (#, ##, ###).
      final heading = RegExp(r'^(#{1,3})\s+(.*)$').firstMatch(trimmed);
      if (heading != null) {
        final level = heading.group(1)!.length;
        final text = heading.group(2)!;
        final style = (level == 1
                ? theme.textTheme.titleMedium
                : theme.textTheme.titleSmall)!
            .copyWith(color: strong, fontWeight: FontWeight.w700);
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 2),
            child: Text.rich(TextSpan(children: _inline(text, style, strong))),
          ),
        );
        continue;
      }

      // Bullets (-, *, •).
      final bullet = RegExp(r'^[-*•]\s+(.*)$').firstMatch(trimmed);
      if (bullet != null) {
        widgets.add(
          _listRow(
            marker: '•',
            markerColor: c.brand,
            child: Text.rich(
              TextSpan(children: _inline(bullet.group(1)!, base, strong)),
            ),
          ),
        );
        continue;
      }

      // Numbered list (1. …).
      final numbered = RegExp(r'^(\d+)\.\s+(.*)$').firstMatch(trimmed);
      if (numbered != null) {
        widgets.add(
          _listRow(
            marker: '${numbered.group(1)}.',
            markerColor: c.brand,
            child: Text.rich(
              TextSpan(children: _inline(numbered.group(2)!, base, strong)),
            ),
          ),
        );
        continue;
      }

      // Plain paragraph.
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text.rich(TextSpan(children: _inline(trimmed, base, strong))),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _listRow({
    required String marker,
    required Color markerColor,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Text(
              marker,
              style: TextStyle(color: markerColor, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  /// Parses inline **bold**, *italic*, and `code`, dropping the markers.
  List<InlineSpan> _inline(String text, TextStyle base, Color strong) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'(\*\*(.+?)\*\*|__(.+?)__|\*(.+?)\*|`(.+?)`)');
    var index = 0;

    for (final m in pattern.allMatches(text)) {
      if (m.start > index) {
        spans.add(TextSpan(text: text.substring(index, m.start), style: base));
      }
      if (m.group(2) != null || m.group(3) != null) {
        spans.add(
          TextSpan(
            text: m.group(2) ?? m.group(3),
            style: base.copyWith(fontWeight: FontWeight.w700, color: strong),
          ),
        );
      } else if (m.group(4) != null) {
        spans.add(
          TextSpan(
            text: m.group(4),
            style: base.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      } else if (m.group(5) != null) {
        spans.add(
          TextSpan(
            text: m.group(5),
            style: base.copyWith(
              fontFeatures: const [],
              letterSpacing: 0,
              color: strong,
            ),
          ),
        );
      }
      index = m.end;
    }
    if (index < text.length) {
      spans.add(TextSpan(text: text.substring(index), style: base));
    }
    if (spans.isEmpty) spans.add(TextSpan(text: text, style: base));
    return spans;
  }
}
