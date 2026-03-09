import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skin_care_app/features/auth/presentation/providers/auth_provider.dart';

/// The 4 metric keys tracked by default for new users (matches DEFAULT_USER
/// in the Cloud Function and the `initUserDocument` auth trigger).
const kDefaultTrackedKeys = [
  'sebumBalance',
  'skinClarity',
  'hydration',
  'porePurity',
];

/// Returns the 4 mandatory metric keys for a given [goal] value.
///
/// These metrics cannot be removed from tracking while the goal is active.
List<String> mandatoryMetricsForGoal(String? goal) {
  switch (goal) {
    case 'clear_skin':
      return ['skinClarity', 'porePurity', 'sebumBalance', 'smoothness'];
    case 'oil_control':
      return ['sebumBalance', 'porePurity', 'hydration', 'skinClarity'];
    case 'hydration_balance':
      return ['hydration', 'elasticity', 'evenTone', 'smoothness'];
    case 'texture':
      return ['smoothness', 'skinClarity', 'hydration', 'porePurity'];
    case 'firmness':
      return ['elasticity', 'evenTone', 'hydration', 'smoothness'];
    case 'maintenance':
      return [];
    default:
      return kDefaultTrackedKeys;
  }
}

/// Derives the user's active tracked-metric keys from their Firestore profile
/// document in real time.
///
/// Used by [DailyAssessmentSection] to decide which sliders to render, and
/// which metric values to include in the Cloud Function call on submit.
///
/// Falls back to [kDefaultTrackedKeys] while the document is loading, on
/// error, or when the field is absent (e.g. legacy accounts pre-migration).
final trackedMetricsProvider = Provider<List<String>>((ref) {
  final docAsync = ref.watch(userDocumentProvider);
  return docAsync.when(
    data: (snap) {
      final raw = snap?.data()?['trackedMetrics'] as List<dynamic>?;
      if (raw == null || raw.isEmpty) return kDefaultTrackedKeys;
      return raw.cast<String>();
    },
    loading: () => kDefaultTrackedKeys,
    error: (_, __) => kDefaultTrackedKeys,
  );
});

/// Returns the metric maps of the [_kAssessmentLimit] most recent assessments,
/// ordered newest-first.
///
/// Each element is a `Map<String, int>` of metric key → value (0–10).
/// The list may have 0, 1, or 2 elements depending on how many assessments
/// the user has submitted.
///
/// Index 0 = most recent, index 1 = second most recent.
const _kAssessmentLimit = 2;

final recentAssessmentMetricsProvider =
    FutureProvider.autoDispose<List<Map<String, int>>>((ref) async {
  // Re-fetch when the user document changes (e.g. after a new submission).
  ref.watch(userDocumentProvider);

  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return [];

  final snap = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('daily_assessments')
      .orderBy(FieldPath.documentId, descending: true)
      .limit(_kAssessmentLimit)
      .get();

  return snap.docs.map((doc) {
    final raw =
        (doc.data()['metrics'] as Map<String, dynamic>?) ?? {};
    return raw.map((k, v) => MapEntry(k, (v as num).toInt()));
  }).toList();
});

/// The set of metric keys that are mandatory for the user's current goal.
///
/// Used by [ChangeMetricsBottomSheet] to prevent the user from disabling
/// metrics that are required to track their selected goal.
final mandatoryMetricsProvider = Provider<Set<String>>((ref) {
  final docAsync = ref.watch(userDocumentProvider);
  return docAsync.when(
    data: (snap) {
      final goal = snap?.data()?['goal'] as String?;
      return Set<String>.from(mandatoryMetricsForGoal(goal));
    },
    loading: () => Set<String>.from(kDefaultTrackedKeys),
    error: (_, __) => const {},
  );
});
