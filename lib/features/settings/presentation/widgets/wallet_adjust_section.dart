import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_manager/app/widgets/app_card.dart';
import 'package:money_manager/app/widgets/app_text_field.dart';
import 'package:money_manager/app/widgets/amount_text.dart';
import 'package:money_manager/app/widgets/primary_button.dart';
import 'package:money_manager/app/widgets/section_header.dart';
import 'package:money_manager/core/money/currency.dart';
import 'package:money_manager/core/money/money.dart';
import 'package:money_manager/data/models/wallet.dart';
import 'package:money_manager/data/repositories/wallet_repository.dart';
import 'package:money_manager/features/wallets/application/wallet_provider.dart';

/// Settings section listing CDF and USD wallets with "Adjust balance" buttons.
class WalletAdjustSection extends ConsumerStatefulWidget {
  const WalletAdjustSection({super.key, required this.uid});

  final String uid;

  @override
  ConsumerState<WalletAdjustSection> createState() =>
      _WalletAdjustSectionState();
}

class _WalletAdjustSectionState extends ConsumerState<WalletAdjustSection> {
  @override
  Widget build(BuildContext context) {
    final walletsAsync = ref.watch(walletProvider(widget.uid));

    return walletsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (wallets) {
        final byCurrency = <String, Wallet>{};
        for (final w in wallets) {
          byCurrency[w.currency] = w;
        }

        return AppCard(
          margin: const EdgeInsets.only(bottom: 20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Wallets',
                  subtitle:
                      'Adjust your wallet balances to match the real world.',
                ),
                const SizedBox(height: 16),
                ...['CDF', 'USD'].map((currency) {
                  final wallet = byCurrency[currency];
                  final balance = wallet?.balance ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currency,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              AmountText(
                                amount: balance,
                                currency: currency,
                                fontSize: 16,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        PrimaryButton(
                          text: 'Adjust balance',
                          onPressed: () =>
                              _showAdjustDialog(context, currency, balance),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAdjustDialog(
    BuildContext context,
    String currency,
    int currentBalance,
  ) {
    final moneyCurrency = currency == 'USD' ? Currency.usd : Currency.cdf;
    final ctrl = TextEditingController(
      text: Money(amount: currentBalance, currency: moneyCurrency).format(),
    );
    String? error;
    bool saving = false;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text('Adjust $currency balance'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter the real current balance.'),
              const SizedBox(height: 12),
              AppTextField(
                controller: ctrl,
                label: 'Current balance ($currency)',
                errorText: error,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() => error = null),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(
                  error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            PrimaryButton(
              text: 'Save',
              busy: saving,
              onPressed: saving
                  ? null
                  : () {
                      final text = ctrl.text.trim();
                      if (text.isEmpty) {
                        setState(() {
                          error = currency == 'CDF'
                              ? 'Enter a valid whole-number CDF amount'
                              : 'Enter a valid USD amount';
                        });
                        return;
                      }
                      int newBalance;
                      try {
                        newBalance = Money.parse(text, moneyCurrency).amount;
                      } on FormatException {
                        setState(() {
                          error = currency == 'CDF'
                              ? 'Enter a valid whole-number CDF amount'
                              : 'Enter a valid USD amount';
                        });
                        return;
                      }
                      final diff = newBalance - currentBalance;
                      if (diff == 0) {
                        if (!mounted) return;
                        Navigator.pop(context);
                        return;
                      }
                      setState(() => saving = true);
                      final dialogContext = context;
                      unawaited(
                        ref
                            .read(walletRepositoryProvider)
                            .adjustBalance(widget.uid, currency, diff)
                            .then((_) {
                              if (!mounted) return;
                              // ignore: use_build_context_synchronously
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(
                                  content: Text('Balance adjusted.'),
                                ),
                              );
                              if (!mounted) return;
                              // ignore: use_build_context_synchronously
                              Navigator.pop(dialogContext);
                            })
                            .catchError((e) {
                              if (!mounted) return;
                              setState(() => saving = false);
                              // ignore: use_build_context_synchronously
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(
                                  content: Text('Could not adjust balance.'),
                                ),
                              );
                            }),
                      );
                    },
            ),
          ],
        ),
      ),
    );
  }
}
