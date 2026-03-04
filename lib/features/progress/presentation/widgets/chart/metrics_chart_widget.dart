import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../metrics/assessment_provider.dart';
import '../metrics/tracked_metrics_provider.dart';
import 'chart_view.dart';
import 'metric_toggle_chips.dart';
import 'metrics_chart_controller.dart';
import 'metrics_period_selector.dart';

/// White card widget displaying a line chart for a single metric with:
/// - Period selector (7д / 30д / 90д)
/// - Trend badge (+18% / −5%)
/// - Smooth fl_chart line with gradient fill
/// - Metric chip grid for switching the tracked metric
///
/// Integrates with [metricsChartProvider] for data and [trackedMetricsProvider]
/// for the list of active metric keys.
class MetricsChartWidget extends ConsumerWidget {
  const MetricsChartWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = MediaQuery.sizeOf(context).width;
    final chartState = ref.watch(metricsChartProvider);
    final notifier = ref.read(metricsChartProvider.notifier);
    final trackedKeys = ref.watch(trackedMetricsProvider);

    final selectedMeta = kAllMetrics
        .where((m) => m.key == chartState.selectedMetricKey)
        .firstOrNull;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(w * 0.051),
      ),
      padding: EdgeInsets.fromLTRB(
        w * 0.051,
        w * 0.046,
        w * 0.051,
        w * 0.046,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: metric title + period pill ───────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  selectedMeta?.label ?? '',
                  style: const TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                    letterSpacing: -0.45,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              MetricsPeriodSelector(
                selectedPeriod: chartState.selectedPeriod,
                onChanged: notifier.selectPeriod,
              ),
            ],
          ),

          SizedBox(height: w * 0.038),

          // ── Trend badge ───────────────────────────────────────────────────
          _TrendBadge(
            trendPercent: chartState.trendPercent,
            trendPositive: chartState.trendPositive,
          ),

          SizedBox(height: w * 0.038),

          // ── Line chart ────────────────────────────────────────────────────
          SizedBox(
            height: w * 0.460,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: child,
              ),
              child: _buildChartBody(chartState, w),
            ),
          ),

          SizedBox(height: w * 0.046),

          // ── Metric chips ──────────────────────────────────────────────────
          MetricToggleChips(
            trackedKeys: trackedKeys,
            selectedKey: chartState.selectedMetricKey,
            onSelected: notifier.selectMetric,
          ),

          SizedBox(height: w * 0.020),
        ],
      ),
    );
  }

  Widget _buildChartBody(ChartState state, double w) {
    if (state.isLoading) {
      return const Center(
        key: ValueKey('loading'),
        child: CircularProgressIndicator(
          color: AppColors.golden,
          strokeWidth: 2,
        ),
      );
    }
    if (state.hasError) {
      return Center(
        key: const ValueKey('error'),
        child: Text(
          'Не удалось загрузить данные',
          style: const TextStyle(
            fontFamily: 'SF Pro',
            fontSize: 14,
            fontWeight: FontWeight.w300,
            color: AppColors.primaryLight,
          ),
        ),
      );
    }
    return ChartView(
      // Key ensures AnimatedSwitcher fades when metric or period changes.
      key: ValueKey('${state.selectedMetricKey}_${state.selectedPeriod}'),
      spots: state.spots,
      period: state.selectedPeriod,
    );
  }
}

// ── Trend badge ───────────────────────────────────────────────────────────────

/// Shows "+18% · Состояние улучшается" or "−5% · Состояние ухудшается".
/// Renders an empty SizedBox (reserved height) while trendPercent is null.
class _TrendBadge extends StatelessWidget {
  const _TrendBadge({
    required this.trendPercent,
    required this.trendPositive,
  });

  final double? trendPercent;
  final bool trendPositive;

  // Trend colors from the Figma spec.
  static const _colorPositive = Color(0xFF6F8F5A);
  static const _colorNegative = Color(0xFFD0583C);

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;

    if (trendPercent == null) {
      // Reserve the same height so the layout doesn't jump.
      return const SizedBox(height: 28);
    }

    final color = trendPositive ? _colorPositive : _colorNegative;
    final sign = trendPositive ? '+' : '';
    final label =
        trendPositive ? 'Состояние улучшается' : 'Состояние ухудшается';

    return Row(
      children: [
        // Percentage pill
        Container(
          height: 28,
          padding: EdgeInsets.symmetric(horizontal: w * 0.038),
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.scaffoldBackground,
              width: 0.7,
            ),
            borderRadius: BorderRadius.circular(15),
          ),
          alignment: Alignment.center,
          child: Text(
            '$sign${trendPercent!.round()}%',
            style: TextStyle(
              fontFamily: 'SF Pro',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
        SizedBox(width: w * 0.038),
        // Description text
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'SF Pro',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryDark,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ],
    );
  }
}
