import 'package:flutter/material.dart';

/// Responsive screen wrapper used on EVERY screen.
///
/// Phone (under 600 wide): full width, 16 padding.
/// Tablet/web (600+): content centered, max width 720, 24 padding.
/// Pass [maxWidth] to override (e.g. 440 for auth/setup forms,
/// 1040 for the wide two-column Home).
///
/// Height is NOT bounded here — screens must size themselves vertically
/// (e.g. [SingleChildScrollView] for scrollable content, [shrinkWrap: true]
/// for [ListView], [mainAxisSize: MainAxisSize.min] for [Column]). [Align]
/// keeps content at the top and shrink-wraps safely when the incoming
/// height constraint is unbounded.
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

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? (isPhone ? double.infinity : 720.0),
        ),
        child: Padding(
          padding: padding ?? EdgeInsets.all(isPhone ? 16.0 : 24.0),
          child: child,
        ),
      ),
    );
  }
}
