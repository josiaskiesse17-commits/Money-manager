import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_manager/app/error_reporter.dart';
import 'package:money_manager/app/widgets/app_text_field.dart';
import 'package:money_manager/app/widgets/auth_layout.dart';
import 'package:money_manager/app/widgets/error_banner.dart';
import 'package:money_manager/app/widgets/primary_button.dart';
import 'package:money_manager/core/money/currency.dart';
import 'package:money_manager/core/money/money.dart';
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
  String? _error;

  @override
  void dispose() {
    _rateCtrl.dispose();
    _cdfCtrl.dispose();
    _usdCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    _error = null;

    final user = ref.read(authProvider);
    if (user == null) {
      setState(() {
        _error = 'Not signed in. Please sign in again.';
        _saving = false;
      });
      return;
    }
    final uid = user.uid;

    try {
      final rate = ExchangeRate.parse(_rateCtrl.text).rateScaled;
      final cdfBalance = Money.parse(_cdfCtrl.text, Currency.cdf).amount;
      final usdBalance = Money.parse(_usdCtrl.text, Currency.usd).amount;

      final setting = Setting(
        docId: 'main',
        usdToCdfRate: rate,
        theme: 'system',
        displayMode: 'combined',
        onboarded: true,
      );

      // Write settings via provider notifier — fire-and-forget (offline-safe).
      // AuthGate watches settingsProvider stream and transitions to Home
      // once the doc syncs and onboarded is true.
      unawaited(ref.read(settingsProvider(uid).notifier).save(setting));

      // Write wallets — fire-and-forget.
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

      // Seed default categories (fixed ids, safe to seed twice).
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

      // Don't await Firestore writes. AuthGate rebuilds when settings stream
      // emits the saved doc with onboarded=true.
      setState(() => _saving = false);
    } catch (e) {
      reportError(e, userMessage: 'Setup failed');
      setState(() => _saving = false);
    }
  }

  String? _validateRate(String? v) {
    if (v == null || v.isEmpty) return 'Rate required';
    try {
      ExchangeRate.parse(v);
      return null;
    } on FormatException {
      return 'Enter a valid rate';
    }
  }

  String? _validateBalance(String? v, Currency currency) {
    if (v == null || v.trim().isEmpty) return 'Enter amount';
    try {
      Money.parse(v.trim(), currency);
      return null;
    } on FormatException {
      return currency == Currency.cdf
          ? 'Enter a valid whole-number CDF amount'
          : 'Enter a valid USD amount';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Set up your wallets',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[ErrorBanner(message: _error!)],
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
              validator: (v) => _validateBalance(v, Currency.cdf),
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _usdCtrl,
              label: 'Money you have in USD',
              helperText: 'e.g. 100.00',
              keyboardType: TextInputType.number,
              validator: (v) => _validateBalance(v, Currency.usd),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              text: 'Start tracking',
              busy: _saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
