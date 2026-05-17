class AuthUser {
  const AuthUser({
    required this.uid,
    required this.emailVerified,
    this.email,
    this.displayName,
  });

  final String uid;
  final bool emailVerified;
  final String? email;
  final String? displayName;
}

/// Thrown when the user dismisses a provider sign-in sheet. Callers
/// should treat this as a no-op, not an error to surface.
class AuthCancelledException implements Exception {
  const AuthCancelledException();
}

abstract class AuthRepository {
  /// Emits the current user on subscription and on every auth change
  /// (sign-in / sign-out), or null when signed out. Note: this does NOT
  /// re-fire when [emailVerified] flips — call [reloadUser] for that.
  Stream<AuthUser?> userChanges();

  Future<AuthUser> signIn(String email, String password);
  Future<AuthUser> signUp(String email, String password, String name);

  /// Interactive Google sign-in. Throws [AuthCancelledException] if the
  /// user dismisses the picker.
  Future<AuthUser> signInWithGoogle();

  /// Sends a verification link to the current user's email.
  Future<void> sendEmailVerification();

  /// Reloads the current user from the server and returns the fresh
  /// snapshot (so [AuthUser.emailVerified] reflects a clicked link).
  Future<AuthUser?> reloadUser();

  Future<void> signOut();
  Future<void> deleteAccount();
}
