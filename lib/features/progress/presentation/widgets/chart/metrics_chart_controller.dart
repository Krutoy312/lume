import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../metrics/tracked_metrics_provider.dart';

/// Available period options in days.
const kChartPeriods = [7, 30, 90];

// ─── State ────────────────────────────────────────────────────────────────────

class ChartState {
  const ChartState({
    required this.selectedMetricKey,
    required this.selectedPeriod,
    required this.spots,
    this.trendPercent,
    this.dataState = const AsyncData(null),
  });

  final String selectedMetricKey;
  final int selectedPeriod;

  /// Spots for the selected metric and period.  X = day index (0 = oldest day),
  /// Y = metric value (1–10).
  final List<FlSpot> spots;

  /// Trend = (last − first) / first × 100.  Null when fewer than 2 data points.
  final double? trendPercent;

  /// Tracks the async Firestore fetch.
  final AsyncValue<void> dataState;

  bool get isLoading => dataState is AsyncLoading;
  bool get hasError => dataState is AsyncError;

  /// `true` when trend is positive (≥ 0).
  bool get trendPositive => (trendPercent ?? 0) >= 0;

  ChartState copyWith({
    String? selectedMetricKey,
    int? selectedPeriod,
    List<FlSpot>? spots,
    double? trendPercent,
    bool clearTrend = false,
    AsyncValue<void>? dataState,
  }) =>
      ChartState(
        selectedMetricKey: selectedMetricKey ?? this.selectedMetricKey,
        selectedPeriod: selectedPeriod ?? this.selectedPeriod,
        spots: spots ?? this.spots,
        trendPercent: clearTrend ? null : (trendPercent ?? this.trendPercent),
        dataState: dataState ?? this.dataState,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class MetricsChartNotifier extends StateNotifier<ChartState> {
  MetricsChartNotifier(String initialKey)
      : super(ChartState(
          selectedMetricKey: initialKey,
          selectedPeriod: 7,
          spots: const [],
        )) {
    fetch();
  }

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // ── Public actions ────────────────────────────────────────────────────────

  void selectMetric(String key) {
    if (state.selectedMetricKey == key) return;
    state = state.copyWith(selectedMetricKey: key);
    fetch();
  }

  void selectPeriod(int days) {
    if (state.selectedPeriod == days) return;
    state = state.copyWith(selectedPeriod: days);
    fetch();
  }

  // ── Data fetch ────────────────────────────────────────────────────────────

  Future<void> fetch() async {
    state = state.copyWith(dataState: const AsyncLoading());
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        state = state.copyWith(
          spots: const [],
          clearTrend: true,
          dataState: const AsyncData(null),
        );
        return;
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final cutoff = today.subtract(Duration(days: state.selectedPeriod - 1));

      // Local helper — converts a DateTime to a "YYYY-MM-DD" Firestore key.
      String toKey(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}'
          '-${d.month.toString().padLeft(2, '0')}'
          '-${d.day.toString().padLeft(2, '0')}';

      final firstKey = toKey(cutoff);
      final lastKey = toKey(today);

      // Fetch all assessment documents in the date range, ordered by date.
      final snap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('daily_assessments')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: firstKey)
          .where(FieldPath.documentId, isLessThanOrEqualTo: lastKey)
          .orderBy(FieldPath.documentId)
          .get();

      // Build FlSpot list.  X = days since cutoff (0 … period−1).
      final spots = <FlSpot>[];
      for (final doc in snap.docs) {
        final docDate = DateTime.parse(doc.id);
        final dayIndex = docDate.difference(cutoff).inDays.toDouble();
        final metrics =
            (doc.data()['metrics'] as Map<String, dynamic>?) ?? const {};
        final val = (metrics[state.selectedMetricKey] as num?)?.toDouble();
        if (val != null) {
          spots.add(FlSpot(dayIndex, val.clamp(0.0, 10.0)));
        }
      }

      // Calculate trend %.
      double? trend;
      if (spots.length >= 2) {
        final first = spots.first.y;
        final last = spots.last.y;
        if (first != 0) {
          trend = (last - first) / first * 100;
        }
      }

      state = state.copyWith(
        spots: spots,
        trendPercent: trend,
        clearTrend: trend == null,
        dataState: const AsyncData(null),
      );
    } catch (e) {
      state = state.copyWith(
        dataState: AsyncError(e, StackTrace.current),
      );
    }
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

/// `ref.read` (not watch) so the notifier is NOT recreated when the tracked
/// metrics list updates mid-session.
final metricsChartProvider =
    StateNotifierProvider.autoDispose<MetricsChartNotifier, ChartState>((ref) {
  final tracked = ref.read(trackedMetricsProvider);
  final initialKey = tracked.isNotEmpty ? tracked.first : 'sebumBalance';
  return MetricsChartNotifier(initialKey);
});
