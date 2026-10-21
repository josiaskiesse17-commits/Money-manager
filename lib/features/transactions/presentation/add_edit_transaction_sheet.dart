import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:money_manager/app/widgets/amount_keypad.dart';
import 'package:money_manager/app/widgets/app_text_field.dart';
import 'package:money_manager/app/widgets/category_chips.dart';
import 'package:money_manager/app/widgets/error_banner.dart';
import 'package:money_manager/app/widgets/primary_button.dart';
import 'package:money_manager/app/widgets/secondary_button.dart';
import 'package:money_manager/app/widgets/section_header.dart';
import 'package:money_manager/data/models/transaction.dart';
import 'package:money_manager/features/auth/application/auth_provider.dart';
import 'package:money_manager/features/categories/application/category_provider.dart';
import 'package:money_manager/features/settings/application/settings_provider.dart';
import 'package:money_manager/features/transactions/application/transaction_provider.dart';

class AddEditTransactionSheet extends ConsumerStatefulWidget {
  final Transaction? transaction;

  const AddEditTransactionSheet({super.key, this.transaction});

  @override
  ConsumerState<AddEditTransactionSheet> createState() =>
      _AddEditTransactionSheetState();
}

class _AddEditTransactionSheetState
    extends ConsumerState<AddEditTransactionSheet> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late String _type;
  late String _currency;
  late String? _categoryId;
  late DateTime _date;

  int _keypadAmount = 0;
  bool _isDeleting = false;
  bool _isSaving = false;

  bool get _isEdit => widget.transaction != null;

  @override
  void initState() {
    super.initState();

    final existing = widget.transaction;

    _type = existing?.type ?? 'expense';
    _currency = existing?.currency ?? 'USD';
    _categoryId = existing?.categoryId;
    _date = existing?.date ?? DateTime.now();

    if (existing != null) {
      _keypadAmount = existing.amount;
      _amountCtrl.text = _formatAmount(existing.amount, _currency);
      _noteCtrl.text = existing.note ?? '';
    }

    _dateCtrl.text = DateFormat('MMM d, yyyy').format(_date);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  String _formatAmount(int amount, String currency) {
    return currency == 'USD'
        ? (amount / 100).toStringAsFixed(2)
        : amount.toString();
  }

  void _changeCurrency(String currency) {
    if (_currency == currency) return;

    setState(() {
      _currency = currency;
      _keypadAmount = 0;
      _amountCtrl.clear();
    });
  }

  void _handleKeypadAmount(int amount) {
    _keypadAmount = amount;

    final display = _formatAmount(amount, _currency);

    if (_amountCtrl.text != display) {
      _amountCtrl.value = TextEditingValue(
        text: display,
        selection: TextSelection.collapsed(offset: display.length),
      );
    }
  }

  String? _validateAmount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter amount';
    }

    final normalized = value.trim().replaceAll(',', '');

    if (_currency == 'CDF') {
      if (int.tryParse(normalized) == null) {
        return 'Invalid amount';
      }
    } else {
      final parsed = double.tryParse(normalized);

      if (parsed == null || !parsed.isFinite || parsed < 0) {
        return 'Invalid amount';
      }

      final parts = normalized.split('.');

      if (parts.length > 2) {
        return 'Invalid amount';
      }

      if (parts.length == 2 && parts[1].length > 2) {
        return 'Max 2 decimals';
      }
    }

    return null;
  }

  int _parseAmount() {
    final normalized = _amountCtrl.text.trim().replaceAll(',', '');

    if (_currency == 'CDF') {
      return int.parse(normalized);
    }

    final parts = normalized.split('.');
    final wholePart = parts[0].isEmpty ? '0' : parts[0];
    final fractionalPart = parts.length > 1 ? parts[1] : '';
    final centsPart = fractionalPart.padRight(2, '0');

    return int.parse(wholePart) * 100 +
        (centsPart.isEmpty ? 0 : int.parse(centsPart));
  }

  Future<void> _save(WidgetRef ref, String uid) async {
    if (_isSaving) return;

    if (!_formKey.currentState!.validate()) return;

    if (_categoryId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select a category')));
      return;
    }

    late final int amount;
    late final int rateAtEntry;

    try {
      amount = _parseAmount();

      rateAtEntry = _isEdit
          ? widget.transaction!.rateAtEntry
          : _rateAtEntryFromSettings(ref, uid);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
      return;
    }

    final now = DateTime.now();

    final txn = Transaction(
      id: widget.transaction?.id ?? now.millisecondsSinceEpoch.toString(),
      amount: amount,
      currency: _currency,
      type: _type,
      categoryId: _categoryId!,
      date: _date,
      note: _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
      rateAtEntry: rateAtEntry,
      createdAt: widget.transaction?.createdAt ?? now,
      updatedAt: now,
    );

    setState(() => _isSaving = true);

    try {
      if (_isEdit) {
        await ref
            .read(transactionProvider(uid).notifier)
            .update(widget.transaction!, txn);
      } else {
        await ref.read(transactionProvider(uid).notifier).add(txn);
      }

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);

        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    }
  }

  int _rateAtEntryFromSettings(WidgetRef ref, String uid) {
    final settingsAsync = ref.read(settingsProvider(uid));

    if (settingsAsync is AsyncLoading) {
      throw Exception('Settings are still loading. Please try again.');
    }

    if (settingsAsync is AsyncError) {
      throw Exception('Failed to load exchange rate settings.');
    }

    final setting = settingsAsync.value;

    if (setting == null) {
      throw Exception('Settings not configured. Complete first-run setup.');
    }

    return setting.usdToCdfRate;
  }

  Future<void> _delete(WidgetRef ref, String uid) async {
    if (_isDeleting) return;

    setState(() => _isDeleting = true);

    try {
      await ref
          .read(transactionProvider(uid).notifier)
          .delete(widget.transaction!);

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);

        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authProvider)?.uid ?? '';
    final categoriesAsync = ref.watch(categoryProvider(uid));
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;

    final isCompact = screenWidth < 400;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _isEdit ? Icons.edit_note_rounded : Icons.add_card_rounded,
                color: colors.onPrimaryContainer,
                size: 23,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isEdit ? 'Edit transaction' : 'Add transaction',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isEdit
                        ? 'Update your transaction details'
                        : 'Record your money movement',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              tooltip: 'Close',
              onPressed: () => context.pop(),
              style: IconButton.styleFrom(
                backgroundColor: colors.surfaceContainerLow,
              ),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ],
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(
          child: ErrorBanner(message: 'Failed to load categories'),
        ),
        data: (categories) {
          return Form(
            key: _formKey,
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      isCompact ? 16 : 20,
                      12,
                      isCompact ? 16 : 20,
                      28,
                    ),
                    children: [
                      _buildSectionLabel(context, 'TRANSACTION TYPE'),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: _SelectionCard(
                              title: 'Expense',
                              subtitle: 'Money going out',
                              icon: Icons.arrow_upward_rounded,
                              selected: _type == 'expense',
                              accentColor: colors.error,
                              onTap: () {
                                if (_type != 'expense') {
                                  setState(() => _type = 'expense');
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SelectionCard(
                              title: 'Income',
                              subtitle: 'Money coming in',
                              icon: Icons.arrow_downward_rounded,
                              selected: _type == 'income',
                              accentColor: colors.primary,
                              onTap: () {
                                if (_type != 'income') {
                                  setState(() => _type = 'income');
                                }
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      _buildSectionLabel(context, 'PAYMENT CURRENCY'),
                      const SizedBox(height: 10),

                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colors.outlineVariant.withValues(
                              alpha: 0.55,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _CurrencyOption(
                                currency: 'CDF',
                                description: 'Congolese franc',
                                selected: _currency == 'CDF',
                                onTap: () => _changeCurrency('CDF'),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: _CurrencyOption(
                                currency: 'USD',
                                description: 'US dollar',
                                selected: _currency == 'USD',
                                onTap: () => _changeCurrency('USD'),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      Row(
                        children: [
                          Expanded(
                            child: _buildSectionLabel(context, 'AMOUNT'),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primaryContainer.withValues(
                                alpha: 0.6,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _currency,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colors.onPrimaryContainer,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      Container(
                        padding: EdgeInsets.all(isCompact ? 12 : 16),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: colors.outlineVariant.withValues(
                              alpha: 0.65,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppTextField(
                              controller: _amountCtrl,
                              label: _currency == 'USD'
                                  ? 'Amount in US dollars'
                                  : 'Amount in Congolese francs',
                              helperText: _currency == 'USD'
                                  ? 'Enter an amount with up to 2 decimals'
                                  : 'Enter a whole number',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              validator: _validateAmount,
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              height: 420,
                              child: AmountKeypad(
                                key: ValueKey(_currency),
                                currency: _currency,
                                initialAmount: _keypadAmount,
                                onAmountChanged: _handleKeypadAmount,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 26),

                      _buildSectionLabel(context, 'CATEGORY'),
                      const SizedBox(height: 10),

                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(isCompact ? 12 : 16),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: colors.outlineVariant.withValues(
                              alpha: 0.55,
                            ),
                          ),
                        ),
                        child: CategoryChips(
                          categories: categories,
                          selectedType: _type,
                          selectedId: _categoryId,
                          onSelected: (id) {
                            setState(() => _categoryId = id);
                          },
                        ),
                      ),

                      const SizedBox(height: 26),

                      _buildSectionLabel(context, 'MORE DETAILS'),
                      const SizedBox(height: 10),

                      Container(
                        padding: EdgeInsets.all(isCompact ? 12 : 16),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: colors.outlineVariant.withValues(
                              alpha: 0.55,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: colors.primaryContainer.withValues(
                                      alpha: 0.65,
                                    ),
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: Icon(
                                    Icons.calendar_month_rounded,
                                    color: colors.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Transaction date',
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Choose when it happened',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: colors.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            AppTextField(
                              controller: _dateCtrl,
                              label: 'Date',
                              readOnly: true,
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _date,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );

                                if (picked != null && mounted) {
                                  setState(() {
                                    _date = picked;
                                    _dateCtrl.text = DateFormat('MMM d, yyyy')
                                        .format(_date);
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: colors.primaryContainer.withValues(
                                      alpha: 0.65,
                                    ),
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: Icon(
                                    Icons.notes_rounded,
                                    color: colors.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Note',
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Add a description (optional)',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: colors.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            AppTextField(
                              controller: _noteCtrl,
                              label: 'Transaction note',
                              helperText: 'Maximum 200 characters',
                              maxLength: 200,
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Fixed action bar stays accessible while the form scrolls.
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(
                    isCompact ? 16 : 20,
                    12,
                    isCompact ? 16 : 20,
                    12 + MediaQuery.paddingOf(context).bottom,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    border: Border(
                      top: BorderSide(
                        color: colors.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.shadow.withValues(alpha: 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      if (_isEdit) ...[
                        Expanded(
                          flex: 2,
                          child: OutlinedButton.icon(
                            onPressed: _isDeleting || _isSaving
                                ? null
                                : () => _delete(ref, uid),
                            icon: _isDeleting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.delete_outline_rounded),
                            label: Text(_isDeleting ? 'Deleting…' : 'Delete'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 50),
                              foregroundColor: colors.error,
                              side: BorderSide(
                                color: colors.error.withValues(alpha: 0.45),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        flex: 3,
                        child: SizedBox(
                          height: 50,
                          child: PrimaryButton(
                            text: _isSaving
                                ? 'Saving…'
                                : _isEdit
                                ? 'Save changes'
                                : 'Add transaction',
                            onPressed: _isSaving || _isDeleting
                                ? null
                                : () => _save(ref, uid),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String title) {
    final theme = Theme.of(context);

    return Text(
      title,
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.0,
      ),
    );
  }
}

class _SelectionCard extends StatelessWidget {
  const _SelectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: selected
          ? accentColor.withValues(alpha: 0.08)
          : colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? accentColor.withValues(alpha: 0.75)
                  : colors.outlineVariant.withValues(alpha: 0.55),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: accentColor, size: 21),
                  ),
                  const Spacer(),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: selected ? accentColor : colors.outlineVariant,
                    size: 21,
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrencyOption extends StatelessWidget {
  const _CurrencyOption({
    required this.currency,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final String currency;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: selected ? colors.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? colors.primary.withValues(alpha: 0.55)
                  : Colors.transparent,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: colors.shadow.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: selected
                      ? colors.primaryContainer
                      : colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(
                  child: Text(
                    currency == 'CDF' ? 'FC' : '\$',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? colors.onPrimaryContainer
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currency,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: selected ? colors.primary : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
