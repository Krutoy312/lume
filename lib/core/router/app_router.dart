import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/shell/presentation/screens/main_shell.dart';

// ── Route name constants ──────────────────────────────────────────────────────

abstract final class AppRoutes {
  static const login = '/login';
  static const home = '/';
}

// ── GoRouter refresh bridge ───────────────────────────────────────────────────

/// Wraps a [Stream] so GoRouter can call [notifyListeners] whenever the
/// stream emits, causing redirect logic to re-evaluate.
class _GoRouterRefreshStream extends ChangeNotifier {
  _GoRouterRefreshStream(Stream<dynamic> stream) {
    // Fire once immediately so GoRouter evaluates redirect on first build.
    notifyListeners();
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

// ── Router ────────────────────────────────────────────────────────────────────

/// Singleton GoRouter.
///
/// Redirect rules:
///   • Unauthenticated + not on /login  → /login
///   • Authenticated   + on /login      → /
///   • Otherwise                        → no redirect (stay)
///
/// The [_GoRouterRefreshStream] wrapping [FirebaseAuth.authStateChanges] causes
/// GoRouter to re-run the redirect every time the signed-in user changes,
/// ensuring automatic navigation on login / logout.
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.home,
  debugLogDiagnostics: false,
  refreshListenable: _GoRouterRefreshStream(
    FirebaseAuth.instance.authStateChanges(),
  ),
  redirect: (_, state) {
    final isAuthenticated = FirebaseAuth.instance.currentUser != null;
    final isOnLogin = state.matchedLocation == AppRoutes.login;

    if (!isAuthenticated && !isOnLogin) return AppRoutes.login;
    if (isAuthenticated && isOnLogin) return AppRoutes.home;
    return null; // no redirect
  },
  routes: [
    GoRoute(
      path: AppRoutes.login,
      builder: (_, __) => const LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.home,
      builder: (_, __) => const MainShell(),
    ),
  ],
  errorBuilder: (_, state) => Scaffold(
    backgroundColor: const Color(0xFFF7F7F7),
    body: Center(
      child: Text(
        'Ошибка навигации\n${state.error}',
        textAlign: TextAlign.center,
      ),
    ),
  ),
);
