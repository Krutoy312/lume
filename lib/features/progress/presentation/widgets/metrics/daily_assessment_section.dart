import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../core/theme/app_colors.dart';
import 'assessment_service.dart';
import 'change_metrics_bottom_sheet.dart';
import 'metric_slider_tile.dart';
import 'metrics_controller.dart';
import 'tracked_metrics_provider.dart';

// ── Fullscreen photo viewer ────────────────────────────────────────────────────

/// Displays a single photo fullscreen with a fade-in transition.
/// Accepts either a local [localPath] (XFile) or a [networkUrl] from Firestore.
/// Tap anywhere to dismiss.
class _FullscreenPhotoView extends StatelessWidget {
  const _FullscreenPhotoView({this.localPath, this.networkUrl})
      : assert(localPath != null || networkUrl != null,
            'Provide localPath or networkUrl');

  final String? localPath;
  final String? networkUrl;

  @override
  Widget build(BuildContext context) {
    final imageWidget = localPath != null
        ? Image.file(File(localPath!), fit: BoxFit.contain)
        : Image.network(
            networkUrl!,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.golden,
                      strokeWidth: 2,
                    ),
                  ),
          );

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.black87,
        body: Center(
          child: Hero(
            tag: 'assessment_photo_hero',
            child: imageWidget,
          ),
        ),
      ),
    );
  }
}

// ── Skeleton blocks ────────────────────────────────────────────────────────────

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox(this.width, this.height, {this.radius = 8});

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFEFEFEF),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// ── Public widget ──────────────────────────────────────────────────────────────

