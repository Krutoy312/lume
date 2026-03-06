import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import 'calendar_controller.dart';
import 'calendar_tile.dart';
import 'comparison_details_view.dart';
import 'month_picker_sheet.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────

const _compareOffBorderStart = Color(0xFFC99A68);
const _compareOffBorderEnd = Color(0xFFDFB586);
const _compareOffText = Color(0xFFBB8E5E);
const _compareOnGradStart = Color(0xFFC99A68);
const _compareOnGradEnd = Color(0xFFDFB586);

const _dayLabels = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

// ─── CalendarView ─────────────────────────────────────────────────────────────

/// Main calendar widget. Drop it into any scrollable column.
class CalendarView extends ConsumerWidget {
  const CalendarView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calendarProvider);
    final notifier = ref.read(calendarProvider.notifier);
    final w = MediaQuery.sizeOf(context).width;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(w * 0.038),
      ),
      padding: EdgeInsets.all(w * 0.051),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Month header ──────────────────────────────────────────────
          _MonthHeader(
            month: state.displayMonth,
            onPrev: () => notifier.changeMonth(
              DateTime(
                  state.displayMonth.year, state.displayMonth.month - 1),
            ),
            onNext: () => notifier.changeMonth(
              DateTime(
                  state.displayMonth.year, state.displayMonth.month + 1),
            ),
            onTapMonth: () => _showMonthPicker(context),
          ),

          SizedBox(height: w * 0.038),

          // ── Day-of-week labels ────────────────────────────────────────
          Row(
            children: _dayLabels.map((lbl) {
              return Expanded(
                child: Center(
                  child: Text(
                    lbl,
                    style: TextStyle(
                      fontFamily: 'SF Pro',
                      fontSize: w * 0.031,
                      color: AppColors.primaryLighter,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          SizedBox(height: w * 0.020),

          // ── Calendar grid ─────────────────────────────────────────────
          _CalendarGrid(month: state.displayMonth),

          SizedBox(height: w * 0.038),

          // ── Comparison mode toggle ────────────────────────────────────
          _ComparisonToggle(
            isOn: state.comparisonMode,
            onTap: notifier.toggleComparison,
          ),

          // ── Detail / comparison view ──────────────────────────────────
          const ComparisonDetailsView(),

          SizedBox(height: w * 0.020),
        ],
      ),
    );
  }

  void _showMonthPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const MonthPickerSheet(),
    );
  }
}

// ─── Month header ─────────────────────────────────────────────────────────────

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.onPrev,
    required this.onNext,
    required this.onTapMonth,
  });

  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onTapMonth;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return Row(
      children: [
        // Tappable month + year label
        Expanded(
          child: GestureDetector(
            onTap: onTapMonth,
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${kCalendarMonthNames[month.month - 1]} ${month.year}',
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: w * 0.046,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(width: w * 0.015),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.golden,
                  size: w * 0.051,
                ),
              ],
            ),
          ),
        ),
        // Prev arrow
        _NavArrow(icon: Icons.chevron_left_rounded, onTap: onPrev),
        SizedBox(width: w * 0.020),
        // Next arrow
        _NavArrow(icon: Icons.chevron_right_rounded, onTap: onNext),
      ],
    );
  }
}

// ─── Nav arrow ────────────────────────────────────────────────────────────────

class _NavArrow extends StatelessWidget {
  const _NavArrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: w * 0.081,
        height: w * 0.081,
        decoration: BoxDecoration(
          color: AppColors.progressBarBack,
          borderRadius: BorderRadius.circular(w * 0.020),
        ),
        child: Icon(
          icon,
          color: AppColors.primaryDark,
          size: w * 0.051,
        ),
      ),
    );
  }
}

// ─── Calendar grid ────────────────────────────────────────────────────────────

class _CalendarGrid extends ConsumerWidget {
  const _CalendarGrid({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calendarProvider);
    final notifier = ref.read(calendarProvider.notifier);
    final w = MediaQuery.sizeOf(context).width;
    final today = DateTime.now();

    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // weekday 1=Mon … 7=Sun; offset for Mon-first grid
    final startOffset = firstDay.weekday - 1;
    final rows = ((startOffset + daysInMonth) / 7).ceil();

    return Column(
      children: List.generate(rows, (row) {
        return Padding(
          padding: EdgeInsets.only(bottom: w * 0.015),
          child: Row(
            children: List.generate(7, (col) {
              final index = row * 7 + col;
              final dayNum = index - startOffset + 1;

              if (dayNum < 1 || dayNum > daysInMonth) {
                return const Expanded(child: SizedBox());
              }

              final day = DateTime(month.year, month.month, dayNum);
              final isToday = day.year == today.year &&
                  day.month == today.month &&
                  day.day == today.day;

              return Expanded(
                child: Center(
                  child: CalendarTile(
                    day: dayNum,
                    isCurrentMonth: true,
                    isToday: isToday,
                    hasData: state.hasData(day),
                    isSelected: state.isSelected(day),
                    isInRange: state.isInRange(day),
                    onTap: state.hasData(day)
                        ? () => notifier.selectDay(day)
                        : null,
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}

// ─── Comparison mode toggle ───────────────────────────────────────────────────

class _ComparisonToggle extends StatelessWidget {
  const _ComparisonToggle({
    required this.isOn,
    required this.onTap,
  });

  final bool isOn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final height = w * 0.112;
    final radius = w * 0.038;

    if (isOn) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          height: height,
          margin: EdgeInsets.only(bottom: w * 0.025),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_compareOnGradStart, _compareOnGradEnd],
            ),
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Center(
            child: Text(
              'Режим сравнения: ВКЛ',
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontSize: w * 0.038,
                fontWeight: FontWeight.w600,
                color: AppColors.surface,
              ),
            ),
          ),
        ),
      );
    }

    // OFF: transparent with gradient border via CustomPaint
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.only(bottom: w * 0.025),
        child: CustomPaint(
          painter: _GradientBorderPainter(
            gradient: const LinearGradient(
              colors: [_compareOffBorderStart, _compareOffBorderEnd],
            ),
            borderRadius: radius,
            borderWidth: 1.5,
          ),
          child: SizedBox(
            width: double.infinity,
            height: height,
            child: Center(
              child: Text(
                'Режим сравнения',
                style: TextStyle(
                  fontFamily: 'SF Pro',
                  fontSize: w * 0.038,
                  fontWeight: FontWeight.w400,
                  color: _compareOffText,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Gradient border painter ──────────────────────────────────────────────────

/// Paints a gradient border using even-odd fill: outer rounded rect minus
/// inner rounded rect, filled with the gradient shader.
class _GradientBorderPainter extends CustomPainter {
  const _GradientBorderPainter({
    required this.gradient,
    required this.borderRadius,
    required this.borderWidth,
  });

  final LinearGradient gradient;
  final double borderRadius;
  final double borderWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final outerRRect =
        RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));
    final innerRect = Rect.fromLTWH(
      borderWidth,
      borderWidth,
      size.width - borderWidth * 2,
      size.height - borderWidth * 2,
    );
    final innerRRect = RRect.fromRectAndRadius(
      innerRect,
      Radius.circular((borderRadius - borderWidth).clamp(0, borderRadius)),
    );

    final path = Path()
      ..addRRect(outerRRect)
      ..addRRect(innerRRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      path,
      Paint()..shader = gradient.createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_GradientBorderPainter old) =>
      old.borderRadius != borderRadius || old.borderWidth != borderWidth;
}
