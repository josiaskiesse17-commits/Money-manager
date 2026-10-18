import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_manager/app/error_reporter.dart';
import 'package:money_manager/app/widgets/app_text_field.dart';
import 'package:money_manager/app/widgets/auth_layout.dart';
import 'package:money_manager/app/widgets/primary_button.dart';
import 'package:money_manager/data/models/category.dart';
import 'package:money_manager/data/models/setting.dart';
import 'package:money_manager/data/models/wallet.dart';
import 'package:money_manager/data/repositories/category_repository.dart';
import 'package:money_manager/data/repositories/wallet_repository.dart';
import 'package:money_manager/features/auth/application/auth_provider.dart';
import 'package:money_manager/features/settings/application/settings_provider.dart';

/// First-run setup: exchange rate (required), opening balances for CDF and USD.
/// Seeds default categories. Writes are fire-and-forget (offline-safe).
class FirstRunSetup extends ConsumerStatefulWidget {
  const FirstRunSetup({super.key});

  @override
  ConsumerState<FirstRunSetup> createState() => _FirstRunSetupState();
}

class _FirstRunSetupState extends ConsumerState<FirstRunSetup> {
  final _rateCtrl = TextEditingController();
  final _cdfCtrl = TextEditingController();
  final _usdCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void dispose() {
    _rateCtrl.dispose();
    _cdfCtrl.dispose();
    _usdCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(String uid) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final rate =
          int.parse(_rateCtrl.text.replaceAll(',', '').replaceAll('.', '')) *
          100;
      final cdfBalance = int.tryParse(_cdfCtrl.text.replaceAll(',', '')) ?? 0;
      final usdBalance = int.tryParse(_usdCtrl.text.replaceAll(',', '')) ?? 0;

      final setting = Setting(
        docId: 'main',
        usdToCdfRate: rate,
        theme: 'system',
        displayMode: 'combined',
        onboarded: true,
      );

      // Write settings via provider notifier so AuthGate rebuilds
      // and transitions to Home once onboarded is true.
      final user = ref.read(authProvider);
      final uid = user?.uid ?? 'current_user';
      await ref.read(settingsProvider(uid).notifier).save(setting);
      unawaited(
        ref
            .read(walletRepositoryProvider)
            .walletDoc(uid, 'CDF')
            .set(
              Wallet(
                currency: 'CDF',
                openingBalance: cdfBalance,
                balance: cdfBalance,
              ).toMap(),
              SetOptions(merge: true),
            ),
      );
      unawaited(
        ref
            .read(walletRepositoryProvider)
            .walletDoc(uid, 'USD')
            .set(
              Wallet(
                currency: 'USD',
                openingBalance: usdBalance,
                balance: usdBalance,
              ).toMap(),
              SetOptions(merge: true),
            ),
      );

      // Seed default categories (fixed ids, safe to seed twice)
      final expenseCategories = [
        Category(
          id: 'cat_food',
          name: 'Food',
          icon: 'restaurant',
          color: 0xFFFF5722,
          type: 'expense',
          archived: false,
        ),
        Category(
          id: 'cat_transport',
          name: 'Transport',
          icon: 'directions',
          color: 0xFF2196F3,
          type: 'expense',
          archived: false,
        ),
        Category(
          id: 'cat_rent',
          name: 'Rent',
          icon: 'home',
          color: 0xFF9C27B0,
          type: 'expense',
          archived: false,
        ),
        Category(
          id: 'cat_airtime',
          name: 'Airtime & Internet',
          icon: 'sim_card',
          color: 0xFF00BCD4,
          type: 'expense',
          archived: false,
        ),
        Category(
          id: 'cat_utilities',
          name: 'Utilities',
          icon: 'lightbulb',
          color: 0xFFFF9800,
          type: 'expense',
          archived: false,
        ),
        Category(
          id: 'cat_health',
          name: 'Health',
          icon: 'local_hospital',
          color: 0xFFE91E63,
          type: 'expense',
          archived: false,
        ),
        Category(
          id: 'cat_education',
          name: 'Education',
          icon: 'school',
          color: 0xFF673AB7,
          type: 'expense',
          archived: false,
        ),
        Category(
          id: 'cat_shopping',
          name: 'Shopping',
          icon: 'shopping_cart',
          color: 0xFF795548,
          type: 'expense',
          archived: false,
        ),
        Category(
          id: 'cat_family',
          name: 'Family',
          icon: 'people',
          color: 0xFF607D8B,
          type: 'expense',
          archived: false,
        ),
        Category(
          id: 'cat_other',
          name: 'Other',
          icon: 'more_horiz',
          color: 0xFF9E9E9E,
          type: 'expense',
          archived: false,
        ),
      ];
      final incomeCategories = [
        Category(
          id: 'cat_salary',
          name: 'Salary',
          icon: 'work',
          color: 0xFF4CAF50,
          type: 'income',
          archived: false,
        ),
        Category(
          id: 'cat_business',
          name: 'Business',
          icon: 'business',
          color: 0xFF009688,
          type: 'income',
          archived: false,
        ),
        Category(
          id: 'cat_gift',
          name: 'Gift',
          icon: 'card_giftcard',
          color: 0xFFF44336,
          type: 'income',
          archived: false,
        ),
        Category(
          id: 'cat_other_income',
          name: 'Other',
          icon: 'more_horiz',
          color: 0xFF9E9E9E,
          type: 'income',
          archived: false,
        ),
      ];

      final catRepo = ref.read(categoryRepositoryProvider);
      for (final c in [...expenseCategories, ...incomeCategories]) {
        unawaited(catRepo.saveCategory(uid, c));
      }

      // Settings stream emits once Firestore syncs; AuthGate rebuilds
      // and shows Home inside AppShell. No Navigator.pop() needed.
      setState(() => _saving = false);
    } catch (e) {
      reportError(e, userMessage: 'Setup failed');
      setState(() => _saving = false);
    }
  }

  String? _validateRate(String? v) {
    if (v == null || v.isEmpty) return 'Rate required';
    try {
      final cleaned = v.replaceAll(',', '').replaceAll('.', '');
      if (int.tryParse(cleaned) == null) return 'Enter a valid rate';
      return null;
    } catch (_) {
      return 'Enter a valid rate';
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = 'current_user'; // TODO: replace with actual uid from auth

    return AuthLayout(
      title: 'Set up your wallets',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: _rateCtrl,
              label: "Today's rate (1 USD = ? CDF)",
              helperText: 'e.g. 2800.50',
              validator: _validateRate,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _cdfCtrl,
              label: 'Money you have in CDF',
              helperText: 'Whole francs',
              keyboardType: TextInputType.number,
              validator: (v) => v == null || v.isEmpty ? 'Enter amount' : null,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _usdCtrl,
              label: 'Money you have in USD',
              helperText: 'e.g. 100.00',
              keyboardType: TextInputType.number,
              validator: (v) => v == null || v.isEmpty ? 'Enter amount' : null,
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              text: 'Start tracking',
              busy: _saving,
              onPressed: _saving ? null : () => _save(uid),
            ),
          ],
        ),
      ),
    );
  }
}
