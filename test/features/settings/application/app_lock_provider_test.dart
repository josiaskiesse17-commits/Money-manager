import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/features/settings/application/app_lock_provider.dart';

class _TestStorage implements AppLockStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PIN hashing', () {
    test('hashPin produces consistent output for same input', () {
      final salt = AppLockNotifier.generateSalt();
      expect(
        AppLockNotifier.hashPin('1234', salt),
        AppLockNotifier.hashPin('1234', salt),
      );
    });

    test('hashPin produces different output for different PINs', () {
      final salt = AppLockNotifier.generateSalt();
      expect(
        AppLockNotifier.hashPin('1234', salt),
        isNot(AppLockNotifier.hashPin('5678', salt)),
      );
    });

    test('hashPin produces different output for different salts', () {
      expect(
        AppLockNotifier.hashPin('1234', 'salt1'),
        isNot(AppLockNotifier.hashPin('1234', 'salt2')),
      );
    });

    test('generateSalt produces 32-character hex string', () {
      final salt = AppLockNotifier.generateSalt();
      expect(salt.length, 32);
      expect(salt, matches(RegExp(r'^[0-9a-f]{32}$')));
    });
  });

  group('AppLock biometric authentication', () {
    late AppLockNotifier notifier;

    Future<void> lockApp() async {
      notifier.lock();
      expect(notifier.isLocked, true);
    }

    Future<void> unlockWithPin() async {
      final verified = await notifier.unlock('1234');
      expect(verified, true);
      expect(notifier.isLocked, false);
    }

    setUp(() async {
      notifier = AppLockNotifier(
        _TestStorage(),
        biometricAuthenticator: () async => false,
      );
      await notifier.setupPin('1234');
    });

    test('successful biometric authentication unlocks the app', () async {
      await lockApp();

      notifier = AppLockNotifier(
        _TestStorage(),
        biometricAuthenticator: () async => true,
      );
      await notifier.setupPin('1234');

      final ok = await notifier.unlockWithBiometrics();

      expect(ok, true);
      expect(notifier.isLocked, false);
    });

    test('failed biometric authentication leaves app locked', () async {
      await lockApp();

      final ok = await notifier.unlockWithBiometrics();

      expect(ok, false);
      expect(notifier.isLocked, true);
    });

    test('biometric authentication exception leaves app locked', () async {
      await lockApp();

      notifier = AppLockNotifier(
        _TestStorage(),
        biometricAuthenticator: () async {
          throw Exception('Biometric sensor error');
        },
      );
      await notifier.setupPin('1234');
      notifier.lock();

      final ok = await notifier.unlockWithBiometrics();

      expect(ok, false);
      expect(notifier.isLocked, true);
    });

    test('unsuccessful authentication does not unlock', () async {
      await lockApp();

      final ok = await notifier.unlockWithBiometrics();

      expect(ok, false);
      expect(notifier.isLocked, true);

      // App should still be unlockable via PIN
      await unlockWithPin();
    });

    test('sequential biometric attempts are handled safely', () async {
      await lockApp();

      // First attempt fails
      final ok1 = await notifier.unlockWithBiometrics();
      expect(ok1, false);
      expect(notifier.isLocked, true);

      // Second attempt succeeds
      notifier = AppLockNotifier(
        _TestStorage(),
        biometricAuthenticator: () async => true,
      );
      await notifier.setupPin('1234');

      final ok2 = await notifier.unlockWithBiometrics();
      expect(ok2, true);
      expect(notifier.isLocked, false);
    });
  });
}
