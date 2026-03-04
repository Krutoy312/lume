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

/// The 4 default active metrics shown in the assessment screen.
const kDefaultMetrics = [
  MetricMeta(
    key: 'matte',
    label: 'Матовость',
    iconPath: 'assets/icons/ic_haze.svg',
  ),
  MetricMeta(
    key: 'richness',
    label: 'Насыщенность',
    iconPath: 'assets/icons/ic_saturation.svg',
  ),
  MetricMeta(
    key: 'hydration',
    label: 'Увлажнённость',
    iconPath: 'assets/icons/ic_moisture.svg',
  ),
  MetricMeta(
    key: 'comfort',
    label: 'Комфорт',
    iconPath: 'assets/icons/ic_comfort.svg',
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

  factory AssessmentState.initial() => AssessmentState(
        metrics: {for (final m in kDefaultMetrics) m.key: 5.0},
      );

  /// Current slider values keyed by [MetricMeta.key].
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
        // No document for today — start fresh.
        state = state._copy(
          loadState: const AsyncData(null),
          existsToday: false,
        );
        return;
      }

      // The Cloud Function nests all metric values under a 'metrics' sub-map:
      //   { dateKey, metrics: { matte: 7, richness: 8, … }, note, photoUrl }
      // Reading from the top-level data map would always return null and fall
      // back to the default 5.0, which is the bug that kept sliders at default.
      final rawMetrics =
          (data['metrics'] as Map<String, dynamic>?) ?? <String, dynamic>{};

      // ignore: avoid_print
      print('[AssessmentProvider] rawMetrics from Firestore: $rawMetrics');

      // Cast every value to double — Firestore returns integers for whole
      // numbers, so (num?)?.toDouble() handles both int and double safely.
      final metrics = <String, double>{
        for (final m in kDefaultMetrics)
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

  Future<void> submit({
    required String timezone,
    required void Function(String dateKey) onSuccess,
    required void Function(String error) onError,
  }) async {
    // Set loading immediately — the Submit button shows CircularProgressIndicator
    // for the entire operation, including the photo upload phase.
    state = state._copy(submissionState: const AsyncLoading());
    try {
      // Step 1: Upload photo first so the URL is ready before the CF call.
      String? photoUrl;
      if (state.photo != null) {
        photoUrl = await AssessmentService.uploadPhoto(state.photo!.path);
      }

      // Step 2: Call the Cloud Function — creates/updates the assessment doc
      //         and returns the server-computed dateKey.
      final metricsInt = state.metrics.map(
        (k, v) => MapEntry(k, v.round()),
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

  /// Resets the entire form back to its initial state.
  void reset() => state = AssessmentState.initial();
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final assessmentProvider =
    StateNotifierProvider.autoDispose<AssessmentNotifier, AssessmentState>(
  (_) => AssessmentNotifier(),
);
