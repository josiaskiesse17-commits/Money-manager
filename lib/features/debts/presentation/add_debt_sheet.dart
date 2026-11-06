import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:money_manager/app/error_reporter.dart';
import 'package:money_manager/app/widgets/amount_keypad.dart';
import 'package:money_manager/app/widgets/app_text_field.dart';
import 'package:money_manager/app/widgets/error_banner.dart';
import 'package:money_manager/app/widgets/primary_button.dart';
import 'package:money_manager/data/models/debt.dart';
import 'package:money_manager/features/auth/application/auth_provider.dart';
import 'package:money_manager/features/debts/application/debt_provider.dart';

/// Sheet (dialog on wide screens) to add a new debt.
class AddDebtSheet extends ConsumerStatefulWidget {
  const AddDebtSheet({super.key});

  @override
  ConsumerState<AddDebtSheet> createState() => _AddDebtSheetState();
}

class _AddDebtSheetState extends ConsumerState<AddDebtSheet> {
  final _nameCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _direction = 'owe'; // owe | owed
  String _currency = 'CDF'; // CDF | USD
  int _amount = 0; // minor units
  DateTime? _dueDate;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  /// Explains the wallet effect of creating this debt.
  String get _walletEffect {
    final verb = _direction == 'owe' ? 'increase' : 'decrease';
    return 'Your $_currency wallet will $verb by ${_formatMinor(_amount)}.';
  }

  String _formatMinor(int amount) {
    switch (_currency) {
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

  bool get _canSave {
    return _nameCtrl.text.trim().isNotEmpty && _amount > 0;
  }

  Future<void> _save() async {
    final uid = ref.read(authProvider)?.uid ?? '';
    if (uid.isEmpty) {
      setState(() {
        _error = 'Please sign in to add a debt.';
        _busy = false;
      });
      return;
    }

    setState(() {
      _error = null;
      _busy = true;
    });

    try {
      final debt = Debt(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameCtrl.text.trim(),
        direction: _direction,
        currency: _currency,
        principal: _amount,
        remaining: _amount,
        dueDate: _dueDate,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        archived: false,
        createdAt: DateTime.now(),
      );

      await ref.read(debtProvider(uid).notifier).addDebt(debt);
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
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isPhone = width < 600;

    final child = SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add debt',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Record money you borrowed (you owe) or lent (you are owed).',
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
              controller: _nameCtrl,
              label: 'Name',
              hint: 'e.g. Phone loan',
              maxLines: 1,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DirectionChoice(
                    value: _direction,
                    selected: _direction == 'owe',
                    label: 'I owe',
                    icon: Icons.payment_rounded,
                    onChanged: (selected) =>
                        setState(() => _direction = selected ? 'owe' : 'owed'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DirectionChoice(
                    value: _direction,
                    selected: _direction == 'owed',
                    label: 'Owed to me',
                    icon: Icons.account_balance_wallet_rounded,
                    onChanged: (selected) =>
                        setState(() => _direction = selected ? 'owed' : 'owe'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _CurrencyChoice(
                    value: _currency,
                    selected: _currency == 'CDF',
                    label: 'CDF',
                    onChanged: (selected) =>
                        setState(() => _currency = selected ? 'CDF' : 'USD'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CurrencyChoice(
                    value: _currency,
                    selected: _currency == 'USD',
                    label: 'USD',
                    onChanged: (selected) =>
                        setState(() => _currency = selected ? 'USD' : 'CDF'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AmountKeypad(
              currency: _currency,
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
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      _dueDate == null
                          ? 'Due date (optional)'
                          : DateFormat('MMM d, yyyy').format(_dueDate!),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _noteCtrl,
              label: 'Note (optional)',
              hint: 'e.g. Paid monthly',
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
                    text: 'Save debt',
                    busy: _busy,
                    onPressed: _canSave && !_busy ? _save : null,
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

class _DirectionChoice extends StatelessWidget {
  const _DirectionChoice({
    required this.value,
    required this.selected,
    required this.label,
    required this.icon,
    required this.onChanged,
  });

  final String value;
  final bool selected;
  final String label;
  final IconData icon;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      onSelected: onChanged,
      avatar: Icon(icon, size: 18),
      label: Text(label),
      labelStyle: TextStyle(
        color: selected
            ? Theme.of(context).colorScheme.onPrimary
            : Theme.of(context).colorScheme.onSurface,
      ),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      checkmarkColor: Theme.of(context).colorScheme.onPrimary,
    );
  }
}

class _CurrencyChoice extends StatelessWidget {
  const _CurrencyChoice({
    required this.value,
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  final String value;
  final bool selected;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      onSelected: onChanged,
      avatar: Icon(
        label == 'CDF' ? Icons.attach_money : Icons.monetization_on,
        size: 18,
      ),
      label: Text(label),
      labelStyle: TextStyle(
        color: selected
            ? Theme.of(context).colorScheme.onPrimary
            : Theme.of(context).colorScheme.onSurface,
      ),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      checkmarkColor: Theme.of(context).colorScheme.onPrimary,
    );
  }
}
