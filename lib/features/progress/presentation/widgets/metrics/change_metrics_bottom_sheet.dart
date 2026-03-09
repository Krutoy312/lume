import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../../core/theme/app_colors.dart';
import 'assessment_provider.dart';

/// Modal bottom sheet for selecting which metrics to track.
///
/// Mirrors Figma node 281:1439.  Each metric in [kAllMetrics] is shown as a
/// tappable white card.  Selected cards are slightly taller and show
/// `ic_check_mark.svg` on the right; unselected cards grey out the icon.
///
/// [onSelectionChanged] is called on every toggle so the caller can capture
/// the latest selection regardless of how the sheet is dismissed (swipe,
/// backdrop tap, back gesture).  The minimum selection is 1 metric.
///
/// Usage:
/// ```dart
/// List<String> latest = currentTracked;
/// await ChangeMetricsBottomSheet.show(
///   context,
///   initialTracked: currentTracked,
///   onSelectionChanged: (v) => latest = v,
/// );
/// // Persist `latest` to Firestore here — fired for any dismissal path.
/// ```
class ChangeMetricsBottomSheet extends StatefulWidget {
  const ChangeMetricsBottomSheet({
    super.key,
    required this.initialTracked,
    required this.onSelectionChanged,
    this.mandatoryMetrics = const {},
  });

  final List<String> initialTracked;
  final ValueChanged<List<String>> onSelectionChanged;

  /// Metric keys that cannot be deselected (required by the user's goal).
  final Set<String> mandatoryMetrics;

  /// Convenience factory — shows the sheet and returns when dismissed.
  static Future<void> show(
    BuildContext context, {
    required List<String> initialTracked,
    required ValueChanged<List<String>> onSelectionChanged,
    Set<String> mandatoryMetrics = const {},
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeMetricsBottomSheet(
        initialTracked: initialTracked,
        onSelectionChanged: onSelectionChanged,
        mandatoryMetrics: mandatoryMetrics,
      ),
    );
  }

  @override
  State<ChangeMetricsBottomSheet> createState() =>
      _ChangeMetricsBottomSheetState();
}

class _ChangeMetricsBottomSheetState extends State<ChangeMetricsBottomSheet> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.initialTracked);
  }

  void _toggle(String key) {
    if (_selected.contains(key)) {
      // Block removal of mandatory metrics.
      if (widget.mandatoryMetrics.contains(key)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Этот показатель обязателен для вашей цели и не может быть отключён.',
            ),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
      if (_selected.length <= 1) return; // always keep at least one metric
      _selected.remove(key);
    } else {
      _selected.add(key);
    }
    setState(() {});
    widget.onSelectionChanged(List.from(_selected));
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.scaffoldBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Drag handle ─────────────────────────────────────────────────
              Center(
                child: Container(
                  margin: EdgeInsets.only(top: w * 0.030),
                  width: w * 0.102,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD9D9D9),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              SizedBox(height: w * 0.038),

              // ── Header card ─────────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.symmetric(horizontal: w * 0.051),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: w * 0.051,
                    vertical: w * 0.038,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(w * 0.038),
                  ),
                  child: const Text(
                    'Выбери что хочешь\nотслеживать!',
                    style: TextStyle(
                      fontFamily: 'SF Pro',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                      height: 1.15,
                      letterSpacing: -0.6,
                    ),
                  ),
                ),
              ),

              SizedBox(height: w * 0.046),

              // ── Section label ───────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.only(left: w * 0.051),
                child: const Text(
                  'Состояние кожи',
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 16,
                    fontWeight: FontWeight.w300,
                    color: AppColors.primaryLight,
                  ),
                ),
              ),

              SizedBox(height: w * 0.025),

              // ── Metric tiles ────────────────────────────────────────────────
              for (final m in kAllMetrics)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    w * 0.051,
                    0,
                    w * 0.051,
                    w * 0.020,
                  ),
                  child: _MetricTile(
                    meta: m,
                    isSelected: _selected.contains(m.key),
                    isMandatory: widget.mandatoryMetrics.contains(m.key),
                    onTap: () => _toggle(m.key),
                    w: w,
                  ),
                ),

              SizedBox(height: w * 0.020),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Metric tile ────────────────────────────────────────────────────────────────

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.meta,
    required this.isSelected,
    required this.isMandatory,
    required this.onTap,
    required this.w,
  });

  final MetricMeta meta;
  final bool isSelected;
  final bool isMandatory;
  final VoidCallback onTap;
  final double w;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        // Selected tiles are slightly taller — matches Figma (52px vs 44px).
        height: isSelected ? w * 0.132 : w * 0.112,
        padding: EdgeInsets.symmetric(horizontal: w * 0.046),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(w * 0.038),
        ),
        child: Row(
          children: [
            // Icon: golden when selected, #E3E3E3 when unselected.
            SvgPicture.asset(
              meta.iconPath,
              width: w * 0.051,
              height: w * 0.051,
              colorFilter: ColorFilter.mode(
                isSelected ? AppColors.golden : const Color(0xFFE3E3E3),
                BlendMode.srcIn,
              ),
            ),
            SizedBox(width: w * 0.038),
            // Label.
            Expanded(
              child: Text(
                meta.label,
                style: const TextStyle(
                  fontFamily: 'SF Pro',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryDark,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            // Trailing: lock for mandatory, check mark for freely selected.
            if (isMandatory)
              Icon(
                Icons.lock_outline_rounded,
                size: w * 0.046,
                color: isSelected
                    ? AppColors.golden.withValues(alpha: 0.6)
                    : const Color(0xFFE3E3E3),
              )
            else if (isSelected)
              SvgPicture.asset(
                'assets/icons/ic_check_mark.svg',
                width: w * 0.051,
                height: w * 0.051,
              ),
          ],
        ),
      ),
    );
  }
}
