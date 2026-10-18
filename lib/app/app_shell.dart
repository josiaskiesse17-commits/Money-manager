import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:money_manager/app/routes.dart';

/// Navigation shell for the app.
///
/// Bottom [NavigationBar] under 840px wide, [NavigationRail] at 840px and
/// above. Destinations: Home, Transactions, Budgets, Charts, Settings.
class AppShell extends StatefulWidget {
  final Widget child;
  final String currentRoute;

  const AppShell({super.key, required this.child, required this.currentRoute});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = _routeToIndex(widget.currentRoute);
  }

  int _routeToIndex(String route) {
    switch (route) {
      case AppRoutes.home:
        return 0;
      case AppRoutes.transactions:
        return 1;
      case AppRoutes.budgets:
        return 2;
      case AppRoutes.charts:
        return 3;
      case AppRoutes.settings:
        return 4;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 840;

    final body = isWide
        ? Row(
            children: [
              NavigationRail(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (index) => _navigateTo(index),
                labelType: NavigationRailLabelType.all,
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.home),
                    label: Text('Home'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.receipt_long),
                    label: Text('Transactions'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.account_balance_wallet),
                    label: Text('Budgets'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.bar_chart),
                    label: Text('Charts'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.settings),
                    label: Text('Settings'),
                  ),
                ],
              ),
              const VerticalDivider(thickness: 1, width: 1),
              Expanded(child: widget.child),
            ],
          )
        : widget.child;

    return Scaffold(
      body: body,
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) => _navigateTo(index),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long),
                  label: 'Transactions',
                ),
                NavigationDestination(
                  icon: Icon(Icons.account_balance_wallet),
                  label: 'Budgets',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bar_chart),
                  label: 'Charts',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
    );
  }

  void _navigateTo(int index) {
    setState(() => _selectedIndex = index);
    switch (index) {
      case 0:
        context.go(AppRoutes.home);
        break;
      case 1:
        context.go(AppRoutes.transactions);
        break;
      case 2:
        context.go(AppRoutes.budgets);
        break;
      case 3:
        context.go(AppRoutes.charts);
        break;
      case 4:
        context.go(AppRoutes.settings);
        break;
    }
  }
}
