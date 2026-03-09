import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../../core/theme/app_colors.dart';
import '../metrics/assessment_provider.dart';
import 'calendar_controller.dart';

// ─── Colors ───────────────────────────────────────────────────────────────────

const _greenDelta = Color(0xFF6F8F5A);

// ─── Root widget ──────────────────────────────────────────────────────────────

/// Displays assessment data for the selected calendar day(s).
///
/// Single mode: photo + read-only metric sliders.
/// Comparison mode (both dates selected): two photos side-by-side + delta sliders.
class ComparisonDetailsView extends ConsumerWidget {
  const ComparisonDetailsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calendarProvider);
    final w = MediaQuery.sizeOf(context).width;

    if (state.startDate == null) return const SizedBox.shrink();

    if (state.detailLoadState is AsyncLoading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: w * 0.076),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.golden),
        ),
      );
    }

    final startData = state.dataFor(state.startDate);
    if (startData == null) return const SizedBox.shrink();

    // Single mode or comparison waiting for second date
    if (!state.comparisonMode || state.endDate == null) {
      return _SingleDayView(data: startData);
    }

    // Comparison mode with both dates
    final endData = state.dataFor(state.endDate);
    if (endData == null) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: w * 0.076),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.golden),
        ),
      );
    }

    return _ComparisonView(startData: startData, endData: endData);
  }
}

// ─── Single day view ──────────────────────────────────────────────────────────

class _SingleDayView extends StatelessWidget {
  const _SingleDayView({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final photoUrl = data['photoUrl'] as String?;
    final metrics =
        (data['metrics'] as Map<String, dynamic>?) ?? const {};
    final note = (data['note'] as String?) ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: w * 0.051),

        if (photoUrl != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(w * 0.038),
            child: Image.network(
              photoUrl,
              width: double.infinity,
              height: w * 0.56,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _photoPlaceholder(w, w * 0.56),
            ),
          ),
          SizedBox(height: w * 0.038),
        ],

        if (note.isNotEmpty) ...[
          Text(
            note,
            style: TextStyle(
              fontFamily: 'SF Pro',
              fontSize: w * 0.036,
              color: AppColors.primaryMedium,
              height: 1.4,
            ),
          ),
          SizedBox(height: w * 0.038),
        ],

        ...kAllMetrics.map((m) {
          final val = (metrics[m.key] as num?)?.toDouble();
          if (val == null) return const SizedBox.shrink();
          return _ReadOnlySliderTile(
            iconPath: m.iconPath,
            label: m.label,
            value: val,
          );
        }),
      ],
    );
  }
}

// ─── Comparison view ──────────────────────────────────────────────────────────

class _ComparisonView extends StatelessWidget {
  const _ComparisonView({
    required this.startData,
    required this.endData,
  });

  final Map<String, dynamic> startData;
  final Map<String, dynamic> endData;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final startPhotoUrl = startData['photoUrl'] as String?;
    final endPhotoUrl = endData['photoUrl'] as String?;
    final startMetrics =
        (startData['metrics'] as Map<String, dynamic>?) ?? const {};
    final endMetrics =
        (endData['metrics'] as Map<String, dynamic>?) ?? const {};

    // Only show metrics tracked on both days
    final shared = kAllMetrics
        .where((m) =>
            startMetrics.containsKey(m.key) &&
            endMetrics.containsKey(m.key))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: w * 0.051),

        // ── Side-by-side photos ──
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _PhotoCard(
                photoUrl: startPhotoUrl,
                label: 'Начало',
              ),
            ),
            SizedBox(width: w * 0.025),
            Expanded(
              child: _PhotoCard(
                photoUrl: endPhotoUrl,
                label: 'Конец',
              ),
            ),
          ],
        ),

        SizedBox(height: w * 0.038),

        if (shared.isEmpty)
          Text(
            'Нет общих метрик для сравнения',
            style: TextStyle(
              fontFamily: 'SF Pro',
              fontSize: w * 0.036,
              color: AppColors.primaryMedium,
            ),
          )
        else
          ...shared.map((m) {
            final startVal = (startMetrics[m.key] as num).toDouble();
            final endVal = (endMetrics[m.key] as num).toDouble();
            return _ComparisonSliderTile(
              iconPath: m.iconPath,
              label: m.label,
              value: endVal,
              delta: endVal - startVal,
            );
          }),
      ],
    );
  }
}

// ─── Photo card ───────────────────────────────────────────────────────────────

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({this.photoUrl, required this.label});

  final String? photoUrl;
  final String label;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final h = w * 0.356;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'SF Pro',
            fontSize: w * 0.031,
            color: AppColors.primaryMedium,
          ),
        ),
        SizedBox(height: w * 0.015),
        ClipRRect(
          borderRadius: BorderRadius.circular(w * 0.025),
          child: photoUrl != null
              ? Image.network(
                  photoUrl!,
                  width: double.infinity,
                  height: h,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _photoPlaceholder(w, h),
                )
              : _photoPlaceholder(w, h),
        ),
      ],
    );
  }
}

