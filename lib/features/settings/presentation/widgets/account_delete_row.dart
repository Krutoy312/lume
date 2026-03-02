import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Standalone destructive row for "Удалить аккаунт".
///
/// Not wrapped in a card — sits directly in the scroll column.
/// Uses [ic_del.svg] (red ×) followed by the label in [AppColors.alertRed].
///
/// Figma measurements (393 px reference):
///   • Icon: 12 px  (x=40 from screen → x=20 from content area after hPad)
///   • Icon → text gap: 8 px  (text at x=60 from screen)
class AccountDeleteRow extends StatelessWidget {
  const AccountDeleteRow({super.key, required this.w, required this.onTap});

  final double w;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(w * 0.038),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: w * 0.031,  // 12 px tap-target padding
          horizontal: w * 0.051, // 20 px — aligns icon with card rows
        ),
        child: Row(
          children: [
            SvgPicture.asset(
              'assets/icons/ic_del.svg',
              width: w * 0.031,  // 12 px
              height: w * 0.031,
              colorFilter: const ColorFilter.mode(
                AppColors.alertRed,
                BlendMode.srcIn,
              ),
            ),
            SizedBox(width: w * 0.020), // 8 px gap
            Text('Удалить аккаунт', style: AppTextStyles.labelMediumAlert),
          ],
        ),
      ),
    );
  }
}
