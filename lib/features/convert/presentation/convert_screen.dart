import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:money_manager/app/app_shell.dart';
import 'package:money_manager/app/routes.dart';
import 'package:money_manager/app/widgets/app_card.dart';
import 'package:money_manager/app/widgets/amount_text.dart';
import 'package:money_manager/app/widgets/app_text_field.dart';
import 'package:money_manager/app/widgets/empty_state.dart';
import 'package:money_manager/app/widgets/error_banner.dart';
import 'package:money_manager/app/widgets/primary_button.dart';
import 'package:money_manager/app/widgets/responsive_body.dart';
import 'package:money_manager/app/widgets/section_header.dart';
import 'package:money_manager/data/models/conversion.dart';
import 'package:money_manager/features/auth/application/auth_provider.dart';
import 'package:money_manager/features/convert/application/conversion_provider.dart';
import 'package:money_manager/features/settings/application/settings_provider.dart';

/// Convert screen: convert between CDF and USD wallets.
class ConvertScreen extends ConsumerStatefulWidget {
  const ConvertScreen({super.key});

  @override
  ConsumerState<ConvertScreen> createState() => _ConvertScreenState();
}

class _ConvertScreenState extends ConsumerState<ConvertScreen> {
  String _direction = 'usd_to_cdf'; // usd_to_cdf | cdf_to_usd
  final _amountCtrl = TextEditingController();
  int _rateScaled = 280050; // 2800.50
  String? _error;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  int? _previewAmount;

  void _updatePreview() {
    final text = _amountCtrl.text.replaceAll(',', '');
    if (text.isEmpty) {
      setState(() {
        _previewAmount = null;
      });
      return;
    }

    try {
      int fromAmount;
      if (_direction == 'usd_to_cdf') {
        final parts = text.split('.');
        final combined = parts.join('');
        fromAmount = int.parse(combined);
        if (parts.length == 2 && parts[1].length == 1) {
          fromAmount *= 10;
        }
      } else {
        final cleaned = text.replaceAll('.', '');
        fromAmount = int.parse(cleaned);
      }

      int toAmount;
      if (_direction == 'usd_to_cdf') {
        // USD cents -> CDF francs: cents * rateScaled / 10000
        toAmount = (fromAmount * _rateScaled) ~/ 10000;
        // Round half away from zero
        final remainder = (fromAmount * _rateScaled) % 10000;
        if (remainder * 2 >= 10000) toAmount++;
      } else {
        // CDF francs -> USD cents: francs * 10000 / rateScaled
        toAmount = (fromAmount * 10000) ~/ _rateScaled;
        final remainder = (fromAmount * 10000) % _rateScaled;
        if (remainder * 2 >= _rateScaled) toAmount++;
      }

      setState(() {
        _previewAmount = toAmount;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _previewAmount = null;
        _error = 'Invalid amount';
      });
    }
  }

  String _formatCdf(int amount) {
    final s = amount.abs().toString();
    if (s.length <= 3) return s;
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  Future<void> _saveConversion(WidgetRef ref, String uid) async {
    if (_previewAmount == null) return;

    final fromAmount =
        int.tryParse(
          _amountCtrl.text.replaceAll(',', '').replaceAll('.', ''),
        ) ??
        0;

    final conversion = Conversion(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fromCurrency: _direction == 'usd_to_cdf' ? 'USD' : 'CDF',
      toCurrency: _direction == 'usd_to_cdf' ? 'CDF' : 'USD',
      fromAmount: fromAmount,
      toAmount: _previewAmount!,
      rate: _rateScaled,
      date: DateTime.now(),
    );

    try {
      await ref.read(conversionProvider(uid).notifier).add(conversion);
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _error = 'Failed to save conversion');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final uid = user?.uid ?? '';
    final settingsAsync = ref.watch(settingsProvider(uid));
    final conversionsAsync = ref.watch(conversionProvider(uid));

    return AppShell(
      currentRoute: AppRoutes.convert,
      child: ResponsiveBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Convert',
              subtitle: 'Move money between your CDF and USD wallets.',
            ),
            const SizedBox(height: 16),
            settingsAsync.when(
              data: (setting) {
                if (setting != null) _rateScaled = setting.usdToCdfRate;
                return Column(
                  children: [
                    // Direction toggle
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'usd_to_cdf',
                          label: Text('USD → CDF'),
                        ),
                        ButtonSegment(
                          value: 'cdf_to_usd',
                          label: Text('CDF → USD'),
                        ),
                      ],
                      selected: {_direction},
                      onSelectionChanged: (selection) {
                        setState(() => _direction = selection.first);
                        _amountCtrl.clear();
                        _updatePreview();
                      },
                    ),
                    const SizedBox(height: 24),
                    // Rate display
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Current rate'),
                          Text(
                            '1 USD = ${_formatCdf(_rateScaled ~/ 100)}.${(_rateScaled % 100).toString().padLeft(2, '0')} CDF',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Amount input
                    const SectionHeader(title: 'Amount'),
                    const SizedBox(height: 8),
                    AppTextField(
                      controller: _amountCtrl,
                      label: _direction == 'usd_to_cdf' ? 'USD' : 'CDF',
                      helperText: _direction == 'usd_to_cdf'
                          ? 'Max 2 decimals'
                          : 'Whole francs',
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _updatePreview(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      ErrorBanner(message: _error!),
                    ],
                    const SizedBox(height: 16),
                    // Preview
                    if (_previewAmount != null) ...[
                      AppCard(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('You will receive'),
                            AmountText(
                              amount: _previewAmount!,
                              currency: _direction == 'usd_to_cdf'
                                  ? 'CDF'
                                  : 'USD',
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    // Save button
                    PrimaryButton(
                      text: 'Convert',
                      onPressed: _previewAmount == null
                          ? null
                          : () => _saveConversion(ref, uid),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => ErrorBanner(message: 'Failed to load settings'),
            ),
            const SizedBox(height: 32),
            // Conversion history
            const SectionHeader(title: 'History'),
            const SizedBox(height: 8),
            conversionsAsync.when(
              data: (conversions) {
                if (conversions.isEmpty) {
                  return const EmptyState(
                    icon: Icons.swap_horiz,
                    title: 'No conversions yet',
                    subtitle: 'Convert between wallets to see history here.',
                  );
                }
                return SizedBox(
                  height: 300,
                  child: ListView.builder(
                    itemCount: conversions.length,
                    itemBuilder: (_, index) {
                      final c = conversions[index];
                      return ListTile(
                        leading: const Icon(Icons.swap_horiz),
                        title: Text('${c.fromCurrency} → ${c.toCurrency}'),
                        subtitle: Text(
                          DateFormat('MMM d, yyyy hh:mm a').format(c.date),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AmountText(
                              amount: c.toAmount,
                              currency: c.toCurrency,
                              fontSize: 14,
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                await ref
                                    .read(conversionProvider(uid).notifier)
                                    .delete(c);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => ErrorBanner(message: 'Failed to load history'),
            ),
          ],
        ),
      ),
    );
  }
}
