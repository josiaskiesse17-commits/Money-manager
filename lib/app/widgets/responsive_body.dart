import 'package:flutter/material.dart';

/// Responsive screen wrapper used on EVERY screen.
///
/// Phone (under 600 wide): full width, 16 padding.
/// Tablet/web (600+): content centered, max width 720, 24 padding.
/// Pass [maxWidth] to override (e.g. 440 for auth/setup forms,
/// 1040 for the wide two-column Home).
///
/// Width is bounded to the screen size so [Expanded]/[Flexible] children
/// inside [Row] work correctly. Height is NOT bounded — screens must size
/// themselves vertically (e.g. [SingleChildScrollView] for scrollable
/// content). Wraps content in [Material] so material widgets (dropdowns,
/// etc.) have a Material ancestor.
class ResponsiveBody extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveBody({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isPhone = width < 600;

    final boundedMaxWidth = maxWidth ?? (isPhone ? width : 720.0);

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: padding ?? EdgeInsets.all(isPhone ? 16.0 : 24.0),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: boundedMaxWidth),
          child: child,
        ),
      ),
    );
  }
}
