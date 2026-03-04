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
