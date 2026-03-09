import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

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
    final bytes = await XFile(localPath).readAsBytes();
    final snapshot = await ref.putData(bytes);
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

  // ── Fetch today ───────────────────────────────────────────────────────────────

  /// Returns the raw Firestore document data for today's assessment, or `null`
  /// if no document exists yet.
  ///
  /// Uses `DateTime.now()` (local time) to derive the dateKey, which matches
  /// the key the Cloud Function computes when given the same local timezone.
  static Future<Map<String, dynamic>?> fetchTodayAssessment() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final now = DateTime.now();
    final dateKey = '${now.year.toString().padLeft(4, '0')}'
        '-${now.month.toString().padLeft(2, '0')}'
        '-${now.day.toString().padLeft(2, '0')}';

    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('daily_assessments')
        .doc(dateKey)
        .get();

    if (!doc.exists || doc.data() == null) return null;
    final data = doc.data()!;
    // ignore: avoid_print
    print('[AssessmentService] fetchTodayAssessment($dateKey): $data');
    return data;
  }

  // ── Tracked metrics ───────────────────────────────────────────────────────────

  /// Persists [keys] as the user's active tracked-metric list in their profile.
  ///
  /// The change is picked up in real time by [userDocumentProvider], which
  /// updates [trackedMetricsProvider] and causes the slider list to rebuild.
  static Future<void> saveTrackedMetrics(List<String> keys) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _firestore
        .collection('users')
        .doc(uid)
        .update({'trackedMetrics': keys});
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
