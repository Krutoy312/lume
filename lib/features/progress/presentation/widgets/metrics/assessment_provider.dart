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
    this.note = '',
    this.submissionState = const AsyncData(null),
  });

  factory AssessmentState.initial() => AssessmentState(
        metrics: {for (final m in kDefaultMetrics) m.key: 5.0},
      );

  final Map<String, double> metrics;
  final XFile? photo;
  final String note;
  final AsyncValue<void> submissionState;

  bool get isLoading => submissionState is AsyncLoading;

  AssessmentState _copy({
    Map<String, double>? metrics,
    bool clearPhoto = false,
    XFile? newPhoto,
    String? note,
    AsyncValue<void>? submissionState,
  }) =>
      AssessmentState(
        metrics: metrics ?? this.metrics,
        photo: clearPhoto ? null : (newPhoto ?? photo),
        note: note ?? this.note,
        submissionState: submissionState ?? this.submissionState,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class AssessmentNotifier extends StateNotifier<AssessmentState> {
  AssessmentNotifier() : super(AssessmentState.initial());

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

  void setNote(String note) => state = state._copy(note: note);

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

  /// Resets the entire form back to its initial state (called after a
  /// successful submission so the user can fill in tomorrow's assessment).
  void reset() => state = AssessmentState.initial();
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final assessmentProvider =
    StateNotifierProvider.autoDispose<AssessmentNotifier, AssessmentState>(
  (_) => AssessmentNotifier(),
);
