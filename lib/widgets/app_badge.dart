import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A notification count badge overlaid on the top-right of [child] (e.g. a
/// bell icon). Hidden entirely when [count] is zero. Replaces the bespoke
/// `RequestBadge` in the dashboard.
class CountBadge extends StatelessWidget {
  const CountBadge({super.key, required this.count, required this.child});

  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (count <= 0) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -6,
          top: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            decoration: BoxDecoration(
              color: c.negative,
              shape: count > 9 ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: count > 9 ? BorderRadius.circular(9) : null,
              border: Border.all(color: c.surfaceElevated, width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(
              count > 99 ? '99+' : '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
