import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Router skeleton — routes are filled in as screens are built.
final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) =>
          const Scaffold(body: Center(child: Text('Auth screen'))),
    ),
  ],
);
