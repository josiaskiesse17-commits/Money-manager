import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:money_manager/app/routes.dart';
import 'package:money_manager/app/theme.dart';
import 'package:money_manager/features/transactions/presentation/add_edit_transaction_sheet.dart';

/// Navigation shell for the tab screens.
///
/// Owns the single [Scaffold] and [AppBar] of every tab screen: the screen
/// title comes from the route, and a Settings gear opens [AppRoutes.settings].
/// Bottom [NavigationBar] under 840px wide, [NavigationRail] at 840px and
/// above. Destinations: Home, Activity, Convert, Budgets, Charts.
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

  static int _routeToIndex(String route) {
    switch (route) {
      case AppRoutes.home:
        return 0;
      case AppRoutes.transactions:
        return 1;
      case AppRoutes.convert:
        return 2;
      case AppRoutes.budgets:
        return 3;
      case AppRoutes.charts:
        return 4;
      default:
        return 0;
    }
  }

  /// Screen title shown in the [AppBar], taken from the current route.
  static String _screenTitle(String route) {
    switch (route) {
      case AppRoutes.home:
        return 'Home';
      case AppRoutes.transactions:
        return 'Activity';
      case AppRoutes.convert:
        return 'Convert';
      case AppRoutes.budgets:
        return 'Budgets';
      case AppRoutes.charts:
        return 'Charts';
      case AppRoutes.reports:
        return 'Reports';
      default:
        return 'Home';
    }
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
        label: 'Activity',
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: appSystemOverlayStyle(context),
      child: Scaffold(
        appBar: AppBar(
          title: Text(_screenTitle(widget.currentRoute)),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Settings',
              onPressed: () => context.push(AppRoutes.settings),
            ),
          ],
        ),
        floatingActionButton: widget.currentRoute == AppRoutes.home
            ? FloatingActionButton(
                tooltip: 'Add transaction',
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (_) => const AddEditTransactionSheet(),
                ),
                child: const Icon(Icons.add),
              )
            : null,
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
                        label: Text(
                          'Home',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.receipt_long_outlined),
                        selectedIcon: Icon(Icons.receipt_long),
                        label: Text(
                          'Activity',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.currency_exchange_outlined),
                        selectedIcon: Icon(Icons.currency_exchange),
                        label: Text(
                          'Convert',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.account_balance_wallet_outlined),
                        selectedIcon: Icon(Icons.account_balance_wallet),
                        label: Text(
                          'Budgets',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.bar_chart_outlined),
                        selectedIcon: Icon(Icons.bar_chart),
                        label: Text(
                          'Charts',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
      ),
    );
  }

  void _handleSwipe({required double distance, required double velocity}) {
    final isLongEnough = distance.abs() >= _minimumSwipeDistance;
    final isFastEnough = velocity.abs() >= _minimumSwipeVelocity;

    if (!isLongEnough && !isFastEnough) return;

    if (distance < 0 || velocity < -_minimumSwipeVelocity) {
      // Swipe left: move to the next main destination.
      if (_selectedIndex < 4) {
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
    if (index < 0 || index > 4 || index == _selectedIndex) {
      return;
    }

    final routes = [
      AppRoutes.home,
      AppRoutes.transactions,
      AppRoutes.convert,
      AppRoutes.budgets,
      AppRoutes.charts,
    ];

    context.go(routes[index]);
  }
}
