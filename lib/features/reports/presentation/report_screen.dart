import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_manager/app/app_shell.dart';
import 'package:money_manager/app/month_provider.dart';
import 'package:money_manager/app/routes.dart';
import 'package:money_manager/app/widgets/app_card.dart';
import 'package:money_manager/app/widgets/primary_button.dart';
import 'package:money_manager/app/widgets/responsive_body.dart';
import 'package:money_manager/app/widgets/secondary_button.dart';
import 'package:money_manager/app/widgets/section_header.dart';
import 'package:money_manager/data/models/category.dart';
import 'package:money_manager/data/models/transaction.dart';
import 'package:money_manager/data/models/wallet.dart';
import 'package:money_manager/features/categories/application/category_provider.dart';
import 'package:money_manager/features/reports/application/report_service.dart';
import 'package:money_manager/features/settings/application/settings_provider.dart';
import 'package:money_manager/features/transactions/application/transaction_provider.dart';
import 'package:money_manager/features/wallets/application/wallet_provider.dart';
import 'package:printing/printing.dart';

/// Report screen: generate PDF reports for this month, last month, or custom range.
class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(selectedMonthProvider);

    return AppShell(
      currentRoute: AppRoutes.reports,
      child: ResponsiveBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Report',
              subtitle: 'Generate a PDF report for a period.',
            ),
            const SizedBox(height: 16),
            _RangeSelector(),
            const SizedBox(height: 24),
            _ReportContent(selectedMonth: selectedMonth),
          ],
        ),
      ),
    );
  }
}

/// Range selector for the report.
class _RangeSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(_rangeProvider);

    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'this_month', label: Text('This month')),
        ButtonSegment(value: 'last_month', label: Text('Last month')),
        ButtonSegment(value: 'custom', label: Text('Custom range')),
      ],
      selected: {range},
      onSelectionChanged: (selection) {
        ref.read(_rangeProvider.notifier).state = selection.first;
        if (selection.first == 'custom') {
          ref.read(_startDateProvider.notifier).state = null;
          ref.read(_endDateProvider.notifier).state = null;
        }
      },
    );
  }
}

final _rangeProvider = StateProvider<String>((ref) => 'this_month');
final _startDateProvider = StateProvider<DateTime?>((ref) => null);
final _endDateProvider = StateProvider<DateTime?>((ref) => null);

/// Report content with PDF generation.
class _ReportContent extends ConsumerWidget {
  final DateTime selectedMonth;

  const _ReportContent({required this.selectedMonth});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = 'current_user';
    final txnsAsync = ref.watch(transactionProvider(uid));
    final catsAsync = ref.watch(categoryProvider(uid));
    final settingsAsync = ref.watch(settingsProvider(uid));
    final walletsAsync = ref.watch(walletProvider(uid));
    final generating = ref.watch(_generatingProvider);
    final pdfBytes = ref.watch(_pdfBytesProvider);

    // Check loading state
    if (txnsAsync.isLoading ||
        catsAsync.isLoading ||
        settingsAsync.isLoading ||
        walletsAsync.isLoading) {
      return const SizedBox.shrink();
    }

    // Check error state
    if (txnsAsync.hasError ||
        catsAsync.hasError ||
        settingsAsync.hasError ||
        walletsAsync.hasError) {
      return const SizedBox.shrink();
    }

    final transactions = txnsAsync.requireValue;
    final categories = catsAsync.requireValue;
    final setting = settingsAsync.requireValue;
    final wallets = walletsAsync.requireValue;

    final cdfWallet = wallets.firstWhere(
      (w) => w.currency == 'CDF',
      orElse: () =>
          const Wallet(currency: 'CDF', openingBalance: 0, balance: 0),
    );
    final usdWallet = wallets.firstWhere(
      (w) => w.currency == 'USD',
      orElse: () =>
          const Wallet(currency: 'USD', openingBalance: 0, balance: 0),
    );

    final range = _getRange(ref, selectedMonth);

