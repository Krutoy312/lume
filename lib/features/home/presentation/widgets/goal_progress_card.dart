import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../progress/presentation/widgets/metrics/assessment_provider.dart';
import '../../../progress/presentation/widgets/metrics/tracked_metrics_provider.dart';
import '../../../settings/presentation/widgets/goal_bottom_sheet.dart';

class GoalProgressCard extends ConsumerWidget {
  const GoalProgressCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = MediaQuery.sizeOf(context).width;
    final hPad = w * 0.051;

    final docAsync = ref.watch(userDocumentProvider);
    final assessmentsAsync = ref.watch(recentAssessmentMetricsProvider);

    final docData = docAsync.valueOrNull?.data();
    final goal = docData?['goal'] as String?;
    final trackedMetrics =
        (docData?['trackedMetrics'] as List<dynamic>?)?.cast<String>() ??
            kDefaultTrackedKeys;

    final mandatoryMetrics = mandatoryMetricsForGoal(goal);
    final metricsForProgress =
        mandatoryMetrics.isEmpty ? trackedMetrics : mandatoryMetrics;

    final recentAssessments = assessmentsAsync.valueOrNull ?? [];
    final latestMetrics = recentAssessments.isNotEmpty ? recentAssessments[0] : null;
    final prevMetrics = recentAssessments.length > 1 ? recentAssessments[1] : null;

    final progressValue = _computeProgress(latestMetrics, metricsForProgress);
    final adviceText = _buildAdviceText(latestMetrics, prevMetrics, metricsForProgress);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: hPad),
      padding: EdgeInsets.fromLTRB(w * 0.061, w * 0.056, w * 0.061, w * 0.061),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Цель:',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.primaryLight,
              fontWeight: FontWeight.w300,
            ),
          ),
          SizedBox(height: w * 0.046),
          Text(
            goalLabel(goal) ?? 'Выберите цель',
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: w * 0.041),
          // Progress bar track + fill
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            child: Stack(
              children: [
                Container(
                  height: 12,
                  decoration: const BoxDecoration(
                    color: AppColors.progressBarBack,
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: progressValue,
                  child: Container(
                    height: 12,
                    decoration: const BoxDecoration(
                      gradient: AppColors.progressBarGradient,
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: w * 0.013),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Прогресс:',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.primaryMedium,
                ),
              ),
              Text(
                '${(progressValue * 100).round()}%',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.primaryMedium,
                ),
              ),
            ],
          ),
          SizedBox(height: w * 0.051),
          // Advice lamp card
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: w * 0.038,
              vertical: w * 0,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-1.0, 0.0),
                end: Alignment(1.0, 0.0),
                stops: [0.092, 0.908],
                colors: [AppColors.adviceLampStart, AppColors.adviceLampEnd],
              ),
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset(
                    'assets/images/img_light_bulb.png',
                    width: w * 0.17,
                    fit: BoxFit.contain,
                  ),
                  SizedBox(width: w * 0.02),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _AdviceText(text: adviceText, w: w),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Computes the progress bar value (0.0–1.0) from the given metric values.
  ///
  /// Returns the average of [metricsToTrack] divided by 10.
  static double _computeProgress(
    Map<String, int>? latestMetrics,
    List<String> metricsToTrack,
  ) {
    if (latestMetrics == null || metricsToTrack.isEmpty) return 0.0;

    var sum = 0;
    var count = 0;
    for (final key in metricsToTrack) {
      final val = latestMetrics[key];
      if (val != null) {
        sum += val;
        count++;
      }
    }

    if (count == 0) return 0.0;
    return (sum / count / 10).clamp(0.0, 1.0);
  }

  /// Builds the advice lamp text by comparing the last two assessments.
  ///
  /// • No assessments → prompt to start assessing
  /// • One assessment → "Вы на правильном пути!"
  /// • Two+ assessments → compares [metricsToCompare], cycles daily
  static String _buildAdviceText(
    Map<String, int>? latest,
    Map<String, int>? prev,
    List<String> metricsToCompare,
  ) {
    if (latest == null || metricsToCompare.isEmpty) {
      return 'Начните оценивать свою кожу';
    }

    if (prev == null) {
      return 'Вы на правильном пути!';
    }

    // Collect metrics that changed between the two assessments.
    final changes = <(String, int, int)>[];
    for (final key in metricsToCompare) {
      final newVal = latest[key] ?? 0;
      final oldVal = prev[key] ?? 0;
      if (newVal != oldVal) {
        changes.add((key, oldVal, newVal));
      }
    }

    if (changes.isEmpty) {
      return 'Вы на правильном пути!';
    }

    // Cycle through changed metrics daily.
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year)).inDays;
    final (key, oldVal, newVal) = changes[dayOfYear % changes.length];
    final label = _metricLabel(key);

    if (newVal > oldVal) {
      return '$label увеличился с $oldVal до $newVal';
    } else {
      return '$label снизился с $oldVal до $newVal';
    }
  }

  static String _metricLabel(String key) {
    try {
      return kAllMetrics.firstWhere((m) => m.key == key).label;
    } catch (_) {
      return key;
    }
  }
}

// ── Advice text ────────────────────────────────────────────────────────────────

class _AdviceText extends StatelessWidget {
  const _AdviceText({required this.text, required this.w});

  final String text;
  final double w;

  @override
  Widget build(BuildContext context) {
    // Split into bold header (first sentence) + lighter body (rest).
    final parts = text.split('\n');
    if (parts.length == 1) {
      return Text(
        text,
        textAlign: TextAlign.right,
        style: TextStyle(
          fontFamily: 'SF Pro',
          fontSize: w * 0.031,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF6B5446),
          letterSpacing: -0.4,
          height: 1.35,
        ),
      );
    }

    return RichText(
      textAlign: TextAlign.right,
      text: TextSpan(
        children: [
          TextSpan(
            text: '${parts[0]}\n',
            style: TextStyle(
              fontFamily: 'SF Pro',
              fontSize: w * 0.031,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF6B5446),
              letterSpacing: -0.5,
            ),
          ),
          TextSpan(
            text: parts.sublist(1).join('\n'),
            style: TextStyle(
              fontFamily: 'SF Pro',
              fontSize: w * 0.031,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF6B5446),
            ),
          ),
        ],
      ),
    );
  }
}
