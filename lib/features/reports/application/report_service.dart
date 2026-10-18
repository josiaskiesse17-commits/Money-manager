import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:money_manager/data/models/category.dart';
import 'package:money_manager/data/models/transaction.dart';

/// Generates a PDF report for a given date range.
///
/// Includes period, totals per wallet, full transaction list oldest first,
/// and a footer note that conversions are excluded.
class ReportService {
  /// Generates PDF bytes for transactions in [startDate] to [endDate].
  static Future<Uint8List> generateReport({
    required DateTime startDate,
    required DateTime endDate,
    required List<Transaction> transactions,
    required List<Category> categories,
    required int cdfBalance,
    required int usdBalance,
    required int rateScaled,
  }) async {
    final pdf = pw.Document();

    final periodText = '${_monthName(startDate)} ${startDate.year}';

    final categoryMap = <String, Category>{};
    for (final c in categories) {
      categoryMap[c.id] = c;
    }

    final periodTxns =
        transactions
            .where(
              (t) =>
                  t.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
                  t.date.isBefore(endDate.add(const Duration(days: 1))),
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Money Manager Report',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text('Period: $periodText'),
              pw.SizedBox(height: 16),
              pw.Text(
                'Wallet Totals',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text('CDF Balance: ${_formatCdf(cdfBalance)}'),
              pw.Text(
                'USD Balance: \$${(usdBalance / 100).toStringAsFixed(2)}',
              ),
              pw.SizedBox(height: 16),
              pw.Text(
                'Transactions',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              if (periodTxns.isEmpty)
                pw.Text('No transactions in this period.')
              else
                ...periodTxns.map((txn) {
                  final cat = categoryMap[txn.categoryId];
                  return pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        '${txn.date.toLocal()} - ${cat?.name ?? 'Unknown'}',
                      ),
                      pw.Text(
                        txn.currency == 'CDF'
                            ? '${txn.type == 'income' ? '+' : '-'}${_formatCdf(txn.amount)}'
                            : '${txn.type == 'income' ? '+' : '-'}\$${(txn.amount / 100).toStringAsFixed(2)}',
                      ),
                    ],
                  );
                }),
              pw.SizedBox(height: 24),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Text(
                'Note: Wallet-to-wallet conversions are excluded from this report.',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static String _monthName(DateTime date) {
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

  static String _formatCdf(int amount) {
    final s = amount.abs().toString();
    if (s.length <= 3) return s;
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
