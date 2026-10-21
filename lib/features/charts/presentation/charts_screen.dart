import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_manager/app/month_provider.dart';
import 'package:money_manager/app/theme.dart';
import 'package:money_manager/app/widgets/amount_text.dart';
import 'package:money_manager/app/widgets/empty_state.dart';
import 'package:money_manager/app/widgets/error_banner.dart';
import 'package:money_manager/app/widgets/responsive_body.dart';
import 'package:money_manager/app/widgets/section_header.dart';
import 'package:money_manager/data/models/category.dart';
import 'package:money_manager/data/models/transaction.dart';
import 'package:money_manager/features/auth/application/auth_provider.dart';
import 'package:money_manager/features/categories/application/category_provider.dart';
import 'package:money_manager/features/settings/application/settings_provider.dart';
import 'package:money_manager/features/transactions/application/transaction_provider.dart';

/// Charts screen: donut of spending by category + daily bars.
class ChartsScreen extends ConsumerWidget {
  const ChartsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final uid = user?.uid ?? '';
    final selectedMonth = ref.watch(selectedMonthProvider);
    final transactionsAsync = ref.watch(transactionProvider(uid));
    final categoriesAsync = ref.watch(categoryProvider(uid));
    final settingsAsync = ref.watch(settingsProvider(uid));

