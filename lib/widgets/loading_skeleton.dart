import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// A single shimmering placeholder block. Compose these into skeleton layouts
/// that mirror the real content, so loading feels like the screen is filling
/// in rather than a spinner blocking it.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 8,
    this.shape = BoxShape.rectangle,
  });

  final double? width;
  final double height;
  final double radius;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
          width: shape == BoxShape.circle ? height : width,
          height: height,
          decoration: BoxDecoration(
            color: c.surfaceSunken,
            shape: shape,
            borderRadius:
                shape == BoxShape.circle ? null : BorderRadius.circular(radius),
          ),
        )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1100.ms, color: c.cardBorder.withValues(alpha: 0.6));
  }
}

/// A ready-made list of skeleton cards for list/loading states.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 5, this.padding});

  final int count;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView.separated(
      padding: padding ?? AppSpacing.screen,
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder:
          (_, __) => Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: c.surfaceElevated,
              borderRadius: AppRadii.card,
              border: Border.all(color: c.cardBorder),
            ),
            child: Row(
              children: [
                const SkeletonBox(height: 44, shape: BoxShape.circle),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SkeletonBox(width: 140, height: 13),
                      SizedBox(height: 8),
                      SkeletonBox(width: 90, height: 11),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                const SkeletonBox(width: 54, height: 16),
              ],
            ),
          ),
    );
  }
}
