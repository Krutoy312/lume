import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────

const _todayGradStart = Color(0xFF6F8F5A);
const _todayGradEnd = Color(0xFFCFE8BE);
const _dataRingStart = Color(0xFFC1CFB8);
const _dataRingEnd = Color(0xFFD9E1D3);
const _selectedBg = Color(0xFFF5EDE4);

// ─── Tile ─────────────────────────────────────────────────────────────────────

/// A single day cell in the calendar grid.
///
/// Visual priority (highest first):
///   1. today       → gradient fill (#6F8F5A → #CFE8BE)
///   2. selected    → solid #F5EDE4 background
///   3. inRange     → solid #F5EDE4 background
///   4. hasData     → gradient border ring (#6F8F5A → #FFFFFF)
///   5. plain       → transparent
class CalendarTile extends StatelessWidget {
  const CalendarTile({
    super.key,
    required this.day,
    required this.isCurrentMonth,
    required this.isToday,
    required this.hasData,
    required this.isSelected,
    required this.isInRange,
    this.onTap,
  });

  final int day;
  final bool isCurrentMonth;
  final bool isToday;
  final bool hasData;
  final bool isSelected;
  final bool isInRange;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final size = w * 0.099;

    // Text color
    Color textColor;
    if (!isCurrentMonth) {
      textColor = AppColors.primaryLighter;
    } else if (isToday) {
      textColor = AppColors.surface;
    } else {
      textColor = AppColors.primaryDark;
    }

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _TilePainter(
            isToday: isToday,
            hasData: hasData && !isSelected && !isToday,
            isSelected: isSelected,
            isInRange: isInRange && !isSelected,
          ),
          child: Center(
            child: Text(
              '$day',
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontSize: w * 0.036,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: textColor,
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Painter ──────────────────────────────────────────────────────────────────

class _TilePainter extends CustomPainter {
  const _TilePainter({
    required this.isToday,
    required this.hasData,
    required this.isSelected,
    required this.isInRange,
  });

  final bool isToday;
  final bool hasData;
  final bool isSelected;
  final bool isInRange;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = Radius.circular(size.width / 2);
    final rRect = RRect.fromRectAndRadius(rect, radius);

    if (isToday) {
      canvas.drawRRect(
        rRect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_todayGradStart, _todayGradEnd],
          ).createShader(rect),
      );
      return;
    }

    if (isSelected || isInRange) {
      canvas.drawRRect(rRect, Paint()..color = _selectedBg);
      return;
    }

    if (hasData) {
      // Outer gradient ring
      const borderWidth = 2.0;
      canvas.drawRRect(
        rRect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_dataRingStart, _dataRingEnd],
          ).createShader(rect),
      );
      // Inner fill punched out
      final innerRect = Rect.fromLTWH(
        borderWidth,
        borderWidth,
        size.width - borderWidth * 2,
        size.height - borderWidth * 2,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          innerRect,
          Radius.circular(size.width / 2 - borderWidth),
        ),
        Paint()..color = AppColors.scaffoldBackground,
      );
    }
  }

  @override
  bool shouldRepaint(_TilePainter old) =>
      old.isToday != isToday ||
      old.hasData != hasData ||
      old.isSelected != isSelected ||
      old.isInRange != isInRange;
}
