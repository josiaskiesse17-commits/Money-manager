import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/app/app.dart';
import 'package:money_manager/data/firebase_providers.dart';
import 'package:money_manager/features/auth/presentation/reset_password_screen.dart';
import 'package:money_manager/features/auth/presentation/sign_in_screen.dart';
import 'package:money_manager/features/auth/presentation/sign_up_screen.dart';
import 'package:money_manager/features/auth/presentation/verify_email_screen.dart';
import 'package:money_manager/features/budgets/presentation/budget_dialog.dart';
import 'package:money_manager/features/budgets/presentation/budgets_screen.dart';
import 'package:money_manager/features/charts/presentation/charts_screen.dart';
import 'package:money_manager/features/convert/presentation/convert_screen.dart';
import 'package:money_manager/features/home/presentation/home_screen.dart';
import 'package:money_manager/features/onboarding/presentation/first_run_setup.dart';
import 'package:money_manager/features/reports/presentation/report_screen.dart';
import 'package:money_manager/features/settings/application/app_lock_provider.dart';
import 'package:money_manager/features/settings/presentation/category_dialog.dart';
import 'package:money_manager/features/settings/presentation/pin_setup_screen.dart';
import 'package:money_manager/features/settings/presentation/settings_screen.dart';
import 'package:money_manager/features/transactions/presentation/add_edit_transaction_sheet.dart';
import 'package:money_manager/features/transactions/presentation/transaction_list_screen.dart';

import '../helpers/test_fonts.dart';
import '../helpers/test_theme.dart';

const _uid = 'test_uid';

const _phoneSize = Size(360, 640);
const _smallPhone = Size(360, 568);
const _largePhone = Size(411, 891);
const _webSize = Size(1280, 800);
const _tabletSize = Size(800, 1280);

const _textScales = [1.0, 1.3, 2.0];

class _TestAppLockStorage implements AppLockStorage {
  final Map<String, String> data = {};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async {
    data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    data.remove(key);
  }
}

Future<void> _seedFirestore(FakeFirebaseFirestore firestore) async {
  final user = firestore.collection('users').doc(_uid);
  await user.collection('settings').doc('main').set({
    'usdToCdfRate': 280050,
    'theme': 'light',
    'displayMode': 'combined',
    'onboarded': true,
  });
  await user.collection('wallets').doc('CDF').set({
    'currency': 'CDF',
    'openingBalance': 35000,
    'balance': 42000,
  });
  await user.collection('wallets').doc('USD').set({
    'currency': 'USD',
    'openingBalance': 10000,
    'balance': 15000,
  });
  await user.collection('categories').doc('cat_food').set({
    'name': 'Food',
    'icon': 'restaurant',
    'color': 0xFFFF5722,
    'type': 'expense',
    'archived': false,
  });
  await user.collection('categories').doc('cat_salary').set({
    'name': 'Salary',
    'icon': 'work',
    'color': 0xFF4CAF50,
    'type': 'income',
    'archived': false,
  });
  final now = DateTime.now();
  final thisMonth = DateTime(now.year, now.month, 15);
  await user.collection('transactions').doc('txn_expense').set({
    'amount': 123450,
    'currency': 'USD',
    'type': 'expense',
    'categoryId': 'cat_food',
    'date': Timestamp.fromDate(thisMonth),
    'note': 'Groceries',
    'rateAtEntry': 280050,
    'createdAt': Timestamp.fromDate(thisMonth),
    'updatedAt': Timestamp.fromDate(thisMonth),
  });
  await user.collection('transactions').doc('txn_income').set({
    'amount': 500000,
    'currency': 'USD',
    'type': 'income',
    'categoryId': 'cat_salary',
    'date': Timestamp.fromDate(thisMonth),
    'note': 'Paycheck',
    'rateAtEntry': 280050,
    'createdAt': Timestamp.fromDate(thisMonth),
    'updatedAt': Timestamp.fromDate(thisMonth),
  });
}

List<Override> _signedOutOverrides() {
  return [
    firebaseAuthProvider.overrideWithValue(MockFirebaseAuth()),
    firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
  ];
}

Future<List<Override>> _signedInOverrides() async {
  final firestore = FakeFirebaseFirestore();
  await _seedFirestore(firestore);
  final auth = MockFirebaseAuth(
    signedIn: true,
    mockUser: MockUser(
      uid: _uid,
      email: 'test@example.com',
      isEmailVerified: true,
    ),
  );
  return [
    firebaseAuthProvider.overrideWithValue(auth),
    firestoreProvider.overrideWithValue(firestore),
  ];
}

