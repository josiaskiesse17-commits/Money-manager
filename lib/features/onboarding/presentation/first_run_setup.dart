import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_manager/app/error_reporter.dart';
import 'package:money_manager/data/models/category.dart';
import 'package:money_manager/data/models/setting.dart';
import 'package:money_manager/data/models/wallet.dart';
import 'package:money_manager/data/repositories/category_repository.dart';
import 'package:money_manager/data/repositories/settings_repository.dart';
import 'package:money_manager/data/repositories/wallet_repository.dart';

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

      // Write settings + wallets (fire-and-forget, offline-safe)
      unawaited(
        ref.read(settingsRepositoryProvider).saveSettings(uid, setting),
      );
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

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      reportError(e, userMessage: 'Setup failed');
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = 'current_user'; // TODO: replace with actual uid from auth
    return Scaffold(
      appBar: AppBar(title: const Text('First-run setup')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text('Exchange rate (CDF per 1 USD, e.g. 2800.50):'),
              TextFormField(
                controller: _rateCtrl,
                decoration: const InputDecoration(labelText: 'Rate'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Rate required' : null,
              ),
              const SizedBox(height: 16),
              const Text('Opening balance CDF (whole francs):'),
              TextFormField(
                controller: _cdfCtrl,
                decoration: const InputDecoration(labelText: 'CDF'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              const Text('Opening balance USD (e.g. 100.00):'),
              TextFormField(
                controller: _usdCtrl,
                decoration: const InputDecoration(labelText: 'USD'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : () => _save(uid),
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
