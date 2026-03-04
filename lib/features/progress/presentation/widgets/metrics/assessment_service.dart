import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Handles saving daily skin assessments.
///
/// Intended call order (enforced by [AssessmentNotifier.submit]):
///   1. [uploadPhoto]       — upload the local file to Storage; returns the URL.
///   2. [saveMetrics]       — call the Gen-2 Cloud Function; returns dateKey.
///   3. [saveNoteAndPhoto]  — merge note + photoUrl into Firestore (merge:true).
///
/// Splitting upload and Firestore write gives the Cloud Function the correct
/// URL on first write and avoids a second round-trip later.
class AssessmentService {
  AssessmentService._();

  static final _functions =
      FirebaseFunctions.instanceFor(region: 'europe-west1');
  static final _firestore = FirebaseFirestore.instance;
  static final _storage = FirebaseStorage.instance;
  static final _auth = FirebaseAuth.instance;

  // ── Photo upload ──────────────────────────────────────────────────────────────

  /// Uploads [localPath] to `users/{uid}/assessments/{timestamp}.jpg` and
  /// returns the public download URL.
  ///
  /// Uses a millisecond timestamp as filename so multiple photos per day
  /// never collide with each other.
  ///
  /// Throws [FirebaseException] on permission or network errors.
  static Future<String> uploadPhoto(String localPath) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not signed in');

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ref = _storage.ref('users/$uid/assessments/$timestamp.jpg');

    // Await the full upload task; any Storage error surfaces here.
    final snapshot = await ref.putFile(File(localPath));
    return snapshot.ref.getDownloadURL();
  }

  // ── Metrics ───────────────────────────────────────────────────────────────────

  /// Calls the [saveDailyAssessment] Gen-2 callable Cloud Function and returns
  /// the [dateKey] (YYYY-MM-DD) computed for the user's local timezone.
  ///
  /// Only the 4 active metric keys should be passed; the function stores the
  /// remaining 8 as null automatically.
  static Future<String> saveMetrics({
    required String timezone,
    required Map<String, int> metrics,
  }) async {
    final result = await _functions
        .httpsCallable('saveDailyAssessment')
        .call(<String, dynamic>{
      'timezone': timezone,
      'metrics': metrics,
    });
    return result.data['dateKey'] as String;
  }

  // ── Note + photo URL ──────────────────────────────────────────────────────────

  /// Merges [note] and [photoUrl] into the existing daily assessment document.
  ///
  /// [photoUrl] must already be a Storage download URL (call [uploadPhoto]
  /// first). Uses [merge: true] so the CF-written metric fields are preserved.
  static Future<void> saveNoteAndPhoto({
    required String dateKey,
    required String note,
    String? photoUrl,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (note.isNotEmpty) updates['note'] = note;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('daily_assessments')
        .doc(dateKey)
        .set(updates, SetOptions(merge: true));
  }
}
