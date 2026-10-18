import 'package:flutter/material.dart';

/// Card with design-token styling: radius 16, 1px outline, no shadow.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  const AppCard({super.key, required this.child, this.margin, this.padding});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: margin ?? const EdgeInsets.all(0),
      child: padding != null ? Padding(padding: padding!, child: child) : child,
    );
  }
}
