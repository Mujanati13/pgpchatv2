import 'package:flutter/material.dart';

/// Constrains child width on large screens and centers it.
/// On mobile (<600px), passes through with no change.
class ResponsiveCenter extends StatelessWidget {
  final double maxWidth;
  final Widget child;

  const ResponsiveCenter({
    super.key,
    this.maxWidth = 520,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Responsive scaffold body that centers content on wide screens
/// and adds a subtle side border on desktop.
class ResponsiveScaffoldBody extends StatelessWidget {
  final double maxWidth;
  final Widget child;
  final Color? backgroundColor;

  const ResponsiveScaffoldBody({
    super.key,
    this.maxWidth = 520,
    required this.child,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= maxWidth) {
          return child;
        }
        // Wide screen: center with side borders
        return Container(
          color: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
          child: Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: maxWidth),
              decoration: BoxDecoration(
                border: Border.symmetric(
                  vertical: BorderSide(
                    color: Colors.white.withValues(alpha: 0.06),
                    width: 1,
                  ),
                ),
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
