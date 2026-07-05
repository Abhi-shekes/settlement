import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// A single destination for [AppBottomNav].
class AppNavItem {
  const AppNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// A premium bottom navigation bar: the selected destination animates into a
/// brand-tinted pill that expands to reveal its label, while the others stay
/// as quiet icons. Docked (not floating) so it never overlaps screen content
/// or FABs, with a soft top edge and haptic feedback on selection.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<AppNavItem> items;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        border: Border(top: BorderSide(color: c.cardBorder)),
        boxShadow: [
          BoxShadow(
            color: c.shadow,
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs + 2,
          ),
          // The selected pill expands to show its label, so the natural row
          // width varies. FittedBox.scaleDown keeps the cluster within the
          // screen on narrow devices / large text scales instead of overflowing.
          child: SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < items.length; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.xxs),
                    _NavPill(
                      item: items[i],
                      selected: i == currentIndex,
                      onTap: () {
                        if (i != currentIndex) {
                          HapticFeedback.selectionClick();
                          onTap(i);
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavPill extends StatelessWidget {
  const _NavPill({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AppNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.colors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      splashColor: c.brand.withValues(alpha: 0.12),
      highlightColor: Colors.transparent,
      child: AnimatedContainer(
        duration: AppDurations.medium,
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: selected ? 16 : 14,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: selected ? c.brandSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              duration: AppDurations.medium,
              curve: Curves.easeOutBack,
              scale: selected ? 1.08 : 1.0,
              child: Icon(
                selected ? item.selectedIcon : item.icon,
                color: selected ? c.brand : c.faint,
                size: 24,
              ),
            ),
            // Label reveals only for the selected pill; AnimatedSize gives it a
            // smooth expand/collapse as selection moves.
            ClipRect(
              child: AnimatedSize(
                duration: AppDurations.medium,
                curve: Curves.easeOutCubic,
                child:
                    selected
                        ? Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            item.label,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.clip,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: c.brand,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                        : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
