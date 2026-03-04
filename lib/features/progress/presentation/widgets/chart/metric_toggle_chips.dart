import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../../core/theme/app_colors.dart';
import '../metrics/assessment_provider.dart';

// Unselected chip text/icon color — #BB8E5E (warm caramel, per Figma spec).
const _kUnselectedColor = Color(0xFFBB8E5E);

/// 2-column grid of tappable metric chips.
///
/// Selected chip: [AppColors.progressBarBack] background, bold text.
/// Unselected chip: transparent background, [AppColors.golden] border, light text.
///
/// Filters [kAllMetrics] down to [trackedKeys] and lays them out in pairs.
class MetricToggleChips extends StatelessWidget {
  const MetricToggleChips({
    super.key,
    required this.trackedKeys,
    required this.selectedKey,
    required this.onSelected,
  });

  final List<String> trackedKeys;
  final String selectedKey;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final gap = w * 0.030;

    final metrics =
        kAllMetrics.where((m) => trackedKeys.contains(m.key)).toList();

    // Build rows of 2 chips.
    final rows = <Widget>[];
    for (var i = 0; i < metrics.length; i += 2) {
      rows.add(
        Row(
          children: [
            Expanded(
              child: _Chip(
                meta: metrics[i],
                isSelected: metrics[i].key == selectedKey,
                onTap: () => onSelected(metrics[i].key),
                w: w,
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: i + 1 < metrics.length
                  ? _Chip(
                      meta: metrics[i + 1],
                      isSelected: metrics[i + 1].key == selectedKey,
                      onTap: () => onSelected(metrics[i + 1].key),
                      w: w,
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
      if (i + 2 < metrics.length) rows.add(SizedBox(height: w * 0.025));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

// ── Single chip ───────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({
    required this.meta,
    required this.isSelected,
    required this.onTap,
    required this.w,
  });

  final MetricMeta meta;
  final bool isSelected;
  final VoidCallback onTap;
  final double w;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        height: w * 0.074, // ≈ 29px at 393px reference width
        decoration: isSelected
            ? BoxDecoration(
                color: AppColors.progressBarBack,
                borderRadius: BorderRadius.circular(16),
              )
            : BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.golden, width: 1),
              ),
        padding: EdgeInsets.symmetric(horizontal: w * 0.030),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              meta.iconPath,
              width: 14,
              height: 14,
              colorFilter: ColorFilter.mode(
                isSelected ? AppColors.primaryDark : _kUnselectedColor,
                BlendMode.srcIn,
              ),
            ),
            SizedBox(width: w * 0.015),
            Flexible(
              child: Text(
                meta.label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'SF Pro',
                  fontSize: 13,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w300,
                  color: isSelected ? AppColors.primaryDark : _kUnselectedColor,
                  letterSpacing: -0.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
