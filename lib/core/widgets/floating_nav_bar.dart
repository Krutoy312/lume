import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';

/// Floating bottom navigation bar matching Figma node 168:1147.
///
/// Reference screen width: 393 px (iPhone 14).
/// The bar is a white rounded card that floats above the system safe area
/// with horizontal margins on both sides.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;

  // Paired icon paths: [thin/unselected, bold/selected]
  static const _icons = [
    ['assets/icons/ic_shelf_t.svg', 'assets/icons/ic_shelf_b.svg'],
    ['assets/icons/ic_progress_t.svg', 'assets/icons/ic_progress_b.svg'],
    ['assets/icons/ic_home_t.svg', 'assets/icons/ic_home_b.svg'],
    ['assets/icons/ic_chat_t.svg', 'assets/icons/ic_chat_b.svg'],
    ['assets/icons/ic_account_t.svg', 'assets/icons/ic_account_b.svg'],
  ];

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    // System safe area (home indicator on iPhone, navigation bar on Android)
    final systemBottomPad = MediaQuery.of(context).padding.bottom;

    // Proportions from Figma (353×67 bar in 393-wide frame, x=20 margin)
    final hMargin = w * 0.051; // 20 / 393
    final barHeight = w * 0.171; // 67 / 393
    final bottomMargin = w * 0.041; // 16 px visual gap above safe area
    final borderRadius = w * 0.041; // 16 / 393
    final iconSize = w * 0.061; // 24 / 393
    final dotSize = w * 0.015; // 6  / 393
    final dotGap = w * 0.020; // ~8 px gap between icon bottom and dot

    return Padding(
      padding: EdgeInsets.fromLTRB(
        hMargin,
        0,
        hMargin,
        bottomMargin + systemBottomPad,
      ),
      child: Container(
        height: barHeight,
        decoration: BoxDecoration(
          // Figma background: #FEFDFC
          color: const Color(0xFFFEFDFC),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
          boxShadow: const [
            // Figma: 0px 29px 32px 0px rgba(150,110,59,0.05)
            BoxShadow(
              color: Color(0x0D966E3B),
              blurRadius: 32,
              offset: Offset(0, 29),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_icons.length, (i) {
            final isSelected = i == selectedIndex;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: w * 0.01),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      isSelected ? _icons[i][1] : _icons[i][0],
                      width: iconSize,
                      height: iconSize,
                      colorFilter: ColorFilter.mode(
                        isSelected ? AppColors.golden : AppColors.primaryLight,
                        BlendMode.srcIn,
                      ),
                    ),
                    SizedBox(height: dotGap),
                    // Dot indicator — visible only when selected; keeps
                    // consistent height for both states.
                    Container(
                      width: dotSize,
                      height: dotSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? AppColors.golden
                            : Colors.transparent,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
