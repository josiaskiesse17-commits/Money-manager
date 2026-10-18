import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_manager/data/repositories/auth_repository.dart';

class AuthStateNotifier extends StateNotifier<User?> {
  AuthStateNotifier(this._repo) : super(null) {
    _repo.authStateChanges.listen((user) => state = user);
  }

  final AuthRepository _repo;

  String? _signInError;
  String? _signUpError;
  bool _resetSent = false;
  bool _busy = false;

  String? get signInError => _signInError;
  String? get signUpError => _signUpError;
  bool get resetSent => _resetSent;
  bool get busy => _busy;

  Future<void> signIn(String email, String password) async {
    _signInError = null;
    _busy = true;
    try {
      await _repo.signIn(email, password);
    } catch (e) {
      _signInError = 'Wrong email or password.';
    } finally {
      _busy = false;
    }
  }

  Future<void> signUp(String email, String password) async {
    _signUpError = null;
    _busy = true;
    try {
      await _repo.signUp(email, password);
    } catch (e) {
      _signUpError = 'Sign up failed.';
    } finally {
      _busy = false;
    }
  }

  Future<void> resetPassword(String email) async {
    _busy = true;
    try {
      await _repo.resetPassword(email);
      _resetSent = true;
    } catch (e) {
      _signUpError = 'Password reset failed.';
    } finally {
      _busy = false;
    }
  }

  Future<void> signOut() async {
    await _repo.signOut();
  }
}

final authProvider = StateNotifierProvider<AuthStateNotifier, User?>((ref) {
  return AuthStateNotifier(ref.read(authRepositoryProvider));
});
