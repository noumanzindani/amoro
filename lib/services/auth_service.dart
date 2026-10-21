import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _googleReady = false;

  Stream<User?> authStateChanges() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> signInWithEmail(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  Future<void> signUpWithEmail(String email, String password) => _auth
      .createUserWithEmailAndPassword(email: email.trim(), password: password);

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> signInWithGoogle() async {
    final google = GoogleSignIn.instance;
    if (!_googleReady) {
      await google.initialize();
      _googleReady = true;
    }
    final account = await google.authenticate();
    final idToken = account.authentication.idToken;
    await _auth.signInWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
  }

  Future<void> signOut() async {
    if (_googleReady) await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }
}

/// Short, user-facing text for Firebase auth errors.
String authErrorMessage(Object e) {
  if (e is GoogleSignInException) {
    return e.code == GoogleSignInExceptionCode.canceled
        ? 'Sign-in cancelled.'
        : 'Google sign-in failed.';
  }
  if (e is! FirebaseAuthException) {
    return 'Something went wrong. Please try again.';
  }
  switch (e.code) {
    case 'invalid-email':
      return 'That email address looks wrong.';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'Email or password is incorrect.';
    case 'email-already-in-use':
      return 'An account already exists for that email.';
    case 'weak-password':
      return 'Password must be at least 6 characters.';
    case 'too-many-requests':
      return 'Too many attempts. Try again later.';
    case 'network-request-failed':
      return 'No internet connection.';
    default:
      return e.message ?? 'Sign-in failed.';
  }
}