    return ResponsiveBody(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Charts',
              subtitle: 'Spending breakdown for the selected month.',
            ),
            const SizedBox(height: 16),
            transactionsAsync.when(
              data: (transactions) => categoriesAsync.when(
                data: (categories) => settingsAsync.when(
                  data: (setting) {
                    final monthStart = DateTime(
                      selectedMonth.year,
                      selectedMonth.month,
                      1,
                    );
                    final monthEnd = DateTime(
                      selectedMonth.year,
                      selectedMonth.month + 1,
                      1,
                    );

                    final expenseTxns = transactions.where((t) {
                      return t.type == 'expense' &&
                          t.date.isAfter(monthStart) &&
                          t.date.isBefore(monthEnd);
                    }).toList();

                    if (expenseTxns.isEmpty) {
                      return const EmptyState(
                        icon: Icons.show_chart,
                        title: 'No expenses this month',
                        subtitle: 'Add expenses to see charts.',
                      );
                    }

                    final displayCurrency = setting?.displayMode ?? 'CDF';
                    final rateScaled = setting?.usdToCdfRate ?? 280050;

                    final Map<String, int> categorySpending = {};
                    for (final txn in expenseTxns) {
                      int converted = txn.amount;
                      if (txn.currency != displayCurrency) {
                        if (txn.currency == 'USD' && displayCurrency == 'CDF') {
                          converted = (txn.amount * rateScaled) ~/ 10000;
                        } else if (txn.currency == 'CDF' &&
                            displayCurrency == 'USD') {
                          converted = (txn.amount * 10000) ~/ rateScaled;
                        }
                      }
                      categorySpending[txn.categoryId] =
                          (categorySpending[txn.categoryId] ?? 0) + converted;
                    }

                    final totalSpending = categorySpending.values.fold<int>(
                      0,
                      (sum, v) => sum + v,
                    );

                    return Column(
                      children: [
                        const SectionHeader(
                          title: 'Spending by category',
                          subtitle: 'Donut chart shows share of each category.',
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 280,
                          child: DonutChart(
                            categorySpending: categorySpending,
                            categories: categories,
                            total: totalSpending,
                          ),
                        ),
                        const SizedBox(height: 32),
                        const SectionHeader(
                          title: 'Daily spending',
                          subtitle: 'Bar chart shows spending per day.',
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 280,
                          child: DailyBarsChart(
                            transactions: expenseTxns,
                            categories: categories,
                            month: selectedMonth,
                            displayCurrency: displayCurrency,
                            rateScaled: rateScaled,
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const SizedBox(
                    height: 160,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, _) => ErrorBanner(
                    message: 'Failed to load settings.',
                    fix: 'Check your connection and try again.',
                    onRetry: () => ref.refresh(settingsProvider(uid)),
                  ),
                ),
                loading: () => const SizedBox(
                  height: 160,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => ErrorBanner(
                  message: 'Failed to load categories.',
                  fix: 'Check your connection and try again.',
                  onRetry: () => ref.refresh(categoryProvider(uid)),
                ),
              ),
              loading: () => const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => ErrorBanner(
                message: 'Failed to load transactions.',
                fix: 'Check your connection and try again.',
                onRetry: () => ref.refresh(transactionProvider(uid)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Donut chart showing spending by category.
class DonutChart extends StatelessWidget {
  final Map<String, int> categorySpending;
  final List<Category> categories;
  final int total;

  const DonutChart({
    super.key,
    required this.categorySpending,
    required this.categories,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final moneyColors = Theme.of(context).extension<MoneyColors>();
    final entries = categorySpending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Row(
      children: [
        Expanded(
          child: AspectRatio(
            aspectRatio: 1,
            child: PieChart(
              PieChartData(
                startDegreeOffset: 270,
                sections: entries.map((entry) {
                  final cat = categories
                      .where((c) => c.id == entry.key)
                      .firstOrNull;
                  if (cat == null) return PieChartSectionData(value: 0);
                  final pct = total > 0 ? (entry.value * 100) ~/ total : 0;
                  return PieChartSectionData(
                    value: entry.value.toDouble(),
                    title: '$pct%',
                    color: cat.type == 'expense'
                        ? (moneyColors?.expense ??
                              Theme.of(context).colorScheme.error)
                        : Theme.of(context).colorScheme.primary,
                    radius: 60,
                  );
                }).toList(),
                centerSpaceRadius: 40,
                sectionsSpace: 4,
              ),
            ),
          ),
        ),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: entries.map((entry) {
              final cat = categories
                  .where((c) => c.id == entry.key)
                  .firstOrNull;
              if (cat == null) return const SizedBox.shrink();
              final pct = total > 0 ? (entry.value * 100) ~/ total : 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: cat.type == 'expense'
                            ? (moneyColors?.expense ??
                                  Theme.of(context).colorScheme.error)
                            : Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        cat.name,
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    AmountText(
                      amount: entry.value,
                      currency: cat.type == 'expense' ? 'CDF' : 'USD',
                      fontSize: 14,
                    ),
                    const SizedBox(width: 4),
                    Text('($pct%)'),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

/// Daily bars chart showing spending per day.
class DailyBarsChart extends StatelessWidget {
  final List<Transaction> transactions;
  final List<Category> categories;
  final DateTime month;
  final String displayCurrency;
  final int rateScaled;

  const DailyBarsChart({
    super.key,
    required this.transactions,
    required this.categories,
    required this.month,
    required this.displayCurrency,
    required this.rateScaled,
  });

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final Map<int, int> dailySpending = {};

    for (final txn in transactions) {
      int converted = txn.amount;
      if (txn.currency != displayCurrency) {
        if (txn.currency == 'USD' && displayCurrency == 'CDF') {
          converted = (txn.amount * rateScaled) ~/ 10000;
        } else if (txn.currency == 'CDF' && displayCurrency == 'USD') {
          converted = (txn.amount * 10000) ~/ rateScaled;
        }
      }
      final day = txn.date.day;
      dailySpending[day] = (dailySpending[day] ?? 0) + converted;
    }

    final maxSpending = dailySpending.values.fold<int>(
      0,
      (sum, v) => sum > v ? sum : v,
    );

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (maxSpending > 0 ? maxSpending : 1).toDouble() * 1.2,
        barGroups: List.generate(daysInMonth, (i) {
          final day = i + 1;
          final amount = dailySpending[day] ?? 0;
          return BarChartGroupData(
            x: day,
            barRods: [
              BarChartRodData(
                toY: amount.toDouble(),
                width: 12,
                color: Theme.of(context).colorScheme.primary,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: (maxSpending > 0 ? maxSpending : 1).toDouble(),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ),
            ],
          );
        }),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final day = value.toInt();
                if (day % 7 == 1 || day == daysInMonth) {
                  return Text('$day', style: const TextStyle(fontSize: 10));
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
      ),
    );
  }
}