/// Embedded daily skin-assessment section for the Progress screen.
///
/// On mount:
///   1. Fetches today's Firestore document via [AssessmentNotifier.load].
///   2. Auto-collapses if a document exists ([existsToday] = true).
///   3. Renders only the sliders for the user's current [trackedMetricsProvider].
///
/// "Изменить метрики" opens [ChangeMetricsBottomSheet]; on dismissal the new
/// selection is written to Firestore and the slider list updates reactively.
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
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();
    _detectTimezone();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(assessmentProvider.notifier).load();
    });
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
      ref.read(assessmentProvider.notifier).removePhoto();

  void _openFullscreen() {
    final state = ref.read(assessmentProvider);
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (_, __, ___) => _FullscreenPhotoView(
          localPath: state.photo?.path,
          networkUrl: state.photo == null ? state.photoUrl : null,
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
      ),
    );
  }

  // ── Change metrics ─────────────────────────────────────────────────────────

  /// Opens the metric selection sheet.  On any dismissal (swipe, backdrop,
  /// back), saves the latest selection to Firestore if it changed.
  Future<void> _openChangeMetrics() async {
    final currentTracked = ref.read(trackedMetricsProvider);
    List<String> latestSelection = List.from(currentTracked);

    await ChangeMetricsBottomSheet.show(
      context,
      initialTracked: currentTracked,
      onSelectionChanged: (updated) => latestSelection = updated,
    );

    if (!mounted) return;

    // Only write to Firestore when the selection actually changed.
    final a = Set<String>.from(currentTracked);
    final b = Set<String>.from(latestSelection);
    final changed = a.length != b.length || !a.containsAll(b);
    if (!changed) return;

    await AssessmentService.saveTrackedMetrics(latestSelection);
    // trackedMetricsProvider rebuilds reactively via userDocumentProvider stream.
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    // Capture tracked keys at the moment of submission.
    final trackedKeys = ref.read(trackedMetricsProvider);

    await ref.read(assessmentProvider.notifier).submit(
      timezone: _timezone,
      trackedKeys: trackedKeys,
      onSuccess: (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Оценка сохранена!'),
            backgroundColor: AppColors.golden,
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Re-fetch so the form shows the saved state and collapses.
        ref.read(assessmentProvider.notifier).load();
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
    final trackedKeys = ref.watch(trackedMetricsProvider);

    // Sync note controller + auto-collapse once the initial load finishes.
    ref.listen<AssessmentState>(assessmentProvider, (prev, next) {
      final wasLoading = prev?.loadState is AsyncLoading;
      final isDone = next.loadState is AsyncData;
      if (wasLoading && isDone) {
        if (_noteController.text != next.note) {
          _noteController.text = next.note;
          _noteController.selection =
              TextSelection.collapsed(offset: next.note.length);
        }
        if (next.existsToday && _isExpanded) {
          setState(() => _isExpanded = false);
        }
      }
    });

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
          GestureDetector(
            onTap: () {
              if (!state.isLoadingData) {
                setState(() => _isExpanded = !_isExpanded);
              }
            },
            behavior: HitTestBehavior.opaque,
            child: Row(
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
                // Arrow: ↑ expanded | ↓ collapsed
                Padding(
                  padding: EdgeInsets.only(top: w * 0.010),
                  child: AnimatedRotation(
                    turns: _isExpanded ? -0.25 : 0.25,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
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
              ],
            ),
          ),

          // ── Collapsible body ───────────────────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            clipBehavior: Clip.hardEdge,
            child: _isExpanded
                ? _buildBody(context, w, state, notifier, trackedKeys)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // ── Body dispatcher ────────────────────────────────────────────────────────

  Widget _buildBody(
    BuildContext context,
    double w,
    AssessmentState state,
    AssessmentNotifier notifier,
    List<String> trackedKeys,
  ) {
    if (state.isLoadingData) return _buildSkeleton(w, trackedKeys.length);
    if (state.hasLoadError) return _buildErrorBody(w);
    return _buildContent(context, w, state, notifier, trackedKeys);
  }

  // ── Skeleton ───────────────────────────────────────────────────────────────

  Widget _buildSkeleton(double w, int count) {
    return Padding(
      padding: EdgeInsets.only(top: w * 0.061),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < count; i++) ...[
            Row(
              children: [
                _SkeletonBox(w * 0.048, w * 0.048, radius: 6),
                SizedBox(width: w * 0.025),
                Expanded(child: _SkeletonBox(double.infinity, 14, radius: 6)),
                SizedBox(width: w * 0.051),
                _SkeletonBox(w * 0.071, w * 0.071, radius: 6),
              ],
            ),
            SizedBox(height: w * 0.020),
            _SkeletonBox(double.infinity, 4, radius: 4),
            SizedBox(height: w * 0.056),
          ],
          _SkeletonBox(double.infinity, w * 0.122, radius: w * 0.038),
          SizedBox(height: w * 0.025),
          _SkeletonBox(double.infinity, w * 0.120, radius: w * 0.038),
          SizedBox(height: w * 0.025),
          _SkeletonBox(double.infinity, w * 0.120, radius: w * 0.041),
        ],
      ),
    );
  }

  // ── Error body ─────────────────────────────────────────────────────────────

  Widget _buildErrorBody(double w) {
    return Padding(
      padding: EdgeInsets.only(top: w * 0.061),
      child: Column(
        children: [
          const Text(
            'Не удалось загрузить данные',
            style: TextStyle(
              fontFamily: 'SF Pro',
              fontSize: 14,
              color: AppColors.primaryMedium,
            ),
          ),
          SizedBox(height: w * 0.025),
          GestureDetector(
            onTap: () => ref.read(assessmentProvider.notifier).load(),
            child: const Text(
              'Повторить',
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.golden,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Full content body ──────────────────────────────────────────────────────

  Widget _buildContent(
    BuildContext context,
    double w,
    AssessmentState state,
    AssessmentNotifier notifier,
    List<String> trackedKeys,
  ) {
    // Filter kAllMetrics to only the user's current tracked subset,
    // preserving the canonical order from kAllMetrics.
    final trackedSet = Set<String>.from(trackedKeys);
    final activeMetrics =
        kAllMetrics.where((m) => trackedSet.contains(m.key)).toList();

    final hasLocalPhoto = state.photo != null;
    final hasNetworkPhoto = state.photoUrl != null && !hasLocalPhoto;
    final hasAnyPhoto = hasLocalPhoto || hasNetworkPhoto;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: w * 0.061),

        // ── Metric sliders (tracked only) ──────────────────────────────────
        for (final m in activeMetrics)
          MetricSliderTile(
            iconPath: m.iconPath,
            label: m.label,
            value: state.metrics[m.key] ?? 5.0,
            onChanged: (v) => notifier.setMetric(m.key, v),
          ),

        // ── Photo thumbnail ────────────────────────────────────────────────
        if (hasAnyPhoto) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(w * 0.025),
            child: Stack(
              children: [
                GestureDetector(
                  onTap: _openFullscreen,
                  child: Hero(
                    tag: 'assessment_photo_hero',
                    child: hasLocalPhoto
                        ? Image.file(
                            File(state.photo!.path),
                            width: double.infinity,
                            height: w * 0.350,
                            fit: BoxFit.cover,
                          )
                        : Image.network(
                            state.photoUrl!,
                            width: double.infinity,
                            height: w * 0.350,
                            fit: BoxFit.cover,
                            loadingBuilder: (_, child, progress) =>
                                progress == null
                                    ? child
                                    : SizedBox(
                                        height: w * 0.350,
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            color: AppColors.golden,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                          ),
                  ),
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
          SizedBox(height: w * 0.030),
        ],

        // ── Note + photo-picker row ────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.transparent, width: 1),
            borderRadius: BorderRadius.circular(w * 0.038),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: w * 0.038),
              Expanded(
                child: TextField(
                  controller: _noteController,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  style: const TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppColors.primaryDark,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Добавить заметку...',
                    hintStyle: const TextStyle(
                      fontFamily: 'SF Pro',
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                      color: AppColors.primaryLighter,
                      letterSpacing: -0.5,
                    ),
                    border: InputBorder.none,
                    isDense: false,
                    contentPadding:
                        EdgeInsets.symmetric(vertical: w * 0.040),
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
                      hasAnyPhoto
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
        _ChangeMetricsButton(w: w, onTap: _openChangeMetrics),

        SizedBox(height: w * 0.025),

        // ── Save / Update button ───────────────────────────────────────────
        _SubmitButton(
          w: w,
          isLoading: state.isLoading,
          label: state.existsToday ? 'Обновить' : 'Сохранить',
          onTap: _submit,
        ),
      ],
    );
  }
}

// ── Change metrics button ──────────────────────────────────────────────────────

class _ChangeMetricsButton extends StatelessWidget {
  const _ChangeMetricsButton({required this.w, required this.onTap});

  final double w;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: w * 0.120,
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
    required this.label,
    required this.onTap,
  });

  final double w;
  final bool isLoading;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: w * 0.120,
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
              : Text(
                  label,
                  style: const TextStyle(
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
