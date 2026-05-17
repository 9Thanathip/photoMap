import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/firebase_auth_repository.dart';
import '../../domain/auth_repository.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  awaitingVerification,
  unauthenticated,
}

class AuthState {
  const AuthState({
    required this.status,
    this.userId,
    this.email,
    this.displayName,
    this.error,
  });

  final AuthStatus status;
  final String? userId;
  final String? email;
  final String? displayName;
  final String? error;

  factory AuthState.initial() => const AuthState(status: AuthStatus.initial);
  factory AuthState.loading() => const AuthState(status: AuthStatus.loading);
  factory AuthState.authenticated(
    String userId, {
    String? email,
    String? displayName,
  }) =>
      AuthState(
        status: AuthStatus.authenticated,
        userId: userId,
        email: email,
        displayName: displayName,
      );
  factory AuthState.awaitingVerification(String userId, String? email) =>
      AuthState(
        status: AuthStatus.awaitingVerification,
        userId: userId,
        email: email,
      );
  factory AuthState.unauthenticated([String? error]) =>
      AuthState(status: AuthStatus.unauthenticated, error: error);

  bool get isAuthenticated => status == AuthStatus.authenticated;
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FirebaseAuthRepository(),
);

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repo) : super(AuthState.initial()) {
    _sub = _repo.userChanges().listen((user) {
      if (!mounted) return;
      // Keep a freshly-set form error visible instead of letting a
      // null stream tick reset it.
      if (user == null &&
          state.status == AuthStatus.unauthenticated &&
          state.error != null) {
        return;
      }
      state = _resolve(user);
    });
  }

  final AuthRepository _repo;
  late final StreamSubscription<AuthUser?> _sub;

  AuthState _resolve(AuthUser? user) {
    if (user == null) return AuthState.unauthenticated();
    return user.emailVerified
        ? AuthState.authenticated(
            user.uid,
            email: user.email,
            displayName: user.displayName,
          )
        : AuthState.awaitingVerification(user.uid, user.email);
  }

  Future<void> signIn(String email, String password) async {
    state = AuthState.loading();
    try {
      final user = await _repo.signIn(email, password);
      if (mounted) state = _resolve(user);
    } catch (e) {
      if (mounted) state = AuthState.unauthenticated(_clean(e));
    }
  }

  Future<void> signUp(String email, String password, String name) async {
    state = AuthState.loading();
    try {
      final user = await _repo.signUp(email, password, name);
      await _repo.sendEmailVerification();
      if (mounted) state = _resolve(user);
    } catch (e) {
      if (mounted) state = AuthState.unauthenticated(_clean(e));
    }
  }

  Future<void> signInWithGoogle() async {
    state = AuthState.loading();
    try {
      final user = await _repo.signInWithGoogle();
      if (mounted) state = _resolve(user);
    } on AuthCancelledException {
      if (mounted) state = AuthState.unauthenticated();
    } catch (e) {
      if (mounted) state = AuthState.unauthenticated(_clean(e));
    }
  }

  /// Resends the verification link. Returns null on success, else an error.
  Future<String?> resendVerification() async {
    try {
      await _repo.sendEmailVerification();
      return null;
    } catch (e) {
      return _clean(e);
    }
  }

  /// Reloads the user; promotes to authenticated if the link was clicked.
  /// Returns true when the email is now verified.
  Future<bool> refreshVerification() async {
    try {
      final user = await _repo.reloadUser();
      if (user != null && mounted) state = _resolve(user);
      return user?.emailVerified ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> signOut() async {
    state = AuthState.loading();
    try {
      await _repo.signOut();
    } catch (e) {
      if (mounted) state = AuthState.unauthenticated(_clean(e));
    }
  }

  Future<void> deleteAccount() async {
    state = AuthState.loading();
    try {
      await _repo.deleteAccount();
    } catch (e) {
      if (mounted) state = AuthState.unauthenticated(_clean(e));
    }
  }

  String _clean(Object e) => e.toString().replaceFirst('Exception: ', '');

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});
