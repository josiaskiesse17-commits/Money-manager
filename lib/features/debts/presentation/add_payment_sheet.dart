import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:money_manager/app/error_reporter.dart';
import 'package:money_manager/app/widgets/amount_keypad.dart';
import 'package:money_manager/app/widgets/app_text_field.dart';
import 'package:money_manager/app/widgets/error_banner.dart';
import 'package:money_manager/app/widgets/primary_button.dart';
import 'package:money_manager/data/debt_logic.dart';
import 'package:money_manager/data/models/debt.dart';
import 'package:money_manager/data/models/debt_payment.dart';
import 'package:money_manager/features/auth/application/auth_provider.dart';
import 'package:money_manager/features/debts/application/debt_provider.dart';

/// Sheet (dialog on wide screens) to add a payment to a debt.
class AddPaymentSheet extends ConsumerStatefulWidget {
  const AddPaymentSheet({super.key, required this.debt});

  final Debt debt;

  @override
  ConsumerState<AddPaymentSheet> createState() => _AddPaymentSheetState();
}

class _AddPaymentSheetState extends ConsumerState<AddPaymentSheet> {
  int _amount = 0; // minor units
  DateTime _date = DateTime.now();
  final _noteCtrl = TextEditingController();
  final _remainingCtrl = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _remainingCtrl.text = _formatMinor(
      widget.debt.remaining,
      widget.debt.currency,
    );
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _remainingCtrl.dispose();
    super.dispose();
  }

  /// Explains the wallet effect of recording this payment.
  String get _walletEffect {
    final verb = widget.debt.direction == 'owe' ? 'decrease' : 'increase';
    return 'Your ${widget.debt.currency} wallet will $verb by ${_formatMinor(_amount, widget.debt.currency)}.';
  }

  String _formatMinor(int amount, String currency) {
    switch (currency) {
      case 'USD':
        final dollars = amount ~/ 100;
        final cents = amount % 100;
        return '\$$dollars.${cents.toString().padLeft(2, '0')}';
      case 'CDF':
        return '$amount FC';
      default:
        return '$amount';
    }
  }

  PaymentValidationResult _validate() =>
      validatePayment(widget.debt.remaining, _amount);

  bool get _canSave => _amount > 0;

  Future<void> _save() async {
    final validation = _validate();
    if (!validation.isValid) {
      setState(() => _error = validation.error);
      return;
    }

    final uid = ref.read(authProvider)?.uid ?? '';
    if (uid.isEmpty) {
      setState(() {
        _error = 'Please sign in to add a payment.';
        _busy = false;
      });
      return;
    }

    setState(() {
      _error = null;
      _busy = true;
    });

    try {
      final payment = DebtPayment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        debtId: widget.debt.id,
        amount: _amount,
        currency: widget.debt.currency,
        date: _date,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        createdAt: DateTime.now(),
      );

      await ref
          .read(debtProvider(uid).notifier)
          .addPayment(widget.debt, payment);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _busy = false;
      });
      reportError(e);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isPhone = width < 600;
    final validation = _validate();

    final child = SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add payment',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Record a payment toward "${widget.debt.name}".',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              ErrorBanner(
                message: _error!,
                onRetry: () => setState(() => _error = null),
              ),
              const SizedBox(height: 12),
            ],
            AppTextField(
              controller: _remainingCtrl,
              label: 'Remaining',
              readOnly: true,
            ),
            const SizedBox(height: 12),
            AmountKeypad(
              currency: widget.debt.currency,
              initialAmount: _amount,
              onAmountChanged: (amount) => setState(() => _amount = amount),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _walletEffect,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            if (!validation.isValid) ...[
              const SizedBox(height: 8),
              Text(
                validation.error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(DateFormat('MMM d, yyyy').format(_date)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _noteCtrl,
              label: 'Note (optional)',
              hint: 'e.g. Monthly installment',
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (!isPhone)
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: PrimaryButton(
                    text: 'Save payment',
                    busy: _busy,
                    onPressed: _canSave && validation.isValid && !_busy
                        ? _save
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (isPhone) {
      return child;
    }
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: child,
      ),
    );
  }
}
