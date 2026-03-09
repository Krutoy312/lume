import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_service.dart';

// ── Service provider ─────────────────────────────────────────────────────────

/// Singleton [AuthService] accessible throughout the app.
final authServiceProvider = Provider<AuthService>(
  (_) => AuthService(),
);

// ── Auth state stream ─────────────────────────────────────────────────────────

/// Emits [User?] whenever sign-in status changes.
/// Drives the GoRouter redirect — the router listens to this stream.
final authStateChangesProvider = StreamProvider<User?>(
  (ref) => ref.watch(authServiceProvider).authStateChanges,
);

// ── User Firestore document ───────────────────────────────────────────────────

/// Watches the current user's Firestore document in real time.
///
/// Returns null when:
///   • No user is signed in.
///   • The [initUserDocument] Cloud Function has not yet run (race window
///     between Firebase Auth sign-in and the async CF invocation).
///
/// The home screen uses this to show a loading state until the document
/// exists, preventing reads against a non-existent document.
///
/// This provider only READS — it never creates the document.
/// Document creation is the exclusive responsibility of [initUserDocument] CF.
final userDocumentProvider = StreamProvider.autoDispose<
    DocumentSnapshot<Map<String, dynamic>>?>((ref) {
  final userAsync = ref.watch(authStateChangesProvider);
  final user = userAsync.valueOrNull;

  // Not signed in — emit null immediately, no Firestore subscription needed.
  if (user == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots();
});

// ── Auth controller ───────────────────────────────────────────────────────────

/// Tracks the in-progress state of a sign-in or sign-out operation.
///
/// State is [AsyncValue<void>]:
///   • [AsyncData]    — idle (no pending operation).
///   • [AsyncLoading] — operation in-flight (show loading UI).
///   • [AsyncError]   — operation failed; error is [AuthFailure].
class AuthController extends StateNotifier<AsyncValue<void>> {
  AuthController(this._service) : super(const AsyncData(null));

  final AuthService _service;

  Future<void> signInWithGoogle() => _run(_service.signInWithGoogle);
  Future<void> signInWithApple() => _run(_service.signInWithApple);
  Future<void> signOut() => _run(_service.signOut);
  Future<void> deleteAccount() => _run(_service.deleteAccount);
  Future<void> updateName(String name) => _run(() => _service.updateName(name));
  Future<void> updateSkinType(String skinType) =>
      _run(() => _service.updateSkinType(skinType));
  Future<void> updateGoal(String goal, List<String> trackedMetrics) =>
      _run(() => _service.updateGoal(goal, trackedMetrics));
  Future<void> updateCareTimes({
    required int morningMinutes,
    required int eveningMinutes,
  }) => _run(() => _service.updateCareTimes(
        morningMinutes: morningMinutes,
        eveningMinutes: eveningMinutes,
      ));

  /// Clears a previous error so the UI can reset the error banner.
  void clearError() => state = const AsyncData(null);

  Future<void> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(action);
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>(
  (ref) => AuthController(ref.watch(authServiceProvider)),
);
