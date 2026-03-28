import '../domain/auth_repository.dart';

class MockAuthRepository implements AuthRepository {
  @override
  Future<String> signIn(String email, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    return 'user_${email.hashCode.abs()}';
  }

  @override
  Future<String> signUp(String email, String password, String name) async {
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    return 'user_${email.hashCode.abs()}';
  }

  @override
  Future<void> signOut() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<void> deleteAccount() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
  }
}
