import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../../core/theme/app_colors.dart';

/// A single metric row used inside the Daily Assessment card.
///
/// Layout (per Figma node 261:462):
///   ┌───────────────────────────────────────────────┐
///   │ [icon]  Label                      N   /10   │
///   │ [══════════golden-gradient-slider═══════════] │
///   └───────────────────────────────────────────────┘
class MetricSliderTile extends StatelessWidget {
  const MetricSliderTile({
    super.key,
    required this.iconPath,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String iconPath;
  final String label;

  /// Current value in [1.0, 10.0].
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;

    return Padding(
      padding: EdgeInsets.only(bottom: w * 0.076),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header: icon · label · score ─────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SvgPicture.asset(
                iconPath,
                width: w * 0.048,
                height: w * 0.048,
                colorFilter: const ColorFilter.mode(
                  AppColors.golden,
                  BlendMode.srcIn,
                ),
              ),
              SizedBox(width: w * 0.025),

              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                    letterSpacing: -0.5,
                  ),
                ),
              ),

              // Score: large number + "/10" suffix
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${value.round()}',
                      style: const TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryDark,
                        height: 1.0,
                      ),
                    ),
                    TextSpan(
                      text: '/10',
                      style: const TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                        color: AppColors.primaryLighter,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: w * 0.020),

          // ── Gradient slider ───────────────────────────────────────────────
          SizedBox(
            height: w * 0.071,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                activeTrackColor: AppColors.golden,
                inactiveTrackColor: AppColors.progressBarBack,
                thumbColor: AppColors.golden,
                overlayColor: AppColors.golden.withValues(alpha: 0.12),
                thumbShape: _GoldenThumbShape(radius: w * 0.025),
                overlayShape:
                    RoundSliderOverlayShape(overlayRadius: w * 0.046),
                trackShape: const _GradientTrackShape(),
              ),
              child: Slider(
                value: value,
                min: 1,
                max: 10,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Gradient track ───────────────────────────────────────────────────────────

/// Paints the active segment with a [AppColors.golden] → [AppColors.goldenLighter]
/// gradient and the inactive segment with [AppColors.progressBarBack].
class _GradientTrackShape extends SliderTrackShape {
  const _GradientTrackShape();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 4.0;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    return Rect.fromLTWH(
      offset.dx,
      trackTop,
      parentBox.size.width,
      trackHeight,
    );
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
    required TextDirection textDirection,
  }) {
    final canvas = context.canvas;
    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
    );
    final radius = Radius.circular(trackRect.height / 2);

    // Full-width inactive background
    canvas.drawRRect(
      RRect.fromRectAndRadius(trackRect, radius),
      Paint()
        ..color =
            sliderTheme.inactiveTrackColor ?? AppColors.progressBarBack,
    );

    // Active gradient segment (left edge → thumb)
    final activeRight =
        thumbCenter.dx.clamp(trackRect.left, trackRect.right);
    final activeRect = Rect.fromLTRB(
      trackRect.left,
      trackRect.top,
      activeRight,
      trackRect.bottom,
    );
    if (activeRect.width > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(activeRect, radius),
        Paint()
          ..shader = const LinearGradient(
            colors: [AppColors.golden, AppColors.goldenLighter],
          ).createShader(trackRect),
      );
    }
  }
}

// ─── Custom thumb ─────────────────────────────────────────────────────────────

/// White-filled circle with a golden border and a subtle glow.
class _GoldenThumbShape extends SliderComponentShape {
  const _GoldenThumbShape({required this.radius});

  final double radius;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      Size.fromRadius(radius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;

    // White fill
    canvas.drawCircle(center, radius, Paint()..color = AppColors.surface);

    // Golden border
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppColors.golden
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
}
