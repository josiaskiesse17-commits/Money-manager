import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// App lock provider: manages PIN (salted SHA-256 hash) in secure storage.
///
/// PIN is stored as salted SHA-256 hash in secure storage (device only).
/// Never stored in plain text or in Firebase.
class AppLockNotifier extends StateNotifier<bool> {
  AppLockNotifier(this._storage) : super(false) {
    _load();
  }

  final FlutterSecureStorage _storage;

  static const _pinKey = 'app_lock_pin';
  static const _saltKey = 'app_lock_salt';

  bool _hasPin = false;

  bool get hasPin => _hasPin;

  Future<void> _load() async {
    final pin = await _storage.read(key: _pinKey);
    _hasPin = pin != null && pin.isNotEmpty;
    state = _hasPin;
  }

  /// Hashes a PIN with a random salt using SHA-256.
  static String _hashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt$pin');
    final digest = sha256.convert(bytes);
    return base64.encode(digest.bytes);
  }

  /// Generates a random 16-character salt.
  static String _generateSalt() {
    final random = Random.secure();
    return List.generate(
      16,
      (i) => random.nextInt(256),
    ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Sets up a new PIN. Returns the salt for verification.
  Future<void> setupPin(String pin) async {
    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);
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
    final hash = _hashPin(pin, salt);
    return hash == storedHash;
  }

  /// Removes the PIN (used for forgot PIN flow).
  Future<void> removePin() async {
    await _storage.delete(key: _pinKey);
    await _storage.delete(key: _saltKey);
    _hasPin = false;
    state = false;
  }

  /// Changes the PIN.
  Future<void> changePin(String oldPin, String newPin) async {
    final verified = await verifyPin(oldPin);
    if (!verified) return;
    await setupPin(newPin);
  }
}

final appLockProvider = StateNotifierProvider<AppLockNotifier, bool>((ref) {
  return AppLockNotifier(FlutterSecureStorage());
});
