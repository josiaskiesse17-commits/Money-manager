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

/// Add/Edit transaction modal bottom sheet.
///
/// Fields: expense/income, wallet (CDF/USD), amount keypad,
/// category chips (filtered by type), date, note (max 200).
/// Edit mode shows a delete button.
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
  final _formKey = GlobalKey<FormState>();
  late String _type; // 'income' | 'expense'
  late String _currency; // 'CDF' | 'USD'
  late String? _categoryId;
  late DateTime _date;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.transaction;
    _type = existing?.type ?? 'expense';
    _currency = existing?.currency ?? 'USD';
    _categoryId = existing?.categoryId;
    _date = existing?.date ?? DateTime.now();
    if (existing != null) {
      final isUSD = _currency == 'USD';
      final display = isUSD
          ? (existing.amount / 100).toStringAsFixed(2)
          : existing.amount.toString();
      _amountCtrl.text = display;
      _noteCtrl.text = existing.note ?? '';
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  String? _validateAmount(String? v) {
    if (v == null || v.isEmpty) return 'Enter amount';
    try {
      if (_currency == 'CDF') {
        final cleaned = v.replaceAll(',', '').replaceAll('.', '');
        if (int.tryParse(cleaned) == null) return 'Invalid amount';
      } else {
        final parts = v.replaceAll(',', '').split('.');
        if (parts.length > 2) return 'Invalid amount';
        if (parts.length == 2 && parts[1].length > 2) {
          return 'Max 2 decimals';
        }
        int.tryParse(parts.join(''));
        if (parts.join('').isEmpty) return 'Invalid amount';
      }
      return null;
    } catch (_) {
      return 'Invalid amount';
    }
  }

  Future<void> _save(WidgetRef ref, String uid) async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select a category')));
      return;
    }

    final isUSD = _currency == 'USD';
    final cleaned = _amountCtrl.text.replaceAll(',', '').replaceAll('.', '');
    int amount;
    if (isUSD) {
      final parts = cleaned.split('.');
      final combined = parts.join('');
      amount = int.parse(combined);
      // If only 1 decimal digit, multiply by 10
      if (parts.length == 2 && parts[1].length == 1) {
        amount = amount * 10;
      }
    } else {
      amount = int.parse(cleaned);
    }

    final txn = Transaction(
      id:
          widget.transaction?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      amount: amount,
      currency: _currency,
      type: _type,
      categoryId: _categoryId!,
      date: _date,
      note: _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
      rateAtEntry: widget.transaction != null
          ? widget.transaction!.rateAtEntry
          : _rateAtEntryFromSettings(ref, uid),
      createdAt: widget.transaction?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      if (widget.transaction == null) {
        await ref.read(transactionProvider(uid).notifier).add(txn);
      } else {
        await ref
            .read(transactionProvider(uid).notifier)
            .update(widget.transaction!, txn);
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
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
    setState(() => _isDeleting = true);
    try {
      await ref
          .read(transactionProvider(uid).notifier)
          .delete(widget.transaction!);
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _isDeleting = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final uid = user?.uid ?? '';
    final categoriesAsync = ref.watch(categoryProvider(uid));
    final isEdit = widget.transaction != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit transaction' : 'Add transaction'),
        leading: SecondaryButton(
          text: 'Cancel',
          onPressed: () => context.pop(),
        ),
      ),
      body: categoriesAsync.when(
        data: (categories) => Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                // Type toggle
                const SectionHeader(title: 'Type'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilterChip(
                        label: const Text('Expense'),
                        selected: _type == 'expense',
                        onSelected: (_) => setState(() => _type = 'expense'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilterChip(
                        label: const Text('Income'),
                        selected: _type == 'income',
                        onSelected: (_) => setState(() => _type = 'income'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Wallet
                const SectionHeader(title: 'Wallet'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilterChip(
                        label: const Text('CDF'),
                        selected: _currency == 'CDF',
                        onSelected: (_) {
                          setState(() => _currency = 'CDF');
                          _amountCtrl.clear();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilterChip(
                        label: const Text('USD'),
                        selected: _currency == 'USD',
                        onSelected: (_) {
                          setState(() => _currency = 'USD');
                          _amountCtrl.clear();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Amount
                const SectionHeader(title: 'Amount'),
                const SizedBox(height: 8),
                AppTextField(
                  controller: _amountCtrl,
                  label: _currency == 'USD' ? 'Amount (USD)' : 'Amount (CDF)',
                  helperText: _currency == 'USD'
                      ? 'Max 2 decimals'
                      : 'Whole francs',
                  keyboardType: TextInputType.number,
                  validator: _validateAmount,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 300,
                  child: AmountKeypad(
                    currency: _currency,
                    initialAmount: widget.transaction?.amount ?? 0,
                    onAmountChanged: (amount) {
                      final isUSD = _currency == 'USD';
                      final display = isUSD
                          ? (amount / 100).toStringAsFixed(2)
                          : amount.toString();
                      _amountCtrl.text = display;
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Category
                const SectionHeader(title: 'Category'),
                const SizedBox(height: 8),
                CategoryChips(
                  categories: categories,
                  selectedType: _type,
                  selectedId: _categoryId,
                  onSelected: (id) => setState(() => _categoryId = id),
                ),
                const SizedBox(height: 24),

                // Date
                const SectionHeader(title: 'Date'),
                const SizedBox(height: 8),
                AppTextField(
                  controller: TextEditingController(
                    text: DateFormat('MMM d, yyyy').format(_date),
                  ),
                  label: 'Date',
                  readOnly: true,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                ),
                const SizedBox(height: 24),

                // Note
                const SectionHeader(title: 'Note'),
                const SizedBox(height: 8),
                AppTextField(
                  controller: _noteCtrl,
                  label: 'Note',
                  helperText: 'Max 200 characters',
                  maxLength: 200,
                  maxLines: 2,
                ),
                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    if (isEdit) ...[
                      Expanded(
                        child: SecondaryButton(
                          text: 'Delete',
                          onPressed: _isDeleting
                              ? null
                              : () => _delete(ref, uid),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: PrimaryButton(
                        text: isEdit ? 'Save changes' : 'Add transaction',
                        onPressed: () => _save(ref, uid),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            Center(child: ErrorBanner(message: 'Failed to load categories')),
      ),
    );
  }
}
