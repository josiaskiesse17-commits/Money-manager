import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_manager/data/firebase_providers.dart';

class AuthRepository {
  AuthRepository(this._auth);
  final FirebaseAuth _auth;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signUp(String email, String password) async {
    await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Sends an email verification message to the currently signed-in user.
  /// The user must click the link in their inbox; this method only sends it.
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No user is currently signed in.',
      );
    }
    await user.sendEmailVerification();
  }

  /// Reloads the current user from Firebase so [emailVerified] reflects the
  /// latest server state (e.g. after the user clicks the verification link).
  Future<void> reloadUser() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No user is currently signed in.',
      );
    }
    await user.reload();
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Google sign-in kept for later; UI button commented out.
  // Future<void> signInWithGoogle() async {
  //   final provider = GoogleAuthProvider();
  //   await _auth.signInWithProvider(provider);
  // }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.read(firebaseAuthProvider));
});
