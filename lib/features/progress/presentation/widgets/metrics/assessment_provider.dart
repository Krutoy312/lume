import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'assessment_service.dart';

// ─── Metric metadata ──────────────────────────────────────────────────────────

class MetricMeta {
  const MetricMeta({
    required this.key,
    required this.label,
    required this.iconPath,
  });

  final String key;
  final String label;
  final String iconPath;
}

/// Full pool of 7 trackable metrics (camelCase keys, matching Firestore + CF).
/// Icons are verified present in assets/icons/.
const kAllMetrics = [
  MetricMeta(
    key: 'sebumBalance',
    label: 'Баланс себума',
    iconPath: 'assets/icons/ic_sebum_balance.svg',
  ),
  MetricMeta(
    key: 'elasticity',
    label: 'Эластичность',
    iconPath: 'assets/icons/ic_elasticity.svg',
  ),
  MetricMeta(
    key: 'hydration',
    label: 'Увлажнённость',
    iconPath: 'assets/icons/ic_hydration.svg',
  ),
  MetricMeta(
    key: 'smoothness',
    label: 'Гладкость',
    iconPath: 'assets/icons/ic_smoothness.svg',
  ),
  MetricMeta(
    key: 'skinClarity',
    label: 'Чистота кожи',
    iconPath: 'assets/icons/ic_skin_clarity.svg',
  ),
  MetricMeta(
    key: 'porePurity',
    label: 'Чистота пор',
    iconPath: 'assets/icons/ic_pore_purity.svg',
  ),
  MetricMeta(
    key: 'evenTone',
    label: 'Ровный тон',
    iconPath: 'assets/icons/ic_even_tone.svg',
  ),
];

// ─── State ────────────────────────────────────────────────────────────────────

class AssessmentState {
  const AssessmentState({
    required this.metrics,
    this.photo,
    this.photoUrl,
    this.note = '',
    this.submissionState = const AsyncData(null),
    this.loadState = const AsyncData(null),
    this.existsToday = false,
  });

  /// All 7 metric values (keys from [kAllMetrics]) initialised to 5.0.
  factory AssessmentState.initial() => AssessmentState(
        metrics: {for (final m in kAllMetrics) m.key: 5.0},
      );

  /// Current slider values keyed by [MetricMeta.key] for all 7 metrics.
  final Map<String, double> metrics;

  /// Locally picked photo file (takes display priority over [photoUrl]).
  final XFile? photo;

  /// Network photo URL loaded from Firestore (shown when [photo] is null).
  final String? photoUrl;

  final String note;

  /// Tracks the Cloud Function + Firestore write in [AssessmentNotifier.submit].
  final AsyncValue<void> submissionState;

  /// Tracks the initial Firestore read in [AssessmentNotifier.load].
  final AsyncValue<void> loadState;

  /// `true` once [load] confirms a document exists for today.
  final bool existsToday;

  bool get isLoading => submissionState is AsyncLoading;
  bool get isLoadingData => loadState is AsyncLoading;
  bool get hasLoadError => loadState is AsyncError;

  /// Whether any photo (local or network) is present.
  bool get hasPhoto => photo != null || photoUrl != null;

