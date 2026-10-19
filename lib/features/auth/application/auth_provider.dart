import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_manager/app/error_reporter.dart';
import 'package:money_manager/data/repositories/auth_repository.dart';

class AuthStateNotifier extends StateNotifier<User?> {
  AuthStateNotifier(this._repo) : super(null) {
    _repo.authStateChanges.listen((user) => state = user);
  }

  final AuthRepository _repo;

  String? _signInError;
  String? _signUpError;
  String? _resetError;
  bool _resetSent = false;
  bool _busy = false;

  String? get signInError => _signInError;
  String? get signUpError => _signUpError;
  String? get resetError => _resetError;
  bool get resetSent => _resetSent;
  bool get busy => _busy;

  Future<void> signIn(String email, String password) async {
    _signInError = null;
    _busy = true;
    try {
      await _repo.signIn(email, password);
    } on FirebaseAuthException catch (e) {
      _signInError = _mapAuthException(e.code);
      reportError(e, userMessage: _signInError);
    } catch (e) {
      _signInError = 'Sign in failed. Please try again.';
      reportError(e, userMessage: _signInError);
    } finally {
      _busy = false;
    }
  }

  Future<void> signUp(String email, String password) async {
    _signUpError = null;
    _busy = true;
    try {
      await _repo.signUp(email, password);
    } on FirebaseAuthException catch (e) {
      _signUpError = _mapAuthException(e.code);
      reportError(e, userMessage: _signUpError);
    } catch (e) {
      _signUpError = 'Sign up failed. Please try again.';
      reportError(e, userMessage: _signUpError);
    } finally {
      _busy = false;
    }
  }

  Future<void> resetPassword(String email) async {
    _resetError = null;
    _busy = true;
    try {
      await _repo.resetPassword(email);
      _resetSent = true;
    } on FirebaseAuthException catch (e) {
      _resetError = _mapAuthException(e.code);
      reportError(e, userMessage: _resetError);
    } catch (e) {
      _resetError = 'Password reset failed. Please try again.';
      reportError(e, userMessage: _resetError);
    } finally {
      _busy = false;
    }
  }

  Future<void> signOut() async {
    _busy = true;
    try {
      await _repo.signOut();
    } on FirebaseAuthException catch (e) {
      final msg = _mapAuthException(e.code);
      reportError(e, userMessage: msg);
    } catch (e) {
      reportError(e, userMessage: 'Sign out failed. Please try again.');
    } finally {
      _busy = false;
    }
  }

  String _mapAuthException(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found for this email.';
      case 'wrong-password':
        return 'Wrong password.';
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'network-request-failed':
        return 'No internet connection. Try again.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}

final authProvider = StateNotifierProvider<AuthStateNotifier, User?>((ref) {
  return AuthStateNotifier(ref.read(authRepositoryProvider));
});