Future<List<Override>> _unverifiedOverrides() async {
  final firestore = FakeFirebaseFirestore();
  await _seedFirestore(firestore);
  final auth = MockFirebaseAuth(
    signedIn: true,
    mockUser: MockUser(
      uid: _uid,
      email: 'unverified@example.com',
      isEmailVerified: false,
    ),
  );
  return [
    firebaseAuthProvider.overrideWithValue(auth),
    firestoreProvider.overrideWithValue(firestore),
  ];
}

Future<List<Override>> _firstRunOverrides() async {
  final firestore = FakeFirebaseFirestore();
  final auth = MockFirebaseAuth(
    signedIn: true,
    mockUser: MockUser(
      uid: _uid,
      email: 'test@example.com',
      isEmailVerified: true,
    ),
  );
  return [
    firebaseAuthProvider.overrideWithValue(auth),
    firestoreProvider.overrideWithValue(firestore),
  ];
}

Future<List<Override>> _pinSetupOverrides() async {
  final firestore = FakeFirebaseFirestore();
  await _seedFirestore(firestore);
  final auth = MockFirebaseAuth(
    signedIn: true,
    mockUser: MockUser(
      uid: _uid,
      email: 'test@example.com',
      isEmailVerified: true,
    ),
  );
  return [
    firebaseAuthProvider.overrideWithValue(auth),
    firestoreProvider.overrideWithValue(firestore),
    appLockProvider.overrideWith(
      (ref) => AppLockNotifier(
        _TestAppLockStorage(),
        onLockStateChanged: () {
          ref.read(appLockRefreshProvider.notifier).state++;
        },
      ),
    ),
  ];
}

Future<List<Override>> _lockScreenOverrides() async {
  final firestore = FakeFirebaseFirestore();
  await _seedFirestore(firestore);
  final auth = MockFirebaseAuth(
    signedIn: true,
    mockUser: MockUser(
      uid: _uid,
      email: 'test@example.com',
      isEmailVerified: true,
    ),
  );
  final storage = _TestAppLockStorage()
    ..data['app_lock_pin'] = AppLockNotifier.hashPin('1234', 'salt1234')
    ..data['app_lock_salt'] = 'salt1234';
  return [
    firebaseAuthProvider.overrideWithValue(auth),
    firestoreProvider.overrideWithValue(firestore),
    appLockProvider.overrideWith(
      (ref) => AppLockNotifier(
        storage,
        onLockStateChanged: () {
          ref.read(appLockRefreshProvider.notifier).state++;
        },
      ),
    ),
  ];
}

Future<void> _pumpAndCheck(
  WidgetTester tester, {
  required Widget widget,
  required Size size,
  required List<Override> overrides,
  bool useAppTheme = true,
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  bool keyboardOpen = false,
  bool gestureBar = false,
  bool pumpAndSettle = false,
}) async {
  final errors = <String>[];
  final originalDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null &&
        (message.contains('overflowed') ||
            message.contains('No Material widget found') ||
            message.contains('assertion failed') ||
            message.contains('A RenderFlex overflowed'))) {
      final match = RegExp(r'overflowed by ([\d.]+) pixels?')
          .firstMatch(message);
      if (match != null) {
        final pixels = double.parse(match.group(1)!);
        if (pixels < 2) {
          originalDebugPrint(message, wrapWidth: wrapWidth);
          return;
        }
      }
      errors.add(message);
    }
    originalDebugPrint(message, wrapWidth: wrapWidth);
  };

  try {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final baseView = tester.view;
    final baseData = MediaQueryData.fromView(baseView);
    final adjustedData = baseData.copyWith(
      textScaler: TextScaler.linear(textScale),
      viewInsets: keyboardOpen
          ? const EdgeInsets.only(bottom: 300)
          : baseData.viewInsets,
      padding: gestureBar
          ? baseData.padding.copyWith(bottom: 24)
          : baseData.padding,
    );

    await tester.pumpWidget(
      MediaQuery(
        data: adjustedData,
        child: ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            theme: brightness == Brightness.light
                ? (useAppTheme ? testTheme() : ThemeData.light())
                : (useAppTheme
                      ? testTheme(brightness: Brightness.dark)
                      : ThemeData.dark()),
            darkTheme: useAppTheme
                ? testTheme(brightness: Brightness.dark)
                : ThemeData.dark(),
            themeMode: brightness == Brightness.dark
                ? ThemeMode.dark
                : ThemeMode.light,
            home: widget,
          ),
        ),
      ),
    );

    if (pumpAndSettle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
    }
  } finally {
    debugPrint = originalDebugPrint;
  }

  if (errors.isNotEmpty) {
    fail('Flutter errors detected:\n${errors.join('\n')}');
  }

  final exception = tester.takeException();
  if (exception != null) {
    final message = exception.toString();
    final match = RegExp(r'overflowed by ([\d.]+) pixels?').firstMatch(message);
    if (match != null) {
      final pixels = double.parse(match.group(1)!);
      if (pixels >= 2) {
        expect(
          exception,
          isNull,
          reason: 'Widget rendered with exception: $exception',
        );
      }
    } else {
      expect(
        exception,
        isNull,
        reason: 'Widget rendered with exception: $exception',
      );
    }
  }
}

