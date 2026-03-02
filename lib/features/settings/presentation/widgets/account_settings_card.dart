import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

// ── Row data ──────────────────────────────────────────────────────────────────

/// Configuration for a single row inside [AccountSettingsCard].
class AccountRowData {
  const AccountRowData({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  /// Path to an SVG asset (e.g. `'assets/icons/ic_person.svg'`).
  final String icon;

  /// Primary label. Supports `\n` for multi-line titles (e.g. notifications row).
  final String title;

  /// Optional subtitle shown in [AppTextStyles.rowCaption].
  /// Pass the placeholder string when the real value is absent so the
  /// screen can always supply a non-null value here.
  final String? subtitle;

  /// Optional trailing widget — [AccountArrowIcon], [AccountNotificationsToggle],
  /// or null / [SizedBox.shrink] for rows with no trailing element.
  final Widget? trailing;

  /// Tap callback. Null makes the row visually inert (no ripple).
  final VoidCallback? onTap;
}

// ── Card ──────────────────────────────────────────────────────────────────────

/// White rounded card that stacks a list of [AccountRowData] with hairline
/// dividers between them.
///
/// Uses [Material] + [Clip.antiAlias] so [InkWell] ripples are clipped to
/// the card's rounded corners.
///
/// Border radius: 15 px (w × 0.038, 393 px reference).
class AccountSettingsCard extends StatelessWidget {
  const AccountSettingsCard({
    super.key,
    required this.w,
    required this.rows,
  });

  final double w;
  final List<AccountRowData> rows;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(w * 0.038); // 15 / 393
    return Material(
      color: AppColors.surface,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            _SettingsRow(w: w, data: rows[i]),
            if (i < rows.length - 1)
              const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.progressBarBack,
              ),
          ],
        ],
      ),
    );
  }
}

// ── Row (private) ─────────────────────────────────────────────────────────────

/// A single tappable row: icon | title + optional subtitle | trailing widget.
///
/// Figma measurements (393 px reference):
///   • Row height: 64 px  → 20 px vertical padding top/bottom
///   • Icon left inset: 20 px from card edge
///   • Icon size: 18 px
///   • Icon → text gap: 14 px
///   • Text starts at 52 px from card edge (Figma: left-[72px] – 20px card margin)
///   • Trailing right inset: 20 px from card edge
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.w, required this.data});

  final double w;
  final AccountRowData data;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: data.onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: w * 0.051,  // 20 px
          horizontal: w * 0.051, // 20 px
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SvgPicture.asset(
              data.icon,
              width: w * 0.046,  // 18 px
              height: w * 0.046,
              colorFilter: const ColorFilter.mode(
                AppColors.golden,
                BlendMode.srcIn,
              ),
            ),
            SizedBox(width: w * 0.036), // 14 px icon → text gap
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(data.title, style: AppTextStyles.rowTitle),
                  if (data.subtitle != null)
                    Text(data.subtitle!, style: AppTextStyles.rowCaption),
                ],
              ),
            ),
            if (data.trailing != null) data.trailing!,
          ],
        ),
      ),
    );
  }
}
