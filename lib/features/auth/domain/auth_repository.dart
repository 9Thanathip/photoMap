abstract class AuthRepository {
  Future<String> signIn(String email, String password);
  Future<String> signUp(String email, String password, String name);
  Future<void> signOut();
  Future<void> deleteAccount();
}
