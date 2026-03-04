import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../core/theme/app_colors.dart';
import 'metric_slider_tile.dart';
import 'metrics_controller.dart';

// ── Public widget ──────────────────────────────────────────────────────────────

/// Embedded daily skin-assessment section for the Progress screen.
///
/// Renders as a single white card (no [Scaffold]) so it can live inside any
/// parent scroll view.  Contains:
///   • Card header — "Как себя чувствует твоя кожа?" + collapse arrow.
///   • 4 metric sliders with golden gradient track.
///   • Optional photo thumbnail with remove button.
///   • Single-line note field + photo-picker icon.
///   • "Изменить метрики" thin-border button.
///   • "Сохранить" — calls [saveDailyAssessment] Cloud Function, merges note +
///     photo into Firestore, shows a SnackBar, and resets the form.
class DailyAssessmentSection extends ConsumerStatefulWidget {
  const DailyAssessmentSection({super.key});

  @override
  ConsumerState<DailyAssessmentSection> createState() =>
      _DailyAssessmentSectionState();
}

class _DailyAssessmentSectionState
    extends ConsumerState<DailyAssessmentSection> {
  final _noteController = TextEditingController();
  final _imagePicker = ImagePicker();
  String _timezone = 'UTC';

  @override
  void initState() {
    super.initState();
    _detectTimezone();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  // ── Timezone ───────────────────────────────────────────────────────────────

  Future<void> _detectTimezone() async {
    try {
      final tz = (await FlutterTimezone.getLocalTimezone()).identifier;
      if (mounted) setState(() => _timezone = tz);
    } catch (_) {
      // Fallback: keep 'UTC'
    }
  }

  // ── Photo ──────────────────────────────────────────────────────────────────

  Future<void> _pickPhoto() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null) {
      ref.read(assessmentProvider.notifier).setPhoto(picked);
    }
  }

  void _removePhoto() =>
      ref.read(assessmentProvider.notifier).setPhoto(null);

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    await ref.read(assessmentProvider.notifier).submit(
      timezone: _timezone,
      onSuccess: (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Оценка сохранена!'),
            backgroundColor: AppColors.golden,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _noteController.clear();
        ref.read(assessmentProvider.notifier).reset();
      },
      onError: (err) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $err'),
            backgroundColor: AppColors.alertRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final state = ref.watch(assessmentProvider);
    final notifier = ref.read(assessmentProvider.notifier);

    return Container(
      padding: EdgeInsets.all(w * 0.051),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(w * 0.041),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D966E3B),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ─────────────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Как себя чувствует\nтвоя кожа?',
                  style: const TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                    height: 1.15,
                    letterSpacing: -0.6,
                  ),
                ),
              ),
              // Collapse indicator (stub — tap does nothing yet)
              GestureDetector(
                onTap: () {},
                child: Padding(
                  padding: EdgeInsets.only(top: w * 0.010),
                  child: Transform.rotate(
                    angle: -math.pi / 2,
                    child: SvgPicture.asset(
                      'assets/icons/ic_arrow.svg',
                      width: w * 0.043,
                      height: w * 0.023,
                      colorFilter: const ColorFilter.mode(
                        AppColors.primaryLight,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: w * 0.061),

          // ── Metric sliders ─────────────────────────────────────────────────
          for (final m in kDefaultMetrics)
            MetricSliderTile(
              iconPath: m.iconPath,
              label: m.label,
              value: state.metrics[m.key] ?? 5.0,
              onChanged: (v) => notifier.setMetric(m.key, v),
            ),

          // ── Photo thumbnail (shown only when a photo is picked) ─────────────
          if (state.photo != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(w * 0.025),
              child: Stack(
                children: [
                  Image.file(
                    File(state.photo!.path),
                    width: double.infinity,
                    height: w * 0.203,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    top: w * 0.015,
                    right: w * 0.015,
                    child: GestureDetector(
                      onTap: _removePhoto,
                      child: Container(
                        padding: EdgeInsets.all(w * 0.010),
                        decoration: const BoxDecoration(
                          color: Color(0x99000000),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: w * 0.038,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: w * 0.020),
          ],

          // ── Note + photo row ───────────────────────────────────────────────
          Container(
            height: w * 0.122,
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.scaffoldBackground,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(w * 0.038),
            ),
            child: Row(
              children: [
                SizedBox(width: w * 0.038),
                Expanded(
                  child: TextField(
                    controller: _noteController,
                    maxLines: 1,
                    style: const TextStyle(
                      fontFamily: 'SF Pro',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.primaryDark,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Добавить заметку...',
                      hintStyle: TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                        color: AppColors.primaryLighter,
                        letterSpacing: -0.5,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: notifier.setNote,
                  ),
                ),
                GestureDetector(
                  onTap: _pickPhoto,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: w * 0.025),
                    child: SvgPicture.asset(
                      'assets/icons/ic_add_photo.svg',
                      width: w * 0.051,
                      height: w * 0.051,
                      colorFilter: ColorFilter.mode(
                        state.photo != null
                            ? AppColors.golden
                            : AppColors.primaryLight,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: w * 0.025),

          // ── Change metrics button ──────────────────────────────────────────
          _ChangeMetricsButton(w: w),

          SizedBox(height: w * 0.025),

          // ── Save button ────────────────────────────────────────────────────
          _SubmitButton(
            w: w,
            isLoading: state.isLoading,
            onTap: _submit,
          ),
        ],
      ),
    );
  }
}

// ── Change metrics button ──────────────────────────────────────────────────────

class _ChangeMetricsButton extends StatelessWidget {
  const _ChangeMetricsButton({required this.w});

  final double w;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // TODO: open metric selection sheet
      },
      child: Container(
        height: w * 0.071,
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.scaffoldBackground,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(w * 0.038),
        ),
        child: const Center(
          child: Text(
            'Изменить метрики',
            style: TextStyle(
              fontFamily: 'SF Pro',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.primaryDark,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Submit button ──────────────────────────────────────────────────────────────

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.w,
    required this.isLoading,
    required this.onTap,
  });

  final double w;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: w * 0.071,
        decoration: BoxDecoration(
          gradient: isLoading ? null : AppColors.metricsGradient,
          color: isLoading ? AppColors.progressBarBack : null,
          borderRadius: BorderRadius.circular(w * 0.041),
          boxShadow: isLoading
              ? null
              : [
                  BoxShadow(
                    color: AppColors.golden.withValues(alpha: 0.30),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Center(
          child: isLoading
              ? const CircularProgressIndicator(
                  color: AppColors.golden,
                  strokeWidth: 2,
                )
              : const Text(
                  'Сохранить',
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.surface,
                    letterSpacing: -0.5,
                  ),
                ),
        ),
      ),
    );
  }
}
