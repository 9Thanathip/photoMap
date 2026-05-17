import '../domain/auth_repository.dart';

class MockAuthRepository implements AuthRepository {
  @override
  Stream<AuthUser?> userChanges() => Stream<AuthUser?>.value(null);

  @override
  Future<AuthUser> signIn(String email, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    return AuthUser(
      uid: 'user_${email.hashCode.abs()}',
      email: email,
      emailVerified: true,
    );
  }

  @override
  Future<AuthUser> signUp(String email, String password, String name) async {
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    return AuthUser(
      uid: 'user_${email.hashCode.abs()}',
      email: email,
      displayName: name,
      emailVerified: false,
    );
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    return const AuthUser(
      uid: 'google_mock_user',
      email: 'mock@gmail.com',
      displayName: 'Mock Google',
      emailVerified: true,
    );
  }

  @override
  Future<void> sendEmailVerification() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<AuthUser?> reloadUser() async => null;

  @override
  Future<void> signOut() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<void> deleteAccount() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
  }
}
