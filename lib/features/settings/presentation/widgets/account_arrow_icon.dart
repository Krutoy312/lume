import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';

/// Right-pointing chevron icon used as the trailing element in settings rows.
///
/// Applies the same transforms Figma specifies: rotate 90° CW + flip Y,
/// which converts [ic_arrow.svg] (assumed down-pointing) into a right-pointing
/// chevron (→).
///
/// Size: 12 × 6 px at 393 px reference width.
class AccountArrowIcon extends StatelessWidget {
  const AccountArrowIcon({super.key, required this.w});

  /// Screen width from [MediaQuery.sizeOf].
  final double w;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/ic_arrow.svg',
      width: w * 0.031, // 12 px
      height: w * 0.015, // 6 px
      colorFilter: const ColorFilter.mode(
        AppColors.primaryLight,
        BlendMode.srcIn,
      ),
    );
  }
}