    return Column(
      children: [
        _ReportPreviewCard(
          transactions: transactions,
          categories: categories,
          range: range,
          cdfBalance: cdfWallet.balance,
          usdBalance: usdWallet.balance,
          rateScaled: setting?.usdToCdfRate ?? 280050,
          generating: generating,
          pdfBytes: pdfBytes,
          onGenerate: () async {
            ref.read(_generatingProvider.notifier).state = true;
            try {
              final pdfBytes = await ReportService.generateReport(
                startDate: range.start,
                endDate: range.end,
                transactions: transactions,
                categories: categories,
                cdfBalance: cdfWallet.balance,
                usdBalance: usdWallet.balance,
                rateScaled: setting?.usdToCdfRate ?? 280050,
              );
              ref.read(_pdfBytesProvider.notifier).state = pdfBytes;
              ref.read(_generatingProvider.notifier).state = false;
            } catch (e) {
              ref.read(_generatingProvider.notifier).state = false;
            }
          },
        ),
        if (pdfBytes != null) ...[
          const SizedBox(height: 24),
          const Text('PDF generated. Use Share to save or print.'),
        ],
      ],
    );
  }

  _Range _getRange(WidgetRef ref, DateTime selectedMonth) {
    final range = ref.watch(_rangeProvider);
    final startDate = ref.watch(_startDateProvider);
    final endDate = ref.watch(_endDateProvider);

    switch (range) {
      case 'last_month':
        final lastMonth = DateTime(
          selectedMonth.year,
          selectedMonth.month - 1,
          1,
        );
        return _Range(
          label: '${_monthName(lastMonth)} ${lastMonth.year}',
          start: lastMonth,
          end: DateTime(
            lastMonth.year,
            lastMonth.month + 1,
            1,
          ).subtract(const Duration(days: 1)),
        );
      case 'custom':
        return _Range(
          label: 'Custom range',
          start: startDate ?? DateTime.now(),
          end: endDate ?? DateTime.now(),
        );
      case 'this_month':
      default:
        return _Range(
          label: '${_monthName(selectedMonth)} ${selectedMonth.year}',
          start: DateTime(selectedMonth.year, selectedMonth.month, 1),
          end: DateTime(
            selectedMonth.year,
            selectedMonth.month + 1,
            1,
          ).subtract(const Duration(days: 1)),
        );
    }
  }
}

/// Report preview card with generate/share buttons.
class _ReportPreviewCard extends ConsumerWidget {
  final List<Transaction> transactions;
  final List<Category> categories;
  final _Range range;
  final int cdfBalance;
  final int usdBalance;
  final int rateScaled;
  final bool generating;
  final Uint8List? pdfBytes;
  final VoidCallback onGenerate;

  const _ReportPreviewCard({
    required this.transactions,
    required this.categories,
    required this.range,
    required this.cdfBalance,
    required this.usdBalance,
    required this.rateScaled,
    required this.generating,
    required this.pdfBytes,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Preview',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text('Period: ${range.label}'),
          const SizedBox(height: 8),
          Text('Transactions: ${_countInRange(transactions, range)}'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  text: 'Generate PDF',
                  busy: generating,
                  onPressed: generating ? null : onGenerate,
                ),
              ),
              if (pdfBytes != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: SecondaryButton(
                    text: 'Share',
                    onPressed: () async {
                      await Printing.sharePdf(
                        bytes: pdfBytes!,
                        filename: 'money_report.pdf',
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Range {
  final String label;
  final DateTime start;
  final DateTime end;

  _Range({required this.label, required this.start, required this.end});
}

int _countInRange(List<Transaction> transactions, _Range range) {
  return transactions.where((t) {
    return t.date.isAfter(range.start.subtract(const Duration(days: 1))) &&
        t.date.isBefore(range.end.add(const Duration(days: 1)));
  }).length;
}

String _monthName(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return months[date.month - 1];
}

final _generatingProvider = StateProvider<bool>((ref) => false);
final _pdfBytesProvider = StateProvider<Uint8List?>((ref) => null);
