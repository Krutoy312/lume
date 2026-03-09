import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../progress/presentation/widgets/metrics/tracked_metrics_provider.dart';

// ── Data ──────────────────────────────────────────────────────────────────────

const List<(String, String)> _goals = [
  ('Чистота кожи',           'clear_skin'),
  ('Контроль жирности кожи', 'oil_control'),
  ('Гладкая текстура кожи',  'texture'),
  ('Баланс увлажнённости',   'hydration_balance'),
  ('Упругость и тонус кожи', 'firmness'),
  ('Поддерживать состояние', 'maintenance'),
];

/// Public reverse-lookup: Firestore value → Russian display label.
String? goalLabel(String? value) {
  if (value == null) return null;
  for (final (label, v) in _goals) {
    if (v == value) return label;
  }
  return null;
}

// ── Launcher ──────────────────────────────────────────────────────────────────

Future<void> showGoalBottomSheet(
  BuildContext context, {
  String? currentGoal,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: const Color(0x80000000),
    builder: (_) => ColoredBox(
      color: Colors.transparent,
      child: GoalBottomSheet(currentGoal: currentGoal),
    ),
  );
}

// ── Widget ────────────────────────────────────────────────────────────────────

class GoalBottomSheet extends ConsumerStatefulWidget {
  const GoalBottomSheet({super.key, this.currentGoal});

  final String? currentGoal;

  @override
  ConsumerState<GoalBottomSheet> createState() => _GoalBottomSheetState();
}

class _GoalBottomSheetState extends ConsumerState<GoalBottomSheet> {
  bool _loading = false;

  Future<void> _onSelect(String value) async {
    if (_loading) return;
    setState(() => _loading = true);

    final metrics = mandatoryMetricsForGoal(value);
    await ref.read(authControllerProvider.notifier).updateGoal(value, metrics);
    if (!mounted) return;

    final authState = ref.read(authControllerProvider);
    if (authState is AsyncError) {
      setState(() => _loading = false);
    } else {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final sysPad = MediaQuery.paddingOf(context).bottom;
    final bottomPad = (sysPad > 0 ? sysPad : 0.0) + 24.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        w * 0.051,
        w * 0.061,
        w * 0.051,
        bottomPad,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(w: w),
          SizedBox(height: w * 0.061),
          for (var i = 0; i < _goals.length; i++) ...[
            _GoalRow(
              w: w,
              label: _goals[i].$1,
              isSelected: _goals[i].$2 == widget.currentGoal,
              enabled: !_loading,
              onTap: () => _onSelect(_goals[i].$2),
            ),
            if (i < _goals.length - 1) SizedBox(height: w * 0.031),
          ],
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.w});

  final double w;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Выберите цель',
            style: AppTextStyles.rowTitle.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryDark,
              letterSpacing: -0.5,
            ),
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.of(context, rootNavigator: true).pop(),
          child: SvgPicture.asset(
            'assets/icons/ic_close.svg',
            width: w * 0.041,
            height: w * 0.041,
            colorFilter: const ColorFilter.mode(
              AppColors.primaryMedium,
              BlendMode.srcIn,
            ),
          ),
        ),
      ],
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({
    required this.w,
    required this.label,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
  });

  final double w;
  final String label;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: w * 0.102,
        padding: EdgeInsets.symmetric(horizontal: w * 0.051),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.progressBarGradient : null,
          color: isSelected ? null : const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(15),
        ),
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: AppTextStyles.rowTitle.copyWith(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.primaryDark,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}
