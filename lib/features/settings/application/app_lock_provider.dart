import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// App lock provider: manages PIN (salted SHA-256 hash) in secure storage.
///
/// PIN is stored as salted hash in secure storage (device only).
/// Never stored in plain text or in Firebase.
class AppLockNotifier extends StateNotifier<bool> {
  AppLockNotifier(this._storage) : super(false) {
    _load();
  }

  final FlutterSecureStorage _storage;

  static const _pinKey = 'app_lock_pin';
  static const _saltKey = 'app_lock_salt';

  bool _hasPin = false;
  bool _isLocked = false;
  DateTime? _backgroundedAt;

  bool get hasPin => _hasPin;
  bool get isLocked => _isLocked;

  void _load() async {
    final pin = await _storage.read(key: _pinKey);
    _hasPin = pin != null && pin.isNotEmpty;
    state = _hasPin;
  }

  /// Hashes a PIN with a random salt using SHA-256.
  static String hashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt$pin');
    final digest = sha256.convert(bytes);
    return base64.encode(digest.bytes);
  }

  /// Generates a random 16-character salt.
  static String generateSalt() {
    final random = Random.secure();
    return List.generate(
      16,
      (i) => random.nextInt(256),
    ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Sets up a new PIN.
  Future<void> setupPin(String pin) async {
    final salt = generateSalt();
    final hash = hashPin(pin, salt);
    await _storage.write(key: _pinKey, value: hash);
    await _storage.write(key: _saltKey, value: salt);
    _hasPin = true;
    state = true;
  }

  /// Verifies a PIN against the stored hash.
  Future<bool> verifyPin(String pin) async {
    final storedHash = await _storage.read(key: _pinKey);
    final salt = await _storage.read(key: _saltKey);
    if (storedHash == null || salt == null) return false;
    final hash = hashPin(pin, salt);
    return hash == storedHash;
  }

  /// Removes the PIN (used for forgot PIN flow).
  Future<void> removePin() async {
    await _storage.delete(key: _pinKey);
    await _storage.delete(key: _saltKey);
    _hasPin = false;
    state = false;
    _isLocked = false;
  }

  /// Changes the PIN.
  Future<void> changePin(String oldPin, String newPin) async {
    final verified = await verifyPin(oldPin);
    if (!verified) return;
    await setupPin(newPin);
  }

  /// Locks the app immediately.
  void lock() {
    _isLocked = true;
  }

  /// Unlocks the app after verifying the PIN.
  Future<bool> unlock(String pin) async {
    final verified = await verifyPin(pin);
    if (verified) {
      _isLocked = false;
    }
    return verified;
  }

  /// Unlocks the app after successful biometric authentication.
  void unlockWithBiometrics() {
    _isLocked = false;
  }

  /// Records that the app went to the background.
  void didEnterBackground() {
    _backgroundedAt = DateTime.now();
  }

  /// Checks if the app has been in the background for more than 15 seconds.
  /// Returns true if the app should be locked.
  bool checkBackgroundLock() {
    if (_backgroundedAt == null) return false;
    final elapsed = DateTime.now().difference(_backgroundedAt!);
    _backgroundedAt = null;
    return elapsed.inSeconds >= 15;
  }

  /// Attempts biometric authentication if available.
  /// Returns false on web or if biometrics is not available.
  Future<bool> authenticateWithBiometrics() async {
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
    } catch (e) {
      return false;
    }
  }
}

final appLockProvider = StateNotifierProvider<AppLockNotifier, bool>((ref) {
  return AppLockNotifier(FlutterSecureStorage());
});
