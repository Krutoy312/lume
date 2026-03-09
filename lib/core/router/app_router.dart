import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/shell/presentation/screens/main_shell.dart';

// ── Route name constants ──────────────────────────────────────────────────────

abstract final class AppRoutes {
  static const login = '/login';
  static const onboarding = '/onboarding';
  static const home = '/';
}

// ── Router refresh notifier ───────────────────────────────────────────────────

/// Listens to Firebase Auth changes and the user's Firestore document.
///
/// Notifies GoRouter whenever the sign-in state or onboarding status changes,
/// causing the redirect logic to re-evaluate.
///
/// The [docLoaded] flag stays false until the first Firestore snapshot arrives.
/// While false, the router keeps the user at the current route (home shows a
/// loading state via [userDocumentProvider]) rather than prematurely
/// redirecting to onboarding.
class _AppRouterNotifier extends ChangeNotifier {
  _AppRouterNotifier() {
    // Fire once so GoRouter evaluates redirect on first build.
    notifyListeners();
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
  }

  late final StreamSubscription<User?> _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _docSub;

  bool docLoaded = false;
  bool onboardingCompleted = false;

  void _onAuthChanged(User? user) {
    _docSub?.cancel();
    _docSub = null;
    docLoaded = false;
    onboardingCompleted = false;

    if (user == null) {
      notifyListeners();
      return;
    }

    // Start watching the user's document.
    _docSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((doc) {
      if (!doc.exists) {
        // Cloud Function hasn't created the document yet — keep waiting.
        notifyListeners();
        return;
      }
      final wasLoaded = docLoaded;
      docLoaded = true;
      final completed =
          doc.data()?['onboardingCompleted'] as bool? ?? false;

      // Latch: once onboardingCompleted is true it never reverts to false
      // within the same app session. This prevents a Firestore write-rejection
      // rollback (or stale cache snapshot) from bouncing the user back to
      // the onboarding screen after they have finished the quiz.
      final newCompleted = onboardingCompleted || completed;

      if (!wasLoaded || newCompleted != onboardingCompleted) {
        onboardingCompleted = newCompleted;
        notifyListeners();
      }
    });

    // Trigger an immediate re-eval while the first snapshot is in-flight.
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub.cancel();
    _docSub?.cancel();
    super.dispose();
  }
}

final _notifier = _AppRouterNotifier();

// ── Router ────────────────────────────────────────────────────────────────────

/// Singleton GoRouter.
///
/// Redirect rules:
///   • Unauthenticated                          → /login
///   • Authenticated, doc not yet loaded        → /  (home shows loading state)
///   • Authenticated, onboarding not complete   → /onboarding
///   • Authenticated, onboarding complete       → stay (or leave /login //onboarding)
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.home,
  debugLogDiagnostics: false,
  refreshListenable: _notifier,
  redirect: (_, state) {
    final isAuthenticated = FirebaseAuth.instance.currentUser != null;
    final loc = state.matchedLocation;
    final isOnLogin = loc == AppRoutes.login;
    final isOnOnboarding = loc == AppRoutes.onboarding;

    // Not signed in → always go to login.
    if (!isAuthenticated) {
      return isOnLogin ? null : AppRoutes.login;
    }

    // Signed in but Firestore doc not yet loaded →
    // send to home (HomeScreen shows loading spinner) or stay wherever we are.
    if (!_notifier.docLoaded) {
      return isOnLogin ? AppRoutes.home : null;
    }

    // Onboarding not completed → go to onboarding.
    if (!_notifier.onboardingCompleted) {
      return isOnOnboarding ? null : AppRoutes.onboarding;
    }

    // Onboarding complete → leave login / onboarding.
    if (isOnLogin || isOnOnboarding) return AppRoutes.home;
    return null;
  },
  routes: [
    GoRoute(
      path: AppRoutes.login,
      builder: (_, __) => const LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.onboarding,
      builder: (_, __) => const OnboardingScreen(),
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
