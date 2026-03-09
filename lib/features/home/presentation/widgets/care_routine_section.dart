import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../shelf/data/models/daily_routine_model.dart';
import '../../../shelf/presentation/controllers/routine_controller.dart';
import '../../../shelf/presentation/controllers/shelf_controller.dart';
import 'care_routine_sheet.dart';

class CareRoutineSection extends ConsumerStatefulWidget {
  const CareRoutineSection({super.key});

  @override
  ConsumerState<CareRoutineSection> createState() => _CareRoutineSectionState();
}

class _CareRoutineSectionState extends ConsumerState<CareRoutineSection>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Trigger load after the first frame so ref is available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(routineProvider.notifier).loadAndSync();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-check on every app resume — handles the case where the user kept the
  /// app open overnight. [loadAndSync] re-syncs with both Firestore and shelf.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(routineProvider.notifier).loadAndSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final routineAsync = ref.watch(routineProvider);

    // Watch the shelf so newly added products appear immediately without
    // requiring an app restart. [syncWithShelf] is a no-op when nothing changed.
    ref.listen<ShelfState>(shelfProvider, (_, next) {
      final shelf = next.data;
      if (shelf != null) {
        ref.read(routineProvider.notifier).syncWithShelf(shelf);
      }
    });

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: w * 0.051),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ваш уход сегодня',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.primaryLight,
              fontWeight: FontWeight.w300,
            ),
          ),
          SizedBox(height: w * 0.030),
          routineAsync.when(
            loading: () => _RoutineRow(w: w, morning: null, evening: null),
            error: (_, __) => _RoutineRow(w: w, morning: null, evening: null),
            data: (routine) => _RoutineRow(
              w: w,
              morning: routine?.morningRoutine,
              evening: routine?.eveningRoutine,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Row of two cards ──────────────────────────────────────────────────────────

class _RoutineRow extends StatelessWidget {
  const _RoutineRow({
    required this.w,
    required this.morning,
    required this.evening,
  });

  final double w;
  final RoutineSlotModel? morning;
  final RoutineSlotModel? evening;

  @override
  Widget build(BuildContext context) {
    // IntrinsicHeight makes both cards adopt the height of the taller one,
    // so they always look like a matched pair.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _RoutineCard(
              assetPath: 'assets/icons/ic_sun.svg',
              label: 'Утренний уход',
              slot: morning,
              isEvening: false,
              w: w,
            ),
          ),
          SizedBox(width: w * 0.030),
          Expanded(
            child: _RoutineCard(
              assetPath: 'assets/icons/ic_moon.svg',
              label: 'Вечерний уход',
              slot: evening,
              isEvening: true,
              w: w,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Single routine card ───────────────────────────────────────────────────────

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({
    required this.assetPath,
    required this.label,
    required this.slot,
    required this.isEvening,
    required this.w,
  });

  final String assetPath;
  final String label;
  final RoutineSlotModel? slot;
  final bool isEvening;
  final double w;

  @override
  Widget build(BuildContext context) {
    final total = slot?.totalCount ?? 0;
    final done = slot?.doneCount ?? 0;
    final isComplete = slot?.isComplete ?? false;

    return GestureDetector(
      onTap: () => showRoutineSheet(context, isEvening: isEvening),
      child: Container(
        // No fixed height — card sizes to content.
        // minHeight preserves the original visual feel on large screens.
        constraints: BoxConstraints(minHeight: w * 0.200),
        padding: EdgeInsets.all(w * 0.038),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          border: isComplete
              ? Border.all(color: AppColors.golden, width: 1)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // never taller than its children need
          children: [
            // Icon row: icon + optional completion badge
            Row(
              children: [
                SvgPicture.asset(
                  assetPath,
                  width: w * 0.071,
                  height: w * 0.071,
                ),
                if (isComplete) ...[
                  const Spacer(),
                  Icon(
                    Icons.check_circle_rounded,
                    size: w * 0.043,
                    color: AppColors.golden,
                  ),
                ],
              ],
            ),
            SizedBox(height: w * 0.025),
            // Label — single line, ellipsis on overflow
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelMedium.copyWith(
                fontWeight: FontWeight.w500,
                letterSpacing: -0.5,
                height: 1.2, // tighter line-height to save vertical space
              ),
            ),
            SizedBox(height: w * 0.008),
            // Subtitle: product count or progress — single line
            if (slot == null)
              _SubtitleText('Загрузка…', w: w)
            else if (total == 0)
              _SubtitleText('Нет средств', w: w)
            else if (done == 0)
              _SubtitleText(_pluralProducts(total), w: w)
            else
              _SubtitleText('$done из $total', w: w),
            // Mini progress bar — only when there are products
            if (total > 0) ...[
              SizedBox(height: w * 0.010),
              _ProgressBar(value: done / total, w: w),
            ],
          ],
        ),
      ),
    );
  }

  /// Returns "N средство/средства/средств" in Russian.
  static String _pluralProducts(int n) {
    if (n % 10 == 1 && n % 100 != 11) return '$n средство';
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) {
      return '$n средства';
    }
    return '$n средств';
  }
}

class _SubtitleText extends StatelessWidget {
  const _SubtitleText(this.text, {required this.w});

  final String text;
  final double w;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'SF Pro',
        fontSize: w * 0.028,
        fontWeight: FontWeight.w400,
        color: AppColors.primaryMedium,
        letterSpacing: -0.3,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value, required this.w});

  final double value; // 0.0 – 1.0
  final double w;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 3,
        backgroundColor: AppColors.progressBarBack,
        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.golden),
      ),
    );
  }
}