Widget _photoPlaceholder(double w, double h) => Container(
      width: double.infinity,
      height: h,
      color: AppColors.progressBarBack,
      child: Icon(
        Icons.photo_outlined,
        color: AppColors.primaryLighter,
        size: w * 0.076,
      ),
    );

// ─── Read-only slider tile ────────────────────────────────────────────────────

class _ReadOnlySliderTile extends StatelessWidget {
  const _ReadOnlySliderTile({
    required this.iconPath,
    required this.label,
    required this.value,
  });

  final String iconPath;
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return Padding(
      padding: EdgeInsets.only(bottom: w * 0.051),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SliderHeader(
            iconPath: iconPath,
            label: label,
            value: value,
          ),
          SizedBox(height: w * 0.020),
          _ReadOnlyTrack(value: value),
        ],
      ),
    );
  }
}

// ─── Comparison slider tile ───────────────────────────────────────────────────

class _ComparisonSliderTile extends StatelessWidget {
  const _ComparisonSliderTile({
    required this.iconPath,
    required this.label,
    required this.value,
    required this.delta,
  });

  final String iconPath;
  final String label;
  final double value;
  final double delta;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;

    final isPositive = delta > 0;
    final isNeutral = delta == 0;
    final deltaColor = isNeutral
        ? AppColors.primaryMedium
        : isPositive
            ? _greenDelta
            : AppColors.alertRed;
    final deltaText = isNeutral
        ? '±0'
        : isPositive
            ? '+${delta.round()}'
            : '${delta.round()}';

    return Padding(
      padding: EdgeInsets.only(bottom: w * 0.051),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SvgPicture.asset(
                iconPath,
                width: w * 0.046,
                height: w * 0.046,
                colorFilter: const ColorFilter.mode(
                  AppColors.golden,
                  BlendMode.srcIn,
                ),
              ),
              SizedBox(width: w * 0.025),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: w * 0.040,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              // Delta badge
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: w * 0.020,
                  vertical: w * 0.008,
                ),
                decoration: BoxDecoration(
                  color: deltaColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(w * 0.015),
                ),
                child: Text(
                  deltaText,
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: w * 0.031,
                    fontWeight: FontWeight.w600,
                    color: deltaColor,
                  ),
                ),
              ),
              SizedBox(width: w * 0.015),
              // Score
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${value.round()}',
                      style: TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: w * 0.061,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryDark,
                        height: 1.0,
                      ),
                    ),
                    TextSpan(
                      text: '/10',
                      style: TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: w * 0.033,
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
          _ReadOnlyTrack(value: value),
        ],
      ),
    );
  }
}

// ─── Shared slider header (icon + label + score) ──────────────────────────────

class _SliderHeader extends StatelessWidget {
  const _SliderHeader({
    required this.iconPath,
    required this.label,
    required this.value,
  });

  final String iconPath;
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return Row(
      children: [
        SvgPicture.asset(
          iconPath,
          width: w * 0.046,
          height: w * 0.046,
          colorFilter: const ColorFilter.mode(
            AppColors.golden,
            BlendMode.srcIn,
          ),
        ),
        SizedBox(width: w * 0.025),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'SF Pro',
              fontSize: w * 0.040,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryDark,
              letterSpacing: -0.5,
            ),
          ),
        ),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '${value.round()}',
                style: TextStyle(
                  fontFamily: 'SF Pro',
                  fontSize: w * 0.061,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryDark,
                  height: 1.0,
                ),
              ),
              TextSpan(
                text: '/10',
                style: TextStyle(
                  fontFamily: 'SF Pro',
                  fontSize: w * 0.033,
                  fontWeight: FontWeight.w300,
                  color: AppColors.primaryLighter,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Read-only gradient track ─────────────────────────────────────────────────

/// Non-interactive gradient progress bar (no thumb, no overlay).
class _ReadOnlyTrack extends StatelessWidget {
  const _ReadOnlyTrack({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return IgnorePointer(
      child: SizedBox(
        height: w * 0.040,
        child: SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            activeTrackColor: AppColors.golden,
            inactiveTrackColor: AppColors.progressBarBack,
            thumbShape: SliderComponentShape.noThumb,
            overlayShape: SliderComponentShape.noOverlay,
            trackShape: const _GradientTrackShape(),
          ),
          child: Slider(
            value: value,
            min: 1,
            max: 10,
            onChanged: (_) {},
          ),
        ),
      ),
    );
  }
}

// ─── Gradient track (mirrors MetricSliderTile) ────────────────────────────────

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
    final h = sliderTheme.trackHeight ?? 4.0;
    final top = offset.dy + (parentBox.size.height - h) / 2;
    return Rect.fromLTWH(offset.dx, top, parentBox.size.width, h);
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

    // Inactive background
    canvas.drawRRect(
      RRect.fromRectAndRadius(trackRect, radius),
      Paint()
        ..color =
            sliderTheme.inactiveTrackColor ?? AppColors.progressBarBack,
    );

    // Active gradient segment
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
