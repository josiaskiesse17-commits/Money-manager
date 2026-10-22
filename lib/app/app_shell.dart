import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:money_manager/app/routes.dart';

/// Navigation shell for the app.
///
/// Bottom NavigationBar under 840px wide, NavigationRail at 840px and above.
/// Supports horizontal swiping between the five main destinations.
class AppShell extends StatefulWidget {
  final Widget child;
  final String currentRoute;

  const AppShell({super.key, required this.child, required this.currentRoute});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _selectedIndex;

  double _horizontalDragDistance = 0;

  static const double _minimumSwipeDistance = 80;
  static const double _minimumSwipeVelocity = 300;

  @override
  void initState() {
    super.initState();
    _selectedIndex = _routeToIndex(widget.currentRoute);
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.currentRoute != widget.currentRoute) {
      _selectedIndex = _routeToIndex(widget.currentRoute);
    }
  }

  int _routeToIndex(String route) {
    if (route == AppRoutes.home) return 0;
    if (route == AppRoutes.transactions) return 1;
    if (route == AppRoutes.convert) return 2;
    if (route == AppRoutes.budgets) return 3;
    if (route == AppRoutes.charts) return 4;
    if (route == AppRoutes.settings) return 5;
    if (route == AppRoutes.reports) return 5;

    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 840;

    final destinations = const [
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Home',
      ),
      NavigationDestination(
        icon: Icon(Icons.receipt_long_outlined),
        selectedIcon: Icon(Icons.receipt_long),
        label: 'Transactions',
      ),
      NavigationDestination(
        icon: Icon(Icons.currency_exchange_outlined),
        selectedIcon: Icon(Icons.currency_exchange),
        label: 'Convert',
      ),
      NavigationDestination(
        icon: Icon(Icons.account_balance_wallet_outlined),
        selectedIcon: Icon(Icons.account_balance_wallet),
        label: 'Budgets',
      ),
      NavigationDestination(
        icon: Icon(Icons.bar_chart_outlined),
        selectedIcon: Icon(Icons.bar_chart),
        label: 'Charts',
      ),
      NavigationDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings),
        label: 'Settings',
      ),
    ];

    final body = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) {
        _horizontalDragDistance = 0;
      },
      onHorizontalDragUpdate: (details) {
        _horizontalDragDistance += details.delta.dx;
      },
      onHorizontalDragEnd: (details) {
        _handleSwipe(
          distance: _horizontalDragDistance,
          velocity: details.primaryVelocity ?? 0,
        );
        _horizontalDragDistance = 0;
      },
      child: widget.child,
    );

    return Scaffold(
      body: isWide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _navigateTo,
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: Text('Home'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.receipt_long_outlined),
                      selectedIcon: Icon(Icons.receipt_long),
                      label: Text('Transactions'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.currency_exchange_outlined),
                      selectedIcon: Icon(Icons.currency_exchange),
                      label: Text('Convert'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.account_balance_wallet_outlined),
                      selectedIcon: Icon(Icons.account_balance_wallet),
                      label: Text('Budgets'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.bar_chart_outlined),
                      selectedIcon: Icon(Icons.bar_chart),
                      label: Text('Charts'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings),
                      label: Text('Settings'),
                    ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: body),
              ],
            )
          : body,
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _navigateTo,
              destinations: destinations,
            ),
    );
  }

  void _handleSwipe({required double distance, required double velocity}) {
    final isLongEnough = distance.abs() >= _minimumSwipeDistance;
    final isFastEnough = velocity.abs() >= _minimumSwipeVelocity;

    if (!isLongEnough && !isFastEnough) return;

    if (distance < 0 || velocity < -_minimumSwipeVelocity) {
      // Swipe left: move to the next main destination.
      if (_selectedIndex < 5) {
        _navigateTo(_selectedIndex + 1);
      }
    } else if (distance > 0 || velocity > _minimumSwipeVelocity) {
      // Swipe right: move to the previous main destination.
      if (_selectedIndex > 0) {
        _navigateTo(_selectedIndex - 1);
      }
    }
  }

  void _navigateTo(int index) {
    if (index < 0 || index > 5 || index == _selectedIndex) {
      return;
    }

    final routes = [
      AppRoutes.home,
      AppRoutes.transactions,
      AppRoutes.convert,
      AppRoutes.budgets,
      AppRoutes.charts,
      AppRoutes.settings,
    ];

    context.go(routes[index]);
  }
}