  AssessmentState _copy({
    Map<String, double>? metrics,
    bool clearPhoto = false,
    XFile? newPhoto,
    bool clearPhotoUrl = false,
    String? newPhotoUrl,
    String? note,
    AsyncValue<void>? submissionState,
    AsyncValue<void>? loadState,
    bool? existsToday,
  }) =>
      AssessmentState(
        metrics: metrics ?? this.metrics,
        photo: clearPhoto ? null : (newPhoto ?? photo),
        photoUrl: clearPhotoUrl ? null : (newPhotoUrl ?? photoUrl),
        note: note ?? this.note,
        submissionState: submissionState ?? this.submissionState,
        loadState: loadState ?? this.loadState,
        existsToday: existsToday ?? this.existsToday,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class AssessmentNotifier extends StateNotifier<AssessmentState> {
  AssessmentNotifier() : super(AssessmentState.initial());

  // ── Individual field setters ───────────────────────────────────────────────

  void setMetric(String key, double value) {
    state = state._copy(metrics: {...state.metrics, key: value});
  }

  void setPhoto(XFile? photo) {
    if (photo == null) {
      state = state._copy(clearPhoto: true);
    } else {
      state = state._copy(newPhoto: photo);
    }
  }

  /// Clears both the local picked file and the Firestore network URL so the
  /// photo slot is fully empty.
  void removePhoto() {
    state = state._copy(clearPhoto: true, clearPhotoUrl: true);
  }

  void setNote(String note) => state = state._copy(note: note);

  // ── Load today's data from Firestore ──────────────────────────────────────

  /// Reads today's assessment document.  Populates slider values, note, and
  /// network photo URL if the document exists.  The UI uses [loadState] to
  /// decide whether to show a loading skeleton.
  Future<void> load() async {
    state = state._copy(loadState: const AsyncLoading());
    try {
      final data = await AssessmentService.fetchTodayAssessment();

      if (data == null) {
        state = state._copy(
          loadState: const AsyncData(null),
          existsToday: false,
        );
        return;
      }

      // The CF stores metric values under a nested 'metrics' sub-map.
      final rawMetrics =
          (data['metrics'] as Map<String, dynamic>?) ?? <String, dynamic>{};

      // ignore: avoid_print
      print('[AssessmentProvider] rawMetrics from Firestore: $rawMetrics');

      // Merge fetched values into current state — unset keys stay at 5.0.
      final metrics = <String, double>{
        for (final m in kAllMetrics)
          m.key: (rawMetrics[m.key] as num?)?.toDouble() ?? 5.0,
      };

      state = state._copy(
        loadState: const AsyncData(null),
        existsToday: true,
        metrics: metrics,
        note: (data['note'] as String?) ?? '',
        newPhotoUrl: data['photoUrl'] as String?,
      );
    } catch (e) {
      state = state._copy(
        loadState: AsyncError(e, StackTrace.current),
      );
    }
  }

  // ── Submit (create or update) ─────────────────────────────────────────────

  /// Saves the assessment.
  ///
  /// Only the [trackedKeys] subset of [state.metrics] is sent to the Cloud
  /// Function — untracked metrics are not written, preserving any previously
  /// saved values for those keys in Firestore.
  Future<void> submit({
    required String timezone,
    required List<String> trackedKeys,
    required void Function(String dateKey) onSuccess,
    required void Function(String error) onError,
  }) async {
    state = state._copy(submissionState: const AsyncLoading());
    try {
      // Step 1: Upload photo first so the URL is ready before the CF call.
      String? photoUrl;
      if (state.photo != null) {
        photoUrl = await AssessmentService.uploadPhoto(state.photo!.path);
      }

      // Step 2: Call the Cloud Function with only the tracked metrics.
      final metricsInt = Map.fromEntries(
        state.metrics.entries
            .where((e) => trackedKeys.contains(e.key))
            .map((e) => MapEntry(e.key, e.value.round())),
      );
      final dateKey = await AssessmentService.saveMetrics(
        timezone: timezone,
        metrics: metricsInt,
      );

      // Step 3: Merge note and the already-uploaded photo URL into the doc.
      await AssessmentService.saveNoteAndPhoto(
        dateKey: dateKey,
        note: state.note,
        photoUrl: photoUrl,
      );

      state = state._copy(submissionState: const AsyncData(null));
      onSuccess(dateKey);
    } catch (e) {
      state = state._copy(
        submissionState: AsyncError(e, StackTrace.current),
      );
      onError(e.toString());
    }
  }

  void clearSubmissionError() =>
      state = state._copy(submissionState: const AsyncData(null));

  void reset() => state = AssessmentState.initial();
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final assessmentProvider =
    StateNotifierProvider.autoDispose<AssessmentNotifier, AssessmentState>(
  (_) => AssessmentNotifier(),
);
