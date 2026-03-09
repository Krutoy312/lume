import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../domain/auth_failure.dart';

/// Service layer — thin wrapper around Firebase Auth.
///
/// Responsibilities:
///   • Executes the OAuth flows (Google, Apple, anonymous).
///   • Translates platform-specific exceptions into [AuthFailure].
///   • Does NOT touch Firestore — document creation is handled by the
///     `initUserDocument` Cloud Function triggered on auth/user.onCreate.
class AuthService {
  AuthService()
      : _auth = FirebaseAuth.instance,
        _googleSignIn = GoogleSignIn();

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  // ── Stream ──────────────────────────────────────────────────────────────────

  /// Emits whenever the signed-in user changes (login / logout / token refresh).
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  // ── Google ──────────────────────────────────────────────────────────────────

  /// Opens the Google account picker and exchanges the credential with Firebase.
  ///
  /// On web: uses Firebase Auth's `signInWithPopup` — no extra HTML meta tag
  /// or google_sign_in client ID required.
  /// On native: uses the google_sign_in package (SHA-1 fingerprint +
  /// google-services.json required for Android).
  Future<void> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Web: Firebase handles the OAuth popup internally.
        final credential = await _auth.signInWithPopup(GoogleAuthProvider());
        if (credential.user == null) throw AuthFailure.cancelled;
        return;
      }

      // Native: clear any stale Google session before presenting the picker.
      // This prevents DEVELOPER_ERROR / SecurityException ("Unknown calling
      // package") that occur when a previously-deleted account's OAuth token
      // is still cached locally.
      await _googleSignIn.signOut();

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw AuthFailure.cancelled;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _auth.signInWithCredential(credential);
    } on AuthFailure {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure.fromFirebaseCode(e.code);
    } catch (_) {
      throw AuthFailure.unknown;
    }
  }

  // ── Apple ───────────────────────────────────────────────────────────────────

  /// Opens the Apple ID sheet and exchanges the credential with Firebase.
  ///
  /// Prerequisites (iOS):
  ///   • "Sign In with Apple" capability added in Xcode.
  ///   • Apple provider enabled in Firebase Console → Authentication.
  ///   • Service ID configured in Apple Developer portal.
  ///
  /// A SHA-256 nonce is used to prevent replay attacks (Firebase requirement).
  Future<void> signInWithApple() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.iOS &&
            defaultTargetPlatform != TargetPlatform.macOS)) {
      throw AuthFailure.appleNotSupported;
    }
    try {
      final rawNonce = _generateNonce();
      final hashedNonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final oAuthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      await _auth.signInWithCredential(oAuthCredential);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) throw AuthFailure.cancelled;
      throw AuthFailure.fromFirebaseCode('invalid-credential');
    } on AuthFailure {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure.fromFirebaseCode(e.code);
    } catch (_) {
      throw AuthFailure.unknown;
    }
  }

  // ── Sign out ────────────────────────────────────────────────────────────────

  /// Signs out from Firebase and clears the cached Google account.
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      // google_sign_in is only initialized on native platforms; skip on web
      // to avoid an error when no google_sign_in session exists.
      if (!kIsWeb) {
        await _googleSignIn.signOut();
      }
    } catch (_) {
      throw AuthFailure.unknown;
    }
  }

  // ── Update name ─────────────────────────────────────────────────────────────

  /// Updates the user's display name in Firestore with a 14-day cooldown.
  ///
  /// Rules:
  ///   • If `lastNameChangeDate` is null (new account) → allow immediately.
  ///   • If `lastNameChangeDate` is set → require at least 14 days to pass.
  ///   • On success → writes `lastNameChangeDate: Timestamp.now()`.
  ///
  /// Throws [AuthFailure.nameCooldown] when the cooldown has not expired.
  Future<void> updateName(String name) async {
    final user = _auth.currentUser;
    if (user == null) throw AuthFailure.unknown;

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);

    try {
      final doc = await docRef.get();
      final lastChange = doc.data()?['lastNameChangeDate'] as Timestamp?;

      if (lastChange != null) {
        final daysSince =
            DateTime.now().difference(lastChange.toDate()).inDays;
        if (daysSince < 14) throw AuthFailure.nameCooldown;
      }

      await docRef.update({
        'name': name,
        'lastNameChangeDate': FieldValue.serverTimestamp(),
      });
    } on AuthFailure {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure.fromFirebaseCode(e.code);
    } catch (_) {
      throw AuthFailure.unknown;
    }
  }

  // ── Update care times ───────────────────────────────────────────────────────

  /// Persists [morningMinutes] and [eveningMinutes] in the user's Firestore
  /// document. Both values are total minutes from midnight
  /// (e.g. 08:00 = 480, 21:00 = 1260).
  Future<void> updateCareTimes({
    required int morningMinutes,
    required int eveningMinutes,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw AuthFailure.unknown;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
            'morningMinutes': morningMinutes,
            'eveningMinutes': eveningMinutes,
          });
    } on FirebaseAuthException catch (e) {
      throw AuthFailure.fromFirebaseCode(e.code);
    } catch (_) {
      throw AuthFailure.unknown;
    }
  }

  // ── Update goal ─────────────────────────────────────────────────────────────

  /// Writes [goal] and the derived [trackedMetrics] to the user's Firestore
  /// document atomically. Both fields are updated in a single call so the
  /// tracked-metric list is always consistent with the active goal.
  Future<void> updateGoal(String goal, List<String> trackedMetrics) async {
    final user = _auth.currentUser;
    if (user == null) throw AuthFailure.unknown;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
            'goal': goal,
            'trackedMetrics': trackedMetrics,
          });
    } on FirebaseAuthException catch (e) {
      throw AuthFailure.fromFirebaseCode(e.code);
    } catch (_) {
      throw AuthFailure.unknown;
    }
  }

  // ── Update skin type ────────────────────────────────────────────────────────

  /// Writes [skinType] to the current user's Firestore document.
  ///
  /// Firestore rules enforce: skinType in ['normal', 'dry', 'oily', 'combo'].
  /// Passing any other value will be rejected by the server.
  Future<void> updateSkinType(String skinType) async {
    final user = _auth.currentUser;
    if (user == null) throw AuthFailure.unknown;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'skinType': skinType});
    } on FirebaseAuthException catch (e) {
      throw AuthFailure.fromFirebaseCode(e.code);
    } catch (_) {
      throw AuthFailure.unknown;
    }
  }

  // ── Delete account ──────────────────────────────────────────────────────────

  /// Permanently removes the user's Firestore document and Firebase Auth record.
  ///
  /// Steps:
  ///   1. Delete `users/{uid}` from Firestore (while still authenticated).
  ///   2. Fully revoke the Google OAuth grant via disconnect(), then signOut().
  ///      This prevents DEVELOPER_ERROR / SecurityException on re-registration
  ///      caused by a zombie Google session after account deletion.
  ///   3. Call [User.delete] on the Firebase Auth user.
  ///   4. Sign out locally to ensure authStateChanges emits null immediately.
  ///
  /// Throws [AuthFailure.requiresRecentLogin] if the Firebase session is too
  /// old. The UI should prompt the user to sign in again and retry.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      // Step 1 — Remove the Firestore user document (requires active session).
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .delete();

      // Step 2 — Fully revoke Google OAuth grant so the next sign-in starts
      // completely fresh. disconnect() invalidates the server-side token;
      // signOut() clears the local cache. Both are no-ops for non-Google users.
      try {
        await _googleSignIn.disconnect();
      } catch (_) {
        // disconnect() can throw if there is no connected account — safe to ignore.
      }
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      // Step 3 — Permanently delete the Firebase Auth account.
      //   • Firebase SDK fires authStateChanges(null) upon success.
      //   • GoRouter's _GoRouterRefreshStream calls notifyListeners(), which
      //     re-evaluates the redirect and navigates to /login automatically.
      //   • Throws FirebaseAuthException(requires-recent-login) when the
      //     session is older than ~5 minutes → surfaced as requiresRecentLogin.
      await user.delete();

      // Step 4 — Belt-and-suspenders: explicitly clear local auth state so the
      // stream emits definitively even if the SDK defers the deletion event.
      await _auth.signOut();
    } on FirebaseAuthException catch (e) {
      // requires-recent-login is mapped to AuthFailure.requiresRecentLogin
      // inside fromFirebaseCode, so the UI can show a targeted prompt.
      throw AuthFailure.fromFirebaseCode(e.code);
    } catch (e) {
      if (e is AuthFailure) rethrow;
      throw AuthFailure.unknown;
    }
  }

  // ── Nonce helpers ───────────────────────────────────────────────────────────

  static String _generateNonce([int length = 32]) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._';
    final random = Random.secure();
    return List.generate(length, (_) => chars[random.nextInt(chars.length)])
        .join();
  }

  static String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
