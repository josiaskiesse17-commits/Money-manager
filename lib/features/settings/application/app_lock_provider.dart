import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/material.dart' show VoidCallback;

typedef BiometricAuthenticator = Future<bool> Function();

abstract class AppLockStorage {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class _SecureStorageImpl implements AppLockStorage {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  Future<String?> read(String key) {
    return _storage.read(key: key);
  }

  @override
  Future<void> write(String key, String value) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete(String key) {
    return _storage.delete(key: key);
  }
}

/// Revision used to rebuild the application when lock visibility changes.
final appLockRefreshProvider = StateProvider<int>((ref) => 0);

class AppLockNotifier extends StateNotifier<bool> {
  AppLockNotifier(
    this._storage, {
    BiometricAuthenticator? biometricAuthenticator,
    this._onLockStateChanged,
  }) : super(false) {
    _biometricAuthenticator = biometricAuthenticator ?? _defaultBiometricAuth;
    _load();
  }

  final AppLockStorage _storage;
  final VoidCallback? _onLockStateChanged;

  late final BiometricAuthenticator _biometricAuthenticator;

  static const String _pinKey = 'app_lock_pin';
  static const String _saltKey = 'app_lock_salt';

  bool _isLocked = false;
  bool _hasLoaded = false;
  DateTime? _backgroundedAt;

  bool get hasPin => state;

  bool get isLocked => _isLocked;

  bool get hasLoaded => _hasLoaded;

  void _notifyLockStateChanged() {
    _onLockStateChanged?.call();
  }

  static Future<bool> _defaultBiometricAuth() async {
    if (kIsWeb) return false;

    try {
      final auth = LocalAuthentication();

      return await auth.authenticate(
        localizedReason: 'Authenticate to unlock Money Manager',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> _load() async {
    try {
      final pin = await _storage.read(_pinKey);

      if (!mounted) return;

      final hasPin = pin != null && pin.isNotEmpty;

      _isLocked = hasPin;
      _hasLoaded = true;
      state = hasPin;

      // Notify the application that storage initialization has completed.
      _notifyLockStateChanged();
    } catch (_) {
      if (!mounted) return;

      // Fail closed: do not expose protected content if we cannot determine
      // whether a PIN exists. Keep initialization status explicit.
      _hasLoaded = true;
      _isLocked = true;
      state = false;

      _notifyLockStateChanged();
    }
  }

  static String hashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt$pin');
    final digest = sha256.convert(bytes);

    return base64.encode(digest.bytes);
  }

  static String generateSalt() {
    final random = Random.secure();

    return List.generate(
      16,
      (_) => random.nextInt(256),
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<void> _storePin(String pin) async {
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      throw ArgumentError('The PIN must contain exactly four digits.');
    }

    final salt = generateSalt();
    final hash = hashPin(pin, salt);

    await _storage.write(_saltKey, salt);
    await _storage.write(_pinKey, hash);

    if (!mounted) return;

    _isLocked = false;
    state = true;

    _notifyLockStateChanged();
  }

  /// Creates a PIN only when one does not already exist.
  ///
  /// Existing PINs must be changed using [changePin], which verifies the
  /// current PIN before saving a replacement.
  Future<void> setupPin(String pin) async {
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      throw ArgumentError('The PIN must contain exactly four digits.');
    }

    final existingPin = await _storage.read(_pinKey);

    if (existingPin != null && existingPin.isNotEmpty) {
      throw StateError(
        'A PIN already exists. Verify the current PIN before changing it.',
      );
    }

    await _storePin(pin);
  }

  Future<bool> verifyPin(String pin) async {
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      return false;
    }

    try {
      final storedHash = await _storage.read(_pinKey);
      final salt = await _storage.read(_saltKey);

      if (storedHash == null || salt == null) {
        return false;
      }

      final candidateHash = hashPin(pin, salt);

      return candidateHash == storedHash;
    } catch (_) {
      return false;
    }
  }

  Future<void> removePin() async {
    await _storage.delete(_pinKey);
    await _storage.delete(_saltKey);

    if (!mounted) return;

    _isLocked = false;
    state = false;
    _backgroundedAt = null;

    _notifyLockStateChanged();
  }

  /// Changes an existing PIN only after verifying the current PIN.
  Future<bool> changePin(String oldPin, String newPin) async {
    if (!RegExp(r'^\d{4}$').hasMatch(newPin)) {
      throw ArgumentError('The new PIN must contain exactly four digits.');
    }

    final verified = await verifyPin(oldPin);

    if (!verified) {
      return false;
    }

    await _storePin(newPin);

    return true;
  }

  void lock() {
    if (!_hasLoaded || !state || _isLocked) return;

    _isLocked = true;
    _notifyLockStateChanged();
  }

  Future<bool> unlock(String pin) async {
    if (!_isLocked) return true;

    final verified = await verifyPin(pin);

    if (!verified || !mounted) {
      return false;
    }

    _isLocked = false;
    _notifyLockStateChanged();

    return true;
  }

  Future<bool> unlockWithBiometrics() async {
    if (!_isLocked) return true;

    final authenticated = await authenticateWithBiometrics();

    if (!authenticated || !mounted) {
      return false;
    }

    _isLocked = false;
    _notifyLockStateChanged();

    return true;
  }

  void didEnterBackground() {
    _backgroundedAt = DateTime.now();
  }

  bool checkBackgroundLock() {
    final backgroundedAt = _backgroundedAt;

    if (backgroundedAt == null) {
      return false;
    }

    _backgroundedAt = null;

    final elapsed = DateTime.now().difference(backgroundedAt);

    return elapsed.inSeconds >= 15;
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _biometricAuthenticator();
    } catch (_) {
      return false;
    }
  }
}

final appLockProvider = StateNotifierProvider<AppLockNotifier, bool>((ref) {
  return AppLockNotifier(
    _SecureStorageImpl(),
    onLockStateChanged: () {
      ref.read(appLockRefreshProvider.notifier).state++;
    },
  );
});
