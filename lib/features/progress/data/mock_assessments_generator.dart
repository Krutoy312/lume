// ignore_for_file: avoid_print
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// TEMPORARY dev utility — generates 90 days of mock assessment data.
///
/// Writes directly to `users/{uid}/daily_assessments/{dateKey}` using
/// the same field schema as the [saveDailyAssessment] Cloud Function:
///
///   { dateKey, metrics: { sebumBalance, elasticity, … }, updatedAt }
///
/// Each metric follows a sine wave (random phase + amplitude) layered
/// over a slow upward trend with mild per-day noise, so charts show
/// realistic "waves" rather than flat lines.
///
/// Safe to run multiple times — Firestore `set()` overwrites existing docs.
///
/// REMOVE this file and its UI trigger before production release.
Future<void> generateMockAssessments() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    print('[MockData] ✗ No user signed in — aborting.');
    return;
  }

  final firestore = FirebaseFirestore.instance;
  final rng = Random();

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  const metricKeys = [
    'sebumBalance',
    'elasticity',
    'hydration',
    'smoothness',
    'skinClarity',
    'porePurity',
    'evenTone',
  ];

  // Per-metric wave parameters — randomised once per run.
  final baseline  = { for (final k in metricKeys) k: 4.5 + rng.nextDouble() * 2.5 };
  final amplitude = { for (final k in metricKeys) k: 0.6 + rng.nextDouble() * 1.4 };
  final phase     = { for (final k in metricKeys) k: rng.nextDouble() * 2 * pi };
  // Trend: some metrics improve (+), some stay flat, a few decline.
  final trend     = { for (final k in metricKeys) k: (rng.nextDouble() * 2.4) - 0.8 };

  // Batches are limited to 500 ops; 90 docs × 1 write each is well within.
  final batch = firestore.batch();

  for (var day = 89; day >= 0; day--) {
    final date = today.subtract(Duration(days: day));
    final dateKey =
        '${date.year.toString().padLeft(4, '0')}'
        '-${date.month.toString().padLeft(2, '0')}'
        '-${date.day.toString().padLeft(2, '0')}';

    // t: 0.0 (oldest day, 89 days ago) → 1.0 (today)
    final t = (89 - day) / 89.0;

    final metrics = <String, int>{};
    for (final key in metricKeys) {
      final wave = amplitude[key]! * sin(phase[key]! + t * 4 * pi);
      final trendDelta = trend[key]! * t;
      final noise = (rng.nextDouble() - 0.5) * 0.8;

      final raw = baseline[key]! + wave + trendDelta + noise;
      metrics[key] = raw.clamp(3.0, 9.0).round();
    }

    final ref = firestore
        .collection('users')
        .doc(uid)
        .collection('daily_assessments')
        .doc(dateKey);

    // Mirror exactly what saveDailyAssessment CF writes (merge:true preserves
    // any note / photoUrl already on the document).
    batch.set(
      ref,
      {
        'dateKey': dateKey,
        'metrics': metrics,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  await batch.commit();
  print('[MockData] ✓ 90 days of data generated for uid: $uid');
}
