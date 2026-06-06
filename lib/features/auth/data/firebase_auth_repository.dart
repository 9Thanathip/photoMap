import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../domain/auth_repository.dart';

/// OAuth 2.0 **Web** client ID from Firebase (Console → Authentication →
/// Sign-in method → Google → Web SDK configuration, or `google-services.json`
/// `client_type: 3`). Required on Android so Firebase accepts the Google
/// ID token. Pass via `--dart-define=GOOGLE_SERVER_CLIENT_ID=...`. Not
/// needed on iOS (clientId is read from GoogleService-Info.plist).
const String _googleServerClientId =
    String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository([FirebaseAuth? auth])
      : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  AuthUser _map(User u) => AuthUser(
        uid: u.uid,
        email: u.email,
        displayName: u.displayName,
        emailVerified: u.emailVerified,
      );

  @override
  Stream<AuthUser?> userChanges() =>
      _auth.authStateChanges().map((u) => u == null ? null : _map(u));

  @override
  Future<AuthUser> signIn(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return _map(cred.user!);
    } on FirebaseAuthException catch (e) {
      throw Exception(_message(e));
    }
  }

  @override
  Future<AuthUser> signUp(String email, String password, String name) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user!;
      await user.updateDisplayName(name.trim());
      await user.reload();
      return _map(_auth.currentUser ?? user);
    } on FirebaseAuthException catch (e) {
      throw Exception(_message(e));
    }
  }

  bool _googleReady = false;

  Future<void> _ensureGoogleInit() async {
    if (_googleReady) return;
    await GoogleSignIn.instance.initialize(
      serverClientId:
          _googleServerClientId.isEmpty ? null : _googleServerClientId,
    );
    _googleReady = true;
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    try {
      await _ensureGoogleInit();
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw Exception('authFailed');
      }
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final cred = await _auth.signInWithCredential(credential);
      return _map(cred.user!);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthCancelledException();
      }
      throw Exception('authFailed');
    } on FirebaseAuthException catch (e) {
      throw Exception(_message(e));
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw Exception(_message(e));
    }
  }

  @override
  Future<AuthUser?> reloadUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    await user.reload();
    final fresh = _auth.currentUser;
    return fresh == null ? null : _map(fresh);
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> deleteAccount() async {
    try {
      await _auth.currentUser?.delete();
    } on FirebaseAuthException catch (e) {
      throw Exception(_message(e));
    }
  }

  /// Returns a stable error *code* (not a display string). The UI layer maps
  /// these to localized text — see `localizedAuthError`.
  String _message(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'authInvalidEmail';
      case 'user-disabled':
        return 'authUserDisabled';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'authInvalidCredentials';
      case 'email-already-in-use':
        return 'authEmailInUse';
      case 'weak-password':
        return 'authWeakPassword';
      case 'network-request-failed':
        return 'authNetworkError';
      case 'requires-recent-login':
        return 'authRequiresRecentLogin';
      case 'too-many-requests':
        return 'authTooManyRequests';
      default:
        return 'authFailed';
    }
  }
}
