import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../progress/presentation/widgets/metrics/assessment_provider.dart';
import '../../../progress/presentation/widgets/metrics/tracked_metrics_provider.dart';

class SkinMetricsGrid extends ConsumerWidget {
  const SkinMetricsGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = MediaQuery.sizeOf(context).width;
    final hPad = w * 0.051;
    final gap = w * 0.030;

    final trackedKeys = ref.watch(trackedMetricsProvider);
    final assessmentsAsync = ref.watch(recentAssessmentMetricsProvider);
    final latestMetrics = assessmentsAsync.valueOrNull?.isNotEmpty == true
        ? assessmentsAsync.valueOrNull!.first
        : null;

    // Show up to 4 tracked metrics in the grid.
    final displayKeys = trackedKeys.take(4).toList();
    final displayMetas = displayKeys.map((key) {
      try {
        return kAllMetrics.firstWhere((m) => m.key == key);
      } catch (_) {
        return null;
      }
    }).whereType<MetricMeta>().toList();

    // Pad to at least 2 items for the grid layout.
    while (displayMetas.length < 2) {
      displayMetas.add(kAllMetrics.first);
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Показатели кожи',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.primaryLight,
              fontWeight: FontWeight.w300,
            ),
          ),
          SizedBox(height: w * 0.030),
          // Row 1
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  meta: displayMetas[0],
                  value: latestMetrics?[displayMetas[0].key],
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                child: _MetricCard(
                  meta: displayMetas[1],
                  value: latestMetrics?[displayMetas[1].key],
                ),
              ),
            ],
          ),
          if (displayMetas.length > 2) ...[
            SizedBox(height: gap),
            // Row 2
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    meta: displayMetas[2],
                    value: latestMetrics?[displayMetas[2].key],
                  ),
                ),
                SizedBox(width: gap),
                Expanded(
                  child: displayMetas.length > 3
                      ? _MetricCard(
                          meta: displayMetas[3],
                          value: latestMetrics?[displayMetas[3].key],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.meta, required this.value});

  final MetricMeta meta;
  final int? value;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final cardPad = w * 0.046;
    final displayValue = value ?? 0;
    final widthFactor = (displayValue / 10).clamp(0.0, 1.0);

    return Container(
      height: w * 0.351,
      padding: EdgeInsets.fromLTRB(cardPad, w * 0.036, cardPad, w * 0.036),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SvgPicture.asset(
            meta.iconPath,
            width: w * 0.046,
            height: w * 0.046,
          ),
          const Spacer(),
          Text(
            meta.label,
            style: AppTextStyles.labelMedium.copyWith(
              fontWeight: FontWeight.w500,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: w * 0.028),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value != null ? '$displayValue' : '—',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(width: w * 0.008),
              Text(
                '/10',
                style: AppTextStyles.labelSmall.copyWith(
                  fontSize: 12,
                  color: AppColors.primaryLight,
                ),
              ),
            ],
          ),
          SizedBox(height: w * 0.020),
          // Mini progress bar
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            child: Stack(
              children: [
                Container(
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.progressBarBack,
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: value != null ? widthFactor : 0,
                  child: Container(
                    height: 7,
                    decoration: const BoxDecoration(
                      gradient: AppColors.metricsGradient,
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
