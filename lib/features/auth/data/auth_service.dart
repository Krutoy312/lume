import 'dart:convert';
import 'dart:io';
import 'dart:math';

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
  /// Prerequisites:
  ///   • SHA-1 fingerprint registered in Firebase Console → Project settings.
  ///   • `google-services.json` present in `android/app/` (already in project).
  Future<void> signInWithGoogle() async {
    try {
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
    if (!Platform.isIOS && !Platform.isMacOS) {
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

  // ── Anonymous ───────────────────────────────────────────────────────────────

  /// Signs in without any user identity.
  /// Firebase still fires `auth/user.onCreate`, so the CF creates a user doc.
  Future<void> signInAnonymously() async {
    try {
      await _auth.signInAnonymously();
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
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (_) {
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
