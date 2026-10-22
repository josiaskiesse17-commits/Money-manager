import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:money_manager/app/widgets/app_card.dart';
import 'package:money_manager/app/widgets/app_text_field.dart';
import 'package:money_manager/app/widgets/primary_button.dart';
import 'package:money_manager/app/widgets/section_header.dart';
import 'package:money_manager/core/money/currency.dart';
import 'package:money_manager/core/money/money.dart';
import 'package:money_manager/data/models/setting.dart';
import 'package:money_manager/features/settings/application/settings_provider.dart';

/// Exchange rate section: the CDF value of one US dollar.
class ExchangeRateSection extends ConsumerStatefulWidget {
  final Setting setting;
  final String uid;

  const ExchangeRateSection({
    super.key,
    required this.setting,
    required this.uid,
  });

  @override
  ConsumerState<ExchangeRateSection> createState() =>
      _ExchangeRateSectionState();
}

class _ExchangeRateSectionState extends ConsumerState<ExchangeRateSection> {
  final TextEditingController _rateController = TextEditingController();
  final FocusNode _rateFocusNode = FocusNode();

  String? _controllerUid;
  String? _rateError;

  bool _savingRate = false;

  @override
  void dispose() {
    _rateController.dispose();
    _rateFocusNode.dispose();
    super.dispose();
  }

  /// Keeps the field in sync with the stored rate without overwriting what
  /// the user is typing.
  void _syncRateController() {
    final formattedRate = Money(
      amount: widget.setting.usdToCdfRate,
      currency: Currency.usd,
    ).format();

    if (_controllerUid != widget.uid) {
      _controllerUid = widget.uid;
      _rateController.text = formattedRate;
      _rateError = null;
      return;
    }

    if (!_rateFocusNode.hasFocus &&
        !_savingRate &&
        _rateError == null &&
        _rateController.text != formattedRate) {
      _rateController.text = formattedRate;
    }
  }

  Future<void> _saveExchangeRate() async {
    if (_savingRate) return;

    int scaledRate;
    try {
      scaledRate = Money.parse(
        _rateController.text.trim(),
        Currency.usd,
      ).amount;
    } on FormatException {
      setState(() {
        _rateError = 'Enter a valid exchange rate greater than zero.';
      });
      return;
    }

    if (scaledRate <= 0 || scaledRate > 10000000000) {
      setState(() {
        _rateError = 'Enter a valid exchange rate greater than zero.';
      });
      return;
    }

    setState(() {
      _savingRate = true;
      _rateError = null;
    });

    try {
      await ref
          .read(settingsProvider(widget.uid).notifier)
          .save(widget.setting.copyWith(usdToCdfRate: scaledRate));

      if (!mounted) return;

      _rateController.text = Money(
        amount: scaledRate,
        currency: Currency.usd,
      ).format();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exchange rate saved successfully.')),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _rateError = 'Could not save the exchange rate. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _savingRate = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncRateController();
    });

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Exchange rate',
              subtitle: 'Set the CDF value of one US dollar.',
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _rateController,
              focusNode: _rateFocusNode,
              label: 'CDF per 1 USD',
              helperText: 'Example: 2800.50',
              prefixIcon: Icons.currency_exchange,
              suffixText: 'CDF',
              errorText: _rateError,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              onChanged: (_) {
                if (_rateError != null) {
                  setState(() {
                    _rateError = null;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              text: 'Save exchange rate',
              busy: _savingRate,
              onPressed: _savingRate ? null : _saveExchangeRate,
            ),
          ],
        ),
      ),
    );
  }
}
