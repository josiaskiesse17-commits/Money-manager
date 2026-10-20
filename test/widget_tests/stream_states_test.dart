import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/app/theme.dart';
import 'package:money_manager/app/widgets/error_banner.dart';
import 'package:money_manager/data/firebase_providers.dart';
import 'package:money_manager/data/models/wallet.dart';
import 'package:money_manager/data/repositories/wallet_repository.dart';
import 'package:money_manager/features/auth/application/auth_provider.dart';
import 'package:money_manager/features/wallets/application/wallet_provider.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';

/// Scripted repository whose [watchWallets] returns a scripted stream,
/// so tests can simulate offline silence (no events) and real errors.
class _ScriptedWalletRepository extends WalletRepository {
  _ScriptedWalletRepository(this._stream) : super(FakeFirebaseFirestore());
  final Stream<List<Wallet>> _stream;
  @override
  Stream<List<Wallet>> watchWallets(String uid) => _stream;
}

/// Minimal widget that mirrors HomeScreen's wallet loading branch.
class _WalletLoadingProbe extends ConsumerWidget {
  const _WalletLoadingProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final uid = user?.uid ?? '';
    final walletsAsync = ref.watch(walletProvider(uid));
    return walletsAsync.when(
      data: (_) => const Text('loaded'),
      loading: () => const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => ErrorBanner(
        message: 'Could not load wallets.',
        fix: 'Check your connection and try again.',
        onRetry: () => ref.refresh(walletProvider(uid)),
      ),
    );
  }
}

/// Stream timeout rules (plan.md): offline must not be an error.
/// - A stream that never emits keeps the loading state (even after the
///   old 10 second window).
/// - A stream that emits an error shows the error state (ErrorBanner +
///   Retry) — only real stream errors (e.g. permission denied) do this.
void main() {
  Future<void> pumpProbeWithWalletStream(
    WidgetTester tester,
    Stream<List<Wallet>> walletStream,
  ) async {
    final mockAuth = MockFirebaseAuth();
    // No sign-in: authProvider.state stays null, uid = '', so
    // walletProvider('') is created exactly once and the broadcast stream
    // is only listened to once — no "already been listened to" errors.

    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          walletRepositoryProvider.overrideWithValue(
            _ScriptedWalletRepository(walletStream),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const _WalletLoadingProbe(),
        ),
      ),
    );
    // pump() instead of pumpAndSettle(): CircularProgressIndicator animates
    // forever, which would keep pumpAndSettle from ever settling.
    await tester.pump(const Duration(milliseconds: 100));
  }

  Stream<List<Wallet>> silentStream() {
    final controller = StreamController<List<Wallet>>.broadcast();
    // Never emit, never close during the test — simulates offline silence.
    addTearDown(() => controller.close());
    return controller.stream;
  }

  testWidgets('a stream that never emits stays in loading, even after 10s', (
    tester,
  ) async {
    await pumpProbeWithWalletStream(tester, silentStream());

    // Loading indicator visible; no error banner.
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.byType(ErrorBanner), findsNothing);

    // Advance fake time well past the old 10 s timeout: still loading,
    // because silence (offline) is not an error.
    await tester.pump(const Duration(seconds: 15));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.byType(ErrorBanner), findsNothing);
  });

  testWidgets('a stream that emits an error shows ErrorBanner with Retry', (
    tester,
  ) async {
    await pumpProbeWithWalletStream(
      tester,
      Stream.error(Exception('Permission denied')),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final banner = find.byType(ErrorBanner);
    expect(banner, findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('provider override is applied', (tester) async {
    final container = ProviderContainer(
      overrides: [
        walletRepositoryProvider.overrideWithValue(
          _ScriptedWalletRepository(Stream.empty()),
        ),
      ],
    );
    final repo = container.read(walletRepositoryProvider);
    expect(repo, isA<_ScriptedWalletRepository>());
    container.dispose();
  });
}
