import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Saves the completed onboarding profile to the user's Firestore document.
///
/// Called once when the user finishes the 7-step quiz.
/// Sets [onboardingCompleted] to `true` so subsequent launches skip the quiz.
class OnboardingService {
  OnboardingService._();

  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static Future<void> saveProfile({
    required String skinType,
    required String goal,
    required DateTime birthDate,
    required String gender,
    required List<String> trackedMetrics,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not signed in');

    await _firestore.collection('users').doc(uid).set(
      {
        'skinType': skinType,
        'goal': goal,
        'birthDate': Timestamp.fromDate(birthDate),
        'gender': gender,
        'trackedMetrics': trackedMetrics,
        'onboardingCompleted': true,
      },
      SetOptions(merge: true),
    );
  }
}
