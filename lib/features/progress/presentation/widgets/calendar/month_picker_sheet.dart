import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import 'calendar_controller.dart';

/// Bottom sheet that lists only months with assessment data, grouped by year.
/// Year labels are non-tappable headers.
class MonthPickerSheet extends ConsumerWidget {
  const MonthPickerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calendarProvider);
    final w = MediaQuery.sizeOf(context).width;

    // Sort available months (YYYY-MM strings)
    final available = state.availableMonths.toList()..sort();

    // Group by year
    final Map<int, List<int>> byYear = {};
    for (final ym in available) {
      final year = int.parse(ym.substring(0, 4));
      final month = int.parse(ym.substring(5, 7));
      byYear.putIfAbsent(year, () => []).add(month);
    }
    final years = byYear.keys.toList()..sort();

    final sysPad = MediaQuery.paddingOf(context).bottom;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(w * 0.051)),
      ),
      padding: EdgeInsets.fromLTRB(
          w * 0.051, w * 0.025, w * 0.051, w * 0.061 + sysPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: w * 0.102,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.primaryLighter,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          SizedBox(height: w * 0.051),
          Text('Выберите месяц', style: AppTextStyles.displayMedium),
          SizedBox(height: w * 0.038),

          if (available.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: w * 0.051),
              child: Text(
                'Данные пока не загружены',
                style: AppTextStyles.bodyLargeProgress,
              ),
            )
          else
            ...years.map((year) {
              final months = byYear[year]!..sort();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Year header (non-tappable) ──
                  Padding(
                    padding:
                        EdgeInsets.only(bottom: w * 0.020, top: w * 0.015),
                    child: Text(
                      '$year',
                      style: TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: w * 0.036,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryMedium,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  // ── Month chips ──
                  Wrap(
                    spacing: w * 0.025,
                    runSpacing: w * 0.020,
                    children: months.map((m) {
                      final isSelected = state.displayMonth.year == year &&
                          state.displayMonth.month == m;
                      return GestureDetector(
                        onTap: () {
                          ref
                              .read(calendarProvider.notifier)
                              .changeMonth(DateTime(year, m));
                          Navigator.of(context).pop();
                        },
                        child: _MonthChip(
                          label: kCalendarMonthNames[m - 1],
                          isSelected: isSelected,
                        ),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: w * 0.020),
                ],
              );
            }),
        ],
      ),
    );
  }
}

// ─── Month chip ───────────────────────────────────────────────────────────────

class _MonthChip extends StatelessWidget {
  const _MonthChip({required this.label, required this.isSelected});

  final String label;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: w * 0.038,
        vertical: w * 0.020,
      ),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.progressBarBack : Colors.transparent,
        borderRadius: BorderRadius.circular(w * 0.025),
        border: isSelected
            ? null
            : Border.all(color: AppColors.primaryLighter, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'SF Pro',
          fontSize: w * 0.036,
          fontWeight:
              isSelected ? FontWeight.w600 : FontWeight.w400,
          color: isSelected
              ? AppColors.primaryDark
              : AppColors.primaryMedium,
        ),
      ),
    );
  }
}
