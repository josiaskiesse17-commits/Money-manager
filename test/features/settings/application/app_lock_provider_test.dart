import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/features/settings/application/app_lock_provider.dart';

void main() {
  group('PIN hashing', () {
    test('hashPin produces consistent output for same input', () {
      final salt = AppLockNotifier.generateSalt();
      final hash1 = AppLockNotifier.hashPin('1234', salt);
      final hash2 = AppLockNotifier.hashPin('1234', salt);
      expect(hash1, hash2);
    });

    test('hashPin produces different output for different PINs', () {
      final salt = AppLockNotifier.generateSalt();
      final hash1 = AppLockNotifier.hashPin('1234', salt);
      final hash2 = AppLockNotifier.hashPin('5678', salt);
      expect(hash1, isNot(hash2));
    });

    test('hashPin produces different output for different salts', () {
      final hash1 = AppLockNotifier.hashPin('1234', 'salt1');
      final hash2 = AppLockNotifier.hashPin('1234', 'salt2');
      expect(hash1, isNot(hash2));
    });

    test('generateSalt produces 32-character hex string', () {
      final salt1 = AppLockNotifier.generateSalt();
      final salt2 = AppLockNotifier.generateSalt();
      expect(salt1.length, 32);
      expect(salt2.length, 32);
      expect(salt1, isNot(salt2));
      expect(salt1, matches(RegExp(r'^[0-9a-f]{32}$')));
    });
  });
}
