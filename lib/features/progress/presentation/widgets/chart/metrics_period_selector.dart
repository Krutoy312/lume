import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import 'metrics_chart_controller.dart';

/// Small pill in the top-right of the chart card that shows the active period
/// (e.g. "7д") and opens a popup menu to switch between 7 / 30 / 90 days.
class MetricsPeriodSelector extends StatelessWidget {
  const MetricsPeriodSelector({
    super.key,
    required this.selectedPeriod,
    required this.onChanged,
  });

  final int selectedPeriod;
  final ValueChanged<int> onChanged;

  String _label(int days) => switch (days) {
        7 => '7д',
        30 => '30д',
        90 => '90д',
        _ => '${days}д',  // ignore: unnecessary_brace_in_string_interps
      };

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      initialValue: selectedPeriod,
      onSelected: onChanged,
      color: AppColors.surface,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      itemBuilder: (_) => kChartPeriods
          .map(
            (d) => PopupMenuItem<int>(
              value: d,
              child: Text(
                _label(d),
                style: TextStyle(
                  fontFamily: 'SF Pro',
                  fontSize: 14,
                  fontWeight:
                      d == selectedPeriod ? FontWeight.w600 : FontWeight.w400,
                  color: d == selectedPeriod
                      ? AppColors.golden
                      : AppColors.primaryDark,
                ),
              ),
            ),
          )
          .toList(),
      // Trigger: pill with subtle scaffold-background border (matches Figma).
      child: Container(
        height: 28,
        constraints: const BoxConstraints(minWidth: 45),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.scaffoldBackground,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        alignment: Alignment.center,
        child: Text(
          _label(selectedPeriod),
          style: const TextStyle(
            fontFamily: 'SF Pro',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.golden,
          ),
        ),
      ),
    );
  }
}
