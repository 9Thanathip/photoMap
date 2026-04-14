import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/gallery/presentation/screens/gallery_screen.dart';
import '../../features/map/presentation/screens/map_screen.dart';
import '../../features/province/presentation/screens/province_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/shell/shell_screen.dart';
import '../../features/splash/view/splash_view.dart';

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(Ref ref) {
    ref.listen<AuthState>(authNotifierProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final auth = ref.read(authNotifierProvider);
      final loc = state.matchedLocation;

      switch (auth.status) {
        case AuthStatus.initial:
        case AuthStatus.loading:
          return loc == '/splash' ? null : '/splash';
        case AuthStatus.unauthenticated:
          const authPaths = ['/onboarding', '/login', '/register'];
          return authPaths.contains(loc) ? null : '/onboarding';
        case AuthStatus.authenticated:
          const unauthPaths = ['/splash', '/onboarding', '/login', '/register'];
          return unauthPaths.contains(loc) ? '/gallery' : null;
      }
    },
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (_, state) => _fade(state, const SplashView()),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (_, state) => _fade(state, const OnboardingScreen()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (_, state) => _fade(state, const LoginScreen()),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (_, state) => _fade(state, const RegisterScreen()),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => ShellScreen(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/gallery',
              pageBuilder: (_, state) => _fade(state, const GalleryScreen()),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/map',
              pageBuilder: (_, state) => _fade(state, const MapScreen()),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/province',
              pageBuilder: (_, state) => _fade(state, const ProvinceScreen()),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/settings',
              pageBuilder: (_, state) => _fade(state, const SettingsScreen()),
            ),
          ]),
        ],
      ),
    ],
  );
});

CustomTransitionPage<void> _fade(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
    transitionDuration: const Duration(milliseconds: 800),
  );
}
