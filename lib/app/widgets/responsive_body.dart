import 'package:flutter/material.dart';

/// Responsive screen wrapper used on EVERY screen.
///
/// Phone (under 600 wide): full width, 16 padding.
/// Tablet/web (600+): centered, max width 720, 24 padding.
/// Pass [maxWidth] to override (e.g. 440 for auth/setup forms).
/// Pass [maxHeight] to bound height for scrollable content (e.g. SingleChildScrollView).
class ResponsiveBody extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final double? maxHeight;
  final EdgeInsetsGeometry? padding;

  const ResponsiveBody({
    super.key,
    required this.child,
    this.maxWidth,
    this.maxHeight,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isPhone = width < 600;

    Widget content = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxWidth ?? (isPhone ? double.infinity : 720.0),
        maxHeight: maxHeight ?? double.infinity,
      ),
      child: Padding(padding: padding ?? EdgeInsets.all(8.0), child: child),
    );

    // Center non-scrollable content horizontally on wide screens.
    // Scrollable content (maxHeight set) must not be inside Center,
    // because Center passes unbounded height constraints that break
    // SingleChildScrollView layout.
    if (maxHeight == null) {
      content = Center(child: content);
    }

    return content;
  }
}
