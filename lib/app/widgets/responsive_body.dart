import 'package:flutter/material.dart';

/// Shared responsive layout used by the app's feature screens.
///
/// Keeps content at a readable width on larger screens while allowing
/// mobile screens to use the available width. The background remains
/// transparent so the parent Scaffold and app theme control its color.
class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
  });

  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isPhone = screenWidth < 600;

    final contentMaxWidth = maxWidth ?? (isPhone ? screenWidth : 720.0);
    final contentPadding = padding ?? EdgeInsets.all(isPhone ? 16.0 : 24.0);

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: contentPadding,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxWidth),
            child: SizedBox(width: double.infinity, child: child),
          ),
        ),
      ),
    );
  }
}