void main() {
  setUpAll(() async {
    await loadTestFonts();
  });

  final phoneSizes = {
    '360x568': _smallPhone,
    '360x640': _phoneSize,
    '411x891': _largePhone,
  };
  final wideSizes = {'1280x800': _webSize, '800x1280': _tabletSize};
  final allSizes = {...phoneSizes, ...wideSizes};

  group('Auth screens (signed out)', () {
    final screens = {
      'SignInScreen': const SignInScreen(),
      'SignUpScreen': const SignUpScreen(),
      'ResetPasswordScreen': const ResetPasswordScreen(),
    };

    for (final screenEntry in screens.entries) {
      for (final sizeEntry in allSizes.entries) {
        testWidgets(
          '${screenEntry.key} renders at ${sizeEntry.key} phone no overflow',
          (tester) async {
            await _pumpAndCheck(
              tester,
              widget: screenEntry.value,
              size: sizeEntry.value,
              overrides: _signedOutOverrides(),
            );
          },
        );
      }
    }

    testWidgets('Auth screens render in dark theme at phone', (tester) async {
      for (final screenEntry in screens.entries) {
        await _pumpAndCheck(
          tester,
          widget: screenEntry.value,
          size: _phoneSize,
          overrides: _signedOutOverrides(),
          brightness: Brightness.dark,
        );
      }
    });

    testWidgets('Auth screens render in dark theme at web', (tester) async {
      for (final screenEntry in screens.entries) {
        await _pumpAndCheck(
          tester,
          widget: screenEntry.value,
          size: _webSize,
          overrides: _signedOutOverrides(),
          brightness: Brightness.dark,
        );
      }
    });

    testWidgets('Auth screens render with keyboard open', (tester) async {
      for (final screenEntry in screens.entries) {
        await _pumpAndCheck(
          tester,
          widget: screenEntry.value,
          size: _phoneSize,
          overrides: _signedOutOverrides(),
          keyboardOpen: true,
        );
      }
    });
  });

  group('VerifyEmailScreen (signed in, unverified)', () {
    for (final sizeEntry in allSizes.entries) {
      testWidgets('renders at ${sizeEntry.key} without overflow', (
        tester,
      ) async {
        await _pumpAndCheck(
          tester,
          widget: const VerifyEmailScreen(),
          size: sizeEntry.value,
          overrides: await _unverifiedOverrides(),
        );
      });
    }

    testWidgets('renders in dark theme', (tester) async {
      await _pumpAndCheck(
        tester,
        widget: const VerifyEmailScreen(),
        size: _phoneSize,
        overrides: await _unverifiedOverrides(),
        brightness: Brightness.dark,
      );
    });
  });

  group('FirstRunSetup (onboarding)', () {
    for (final sizeEntry in allSizes.entries) {
      testWidgets('renders at ${sizeEntry.key} without overflow', (
        tester,
      ) async {
        await _pumpAndCheck(
          tester,
          widget: const FirstRunSetup(),
          size: sizeEntry.value,
          overrides: await _firstRunOverrides(),
        );
      });
    }

    testWidgets('renders in dark theme at phone', (tester) async {
      await _pumpAndCheck(
        tester,
        widget: const FirstRunSetup(),
        size: _phoneSize,
        overrides: await _firstRunOverrides(),
        brightness: Brightness.dark,
      );
    });

    testWidgets('renders with keyboard open at phone', (tester) async {
      await _pumpAndCheck(
        tester,
        widget: const FirstRunSetup(),
        size: _phoneSize,
        overrides: await _firstRunOverrides(),
        keyboardOpen: true,
      );
    });
  });

  group('Signed-in main screens', () {
    final screens = {
      'HomeScreen': const HomeScreen(),
      'TransactionsScreen': const TransactionsScreen(),
      'ConvertScreen': const ConvertScreen(),
      'BudgetsScreen': const BudgetsScreen(),
      'ChartsScreen': const ChartsScreen(),
      'ReportScreen': const ReportScreen(),
      'SettingsScreen': const SettingsScreen(),
    };

    for (final screenEntry in screens.entries) {
      for (final sizeEntry in allSizes.entries) {
        testWidgets(
          '${screenEntry.key} renders at ${sizeEntry.key} light no overflow',
          (tester) async {
            await _pumpAndCheck(
              tester,
              widget: screenEntry.value,
              size: sizeEntry.value,
              overrides: await _signedInOverrides(),
            );
          },
        );
      }
    }
  });

  group('Signed-in screens dark theme', () {
    final screens = {
      'HomeScreen': const HomeScreen(),
      'TransactionsScreen': const TransactionsScreen(),
      'ConvertScreen': const ConvertScreen(),
      'BudgetsScreen': const BudgetsScreen(),
      'ChartsScreen': const ChartsScreen(),
      'ReportScreen': const ReportScreen(),
      'SettingsScreen': const SettingsScreen(),
    };

    for (final screenEntry in screens.entries) {
      for (final sizeEntry in phoneSizes.entries) {
        testWidgets(
          '${screenEntry.key} renders ${sizeEntry.key} dark no overflow',
          (tester) async {
            await _pumpAndCheck(
              tester,
              widget: screenEntry.value,
              size: sizeEntry.value,
              overrides: await _signedInOverrides(),
              brightness: Brightness.dark,
            );
          },
        );
      }
    }
  });

  group('AddEditTransactionSheet', () {
    for (final sizeEntry in allSizes.entries) {
      testWidgets('Add mode renders at ${sizeEntry.key} without overflow', (
        tester,
      ) async {
        await _pumpAndCheck(
          tester,
          widget: const Scaffold(
            body: SafeArea(child: AddEditTransactionSheet()),
          ),
          size: sizeEntry.value,
          overrides: await _signedInOverrides(),
        );
      });
    }

    testWidgets('Add mode renders with keyboard open at phone', (tester) async {
      await _pumpAndCheck(
        tester,
        widget: const Scaffold(
          body: SafeArea(child: AddEditTransactionSheet()),
        ),
        size: _phoneSize,
        overrides: await _signedInOverrides(),
        keyboardOpen: true,
      );
    });

    testWidgets('Add mode renders in dark theme at web', (tester) async {
      await _pumpAndCheck(
        tester,
        widget: const Scaffold(
          body: SafeArea(child: AddEditTransactionSheet()),
        ),
        size: _webSize,
        overrides: await _signedInOverrides(),
        brightness: Brightness.dark,
      );
    });
  });

  group('PinSetupScreen', () {
    for (final sizeEntry in allSizes.entries) {
      testWidgets('renders at ${sizeEntry.key} without overflow', (
        tester,
      ) async {
        await _pumpAndCheck(
          tester,
          widget: const PinSetupScreen(),
          size: sizeEntry.value,
          overrides: await _pinSetupOverrides(),
          pumpAndSettle: true,
        );
      });
    }

    testWidgets('renders in dark theme at phone', (tester) async {
      await _pumpAndCheck(
        tester,
        widget: const PinSetupScreen(),
        size: _phoneSize,
        overrides: await _pinSetupOverrides(),
        brightness: Brightness.dark,
        pumpAndSettle: true,
      );
    });
  });

  group('BudgetDialog', () {
    for (final sizeEntry in allSizes.entries) {
      testWidgets('renders at ${sizeEntry.key} without overflow', (
        tester,
      ) async {
        await _pumpAndCheck(
          tester,
          widget: const Scaffold(body: BudgetDialog()),
          size: sizeEntry.value,
          overrides: await _signedInOverrides(),
        );
      });
    }

    testWidgets('renders in dark theme at phone', (tester) async {
      await _pumpAndCheck(
        tester,
        widget: const Scaffold(body: BudgetDialog()),
        size: _phoneSize,
        overrides: await _signedInOverrides(),
        brightness: Brightness.dark,
      );
    });
  });

  group('CategoryDialog', () {
    for (final sizeEntry in allSizes.entries) {
      testWidgets('renders at ${sizeEntry.key} without overflow', (
        tester,
      ) async {
        await _pumpAndCheck(
          tester,
          widget: const Scaffold(body: CategoryDialog()),
          size: sizeEntry.value,
          overrides: await _signedInOverrides(),
        );
      });
    }

    testWidgets('renders in dark theme at phone', (tester) async {
      await _pumpAndCheck(
        tester,
        widget: const Scaffold(body: CategoryDialog()),
        size: _phoneSize,
        overrides: await _signedInOverrides(),
        brightness: Brightness.dark,
      );
    });
  });

  group('LockScreen via App widget', () {
    testWidgets('Lock screen renders at phone 360x640', (tester) async {
      await _pumpAndCheck(
        tester,
        widget: const App(),
        size: _phoneSize,
        overrides: await _lockScreenOverrides(),
        pumpAndSettle: true,
      );

      expect(find.text('Money Manager'), findsOneWidget);
      expect(find.text('Enter your PIN to continue.'), findsOneWidget);
    });

    testWidgets('Lock screen renders at web 1280x800', (tester) async {
      await _pumpAndCheck(
        tester,
        widget: const App(),
        size: _webSize,
        overrides: await _lockScreenOverrides(),
        pumpAndSettle: true,
      );

      expect(find.text('Money Manager'), findsOneWidget);
      expect(find.text('Enter your PIN to continue.'), findsOneWidget);
    });
  });

  group('Text scale compliance', () {
    final keyScreens = {
      'Home': const HomeScreen(),
      'Transactions': const TransactionsScreen(),
      'Budgets': const BudgetsScreen(),
      'Settings': const SettingsScreen(),
    };

    for (final screenEntry in keyScreens.entries) {
      for (final scale in _textScales) {
        testWidgets('${screenEntry.key} renders at 2.0x textScale at phone', (
          tester,
        ) async {
          await _pumpAndCheck(
            tester,
            widget: screenEntry.value,
            size: _phoneSize,
            overrides: await _signedInOverrides(),
            textScale: scale,
          );
        });
      }
    }
  });

  group('Gesture bar padding', () {
    final screens = {
      'Home': const HomeScreen(),
      'Transactions': const TransactionsScreen(),
      'Budgets': const BudgetsScreen(),
      'Settings': const SettingsScreen(),
    };

    for (final screenEntry in screens.entries) {
      for (final sizeEntry in phoneSizes.entries) {
        testWidgets(
          '${screenEntry.key} renders with gesture bar at ${sizeEntry.key}',
          (tester) async {
            await _pumpAndCheck(
              tester,
              widget: screenEntry.value,
              size: sizeEntry.value,
              overrides: await _signedInOverrides(),
              gestureBar: true,
            );
          },
        );
      }
    }
  });

  group('Keyboard + gesture bar combined', () {
    testWidgets('SignInScreen with keyboard and gesture bar at 360x568', (
      tester,
    ) async {
      await _pumpAndCheck(
        tester,
        widget: const SignInScreen(),
        size: _smallPhone,
        overrides: _signedOutOverrides(),
        keyboardOpen: true,
        gestureBar: true,
        textScale: 1.3,
      );
    });

    testWidgets('SignUpScreen with keyboard and gesture bar at 411x891', (
      tester,
    ) async {
      await _pumpAndCheck(
        tester,
        widget: const SignUpScreen(),
        size: _largePhone,
        overrides: _signedOutOverrides(),
        keyboardOpen: true,
        gestureBar: true,
        textScale: 1.3,
      );
    });

    testWidgets(
      'AddEditTransactionSheet with keyboard and gesture bar at 360x568',
      (tester) async {
        await _pumpAndCheck(
          tester,
          widget: const Scaffold(
            body: SafeArea(child: AddEditTransactionSheet()),
          ),
          size: _smallPhone,
          overrides: await _signedInOverrides(),
          keyboardOpen: true,
          gestureBar: true,
          textScale: 1.3,
        );
      },
    );

    testWidgets('FirstRunSetup with keyboard and gesture bar at 360x568', (
      tester,
    ) async {
      await _pumpAndCheck(
        tester,
        widget: const FirstRunSetup(),
        size: _smallPhone,
        overrides: await _firstRunOverrides(),
        keyboardOpen: true,
        gestureBar: true,
        textScale: 1.3,
      );
    });
  });
}
