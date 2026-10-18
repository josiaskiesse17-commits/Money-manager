import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared selected month across Home, Transactions, Budgets, and Charts.
///
/// All screens use the same month so navigation is consistent.
final selectedMonthProvider = StateNotifierProvider<MonthNotifier, DateTime>((
  ref,
) {
  return MonthNotifier();
});

class MonthNotifier extends StateNotifier<DateTime> {
  MonthNotifier() : super(DateTime.now());

  void setMonth(int year, int month) {
    state = DateTime(year, month, 1);
  }

  void previousMonth() {
    state = DateTime(state.year, state.month - 1, 1);
  }

  void nextMonth() {
    state = DateTime(state.year, state.month + 1, 1);
  }
}
