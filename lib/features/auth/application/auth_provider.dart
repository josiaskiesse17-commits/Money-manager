import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_manager/data/repositories/auth_repository.dart';

class AuthStateNotifier extends StateNotifier<User?> {
  AuthStateNotifier(this._repo) : super(null) {
    _repo.authStateChanges.listen((user) => state = user);
  }

  final AuthRepository _repo;

  Future<void> signIn(String email, String password) async {
    await _repo.signIn(email, password);
  }

  Future<void> signUp(String email, String password) async {
    await _repo.signUp(email, password);
  }

  Future<void> resetPassword(String email) async {
    await _repo.resetPassword(email);
  }

  Future<void> signOut() async {
    await _repo.signOut();
  }
}

final authProvider = StateNotifierProvider<AuthStateNotifier, User?>((ref) {
  return AuthStateNotifier(ref.read(authRepositoryProvider));
});
