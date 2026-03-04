import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

/// Pure UI widget — renders a smooth line chart for a single metric.
///
/// [spots] use X = day index (0 = oldest), Y = metric value (1–10).
/// [period] defines the X-axis range (7, 30, or 90 days).
///
/// The widget animates via [AnimatedSwitcher] when the key changes (i.e. when
/// the caller passes a new [key] on metric/period switch).
class ChartView extends StatelessWidget {
  const ChartView({
    super.key,
    required this.spots,
    required this.period,
  });

  final List<FlSpot> spots;
  final int period;

  @override
  Widget build(BuildContext context) {
    if (spots.isEmpty) {
      return Center(
        child: Text(
          'Нет данных за этот период',
          style: const TextStyle(
            fontFamily: 'SF Pro',
            fontSize: 14,
            fontWeight: FontWeight.w300,
            color: AppColors.primaryLight,
          ),
        ),
      );
    }

    return LineChart(
      _buildData(),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  LineChartData _buildData() {
    final maxX = (period - 1).toDouble();

    return LineChartData(
      minX: 0,
      maxX: maxX,
      minY: 0,
      maxY: 10,
      clipData: const FlClipData.all(),

      // ── Grid ──────────────────────────────────────────────────────────────
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        drawHorizontalLine: true,
        horizontalInterval: 2,
        verticalInterval: _verticalInterval,
        getDrawingHorizontalLine: (value) => FlLine(
          color: value == 0
              ? const Color(0xFFD9D9D9)
              : const Color(0xFFEEEEEE),
          strokeWidth: value == 0 ? 1.0 : 0.7,
          dashArray: value == 0 ? null : [4, 4],
        ),
        getDrawingVerticalLine: (_) => const FlLine(
          color: Color(0xFFEEEEEE),
          strokeWidth: 0.7,
        ),
      ),

      // ── Axes ──────────────────────────────────────────────────────────────
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 2,
            reservedSize: 28,
            getTitlesWidget: (value, _) {
              if (value % 2 != 0 || value < 0 || value > 10) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  value.toInt().toString(),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 10,
                    fontWeight: FontWeight.w300,
                    color: AppColors.primaryLight,
                  ),
                ),
              );
            },
          ),
        ),
        bottomTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),

      borderData: FlBorderData(show: false),

      // ── Line ──────────────────────────────────────────────────────────────
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.35,
          preventCurveOverShooting: true,
          color: AppColors.golden,
          barWidth: 2,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          // Gradient fill under the line — golden fading to transparent.
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.golden.withValues(alpha: 0.28),
                AppColors.golden.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ],

      // Disable default touch tooltips; they look inconsistent with the design.
      lineTouchData: const LineTouchData(enabled: false),
    );
  }

  /// Vertical grid-line interval based on the selected period.
  double get _verticalInterval {
    if (period <= 7) return 1;
    if (period <= 30) return 5;
    return 15;
  }
}
