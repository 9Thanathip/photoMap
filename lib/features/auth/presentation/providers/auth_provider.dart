import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/mock_auth_repository.dart';
import '../../domain/auth_repository.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated }

class AuthState {
  const AuthState({required this.status, this.userId, this.error});

  final AuthStatus status;
  final String? userId;
  final String? error;

  factory AuthState.initial() => const AuthState(status: AuthStatus.initial);
  factory AuthState.loading() => const AuthState(status: AuthStatus.loading);
  factory AuthState.authenticated(String userId) =>
      AuthState(status: AuthStatus.authenticated, userId: userId);
  factory AuthState.unauthenticated([String? error]) =>
      AuthState(status: AuthStatus.unauthenticated, error: error);

  bool get isAuthenticated => status == AuthStatus.authenticated;
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => MockAuthRepository(),
);

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repo) : super(AuthState.initial()) {
    _init();
  }

  final AuthRepository _repo;

  Future<void> _init() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) state = AuthState.unauthenticated();
  }

  Future<void> signIn(String email, String password) async {
    state = AuthState.loading();
    try {
      final userId = await _repo.signIn(email, password);
      state = AuthState.authenticated(userId);
    } catch (e) {
      state = AuthState.unauthenticated(e.toString());
    }
  }

  Future<void> signUp(String email, String password, String name) async {
    state = AuthState.loading();
    try {
      final userId = await _repo.signUp(email, password, name);
      state = AuthState.authenticated(userId);
    } catch (e) {
      state = AuthState.unauthenticated(e.toString());
    }
  }

  Future<void> signOut() async {
    state = AuthState.loading();
    await _repo.signOut();
    if (mounted) state = AuthState.unauthenticated();
  }

  Future<void> deleteAccount() async {
    state = AuthState.loading();
    await _repo.deleteAccount();
    if (mounted) state = AuthState.unauthenticated();
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});
