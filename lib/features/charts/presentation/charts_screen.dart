import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_manager/app/month_provider.dart';
import 'package:money_manager/app/widgets/amount_text.dart';
import 'package:money_manager/app/widgets/empty_state.dart';
import 'package:money_manager/app/widgets/error_banner.dart';
import 'package:money_manager/app/widgets/responsive_body.dart';
import 'package:money_manager/app/widgets/section_header.dart';
import 'package:money_manager/data/models/category.dart';
import 'package:money_manager/data/models/transaction.dart';
import 'package:money_manager/features/auth/application/auth_provider.dart';
import 'package:money_manager/features/categories/application/category_provider.dart';
import 'package:money_manager/features/charts/application/chart_totals.dart';
import 'package:money_manager/features/home/application/home_totals.dart';
import 'package:money_manager/features/settings/application/settings_provider.dart';
import 'package:money_manager/features/transactions/application/transaction_provider.dart';

/// Distinct slice colors; index follows the sorted category order.
const List<Color> _chartPalette = [
  Color(0xFF0F5FA8),
  Color(0xFFD9A21B),
  Color(0xFF1B9E8F),
  Color(0xFF7B5EA7),
  Color(0xFFE0752B),
  Color(0xFFC2477A),
  Color(0xFF5B8C2A),
  Color(0xFF5C7080),
];

Color _colorAt(int index) => _chartPalette[index % _chartPalette.length];

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

    final width = MediaQuery.sizeOf(context).width;
    final isPhone = width < 600;

    return Scaffold(
      body: ResponsiveBody(
        maxWidth: width >= 900 ? 1040 : null,
        padding: EdgeInsets.only(
          left: isPhone ? 16 : 24,
          top: 0,
          right: isPhone ? 16 : 24,
          bottom: isPhone ? 16 : 24,
        ),
        child: SafeArea(
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
                        final expenseTxns = transactions.where((t) {
                          return t.type == 'expense' &&
                              isInMonth(t.date, selectedMonth);
                        }).toList();

                        if (expenseTxns.isEmpty) {
                          return const EmptyState(
                            icon: Icons.show_chart,
                            title: 'No expenses this month',
                            subtitle: 'Add expenses to see charts.',
                          );
                        }

                        // displayMode is cdf | usd | combined (combined = CDF).
                        final target = targetCurrencyFor(
                          setting?.displayMode ?? 'combined',
                        );

                        final categorySpending = spendingByCategory(
                          expenses: expenseTxns,
                          target: target,
                        );

                        final totalSpending = categorySpending.values.fold<int>(
                          0,
                          (sum, v) => sum + v,
                        );

                        return Column(
                          children: [
                            SectionHeader(
                              title: 'Spending by category',
                              subtitle:
                                  'Share of each category. Amounts in $target.',
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 280,
                              child: DonutChart(
                                categorySpending: categorySpending,
                                categories: categories,
                                total: totalSpending,
                                currency: target,
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
                                displayCurrency: target,
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
        ),
      ),
    );
  }
}

/// Donut chart showing spending by category.
/// [currency] is the currency the amounts are expressed in.
class DonutChart extends StatelessWidget {
  final Map<String, int> categorySpending;
  final List<Category> categories;
  final int total;
  final String currency;

  const DonutChart({
    super.key,
    required this.categorySpending,
    required this.categories,
    required this.total,
    this.currency = 'CDF',
  });

  @override
  Widget build(BuildContext context) {
    // Only categories we can name; largest first. Color index follows order.
    final entries =
        categorySpending.entries
            .where((e) => categories.any((c) => c.id == e.key))
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return Row(
      children: [
        Expanded(
          child: AspectRatio(
            aspectRatio: 1,
            child: PieChart(
              PieChartData(
                startDegreeOffset: 270,
                sections: [
                  for (var i = 0; i < entries.length; i++)
                    PieChartSectionData(
                      value: entries[i].value.toDouble(),
                      title: _pct(entries[i].value) >= 5
                          ? '${_pct(entries[i].value)}%'
                          : '',
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      color: _colorAt(i),
                      radius: 60,
                    ),
                ],
                centerSpaceRadius: 40,
                sectionsSpace: 4,
              ),
            ),
          ),
        ),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < entries.length; i++)
                _legendRow(context, entries[i], i),
            ],
          ),
        ),
      ],
    );
  }

  int _pct(int value) => total > 0 ? (value * 100) ~/ total : 0;

  Widget _legendRow(BuildContext context, MapEntry<String, int> entry, int i) {
    final cat = categories.firstWhereOrNull((c) => c.id == entry.key);
    if (cat == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: _colorAt(i),
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
            currency: currency,
            type: 'expense',
            fontSize: 14,
          ),
          const SizedBox(width: 4),
          Text('(${_pct(entry.value)}%)'),
        ],
      ),
    );
  }
}

/// Daily bars chart showing spending per day.
/// Each transaction is converted with its own rateAtEntry.
/// [rateScaled] is kept only for compatibility and is ignored.
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
    this.rateScaled = 0,
  });

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final target = displayCurrency == 'USD' || displayCurrency == 'usd'
        ? 'USD'
        : 'CDF';
    final dailySpending = spendingByDay(expenses: transactions, target: target);

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
