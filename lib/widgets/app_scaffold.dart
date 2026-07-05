import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Standard screen shell so all 30+ screens share one app-bar treatment
/// instead of each rebuilding a teal `AppBar` by hand.
///
/// Set [gradientHeader] for landing-style screens (dashboard, analytics) that
/// want the brand gradient behind the title; leave it off for plain screens.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.leading,
    this.floatingActionButton,
    this.bottom,
    this.gradientHeader = false,
    this.centerTitle = false,
    this.titleWidget,
    this.backgroundColor,
    this.resizeToAvoidBottomInset,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? leading;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? bottom;
  final bool gradientHeader;
  final bool centerTitle;
  final Widget? titleWidget;
  final Color? backgroundColor;
  final bool? resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (!gradientHeader) {
      return Scaffold(
        backgroundColor: backgroundColor ?? c.surface,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        appBar: AppBar(
          title: titleWidget ?? Text(title),
          centerTitle: centerTitle,
          leading: leading,
          actions: actions,
          bottom: bottom,
        ),
        floatingActionButton: floatingActionButton,
        body: body,
      );
    }

    // Gradient header variant: a brand-colored bar with light foreground.
    return Scaffold(
      backgroundColor: backgroundColor ?? c.surface,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: AppBar(
        title: titleWidget ?? Text(title),
        centerTitle: centerTitle,
        leading: leading,
        actions: actions,
        bottom: bottom,
        foregroundColor: c.onBrand,
        iconTheme: IconThemeData(color: c.onBrand),
        titleTextStyle: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(color: c.onBrand),
        flexibleSpace: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [c.heroGradientStart, c.heroGradientEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      floatingActionButton: floatingActionButton,
      body: body,
    );
  }
}
