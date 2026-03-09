import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/providers/shell_tab_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class SkinAssessmentButton extends ConsumerWidget {
  const SkinAssessmentButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = MediaQuery.sizeOf(context).width;
    final hPad = w * 0.051;

    return GestureDetector(
      onTap: () {
        ref.read(shellTabProvider.notifier).state = 1; // Progress tab
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: hPad),
        height: w * 0.244,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Arrow decoration
            Positioned(
              right: w * 0.023,
              top: 0,
              bottom: 0,
              child: SvgPicture.asset(
                'assets/images/img_arrow.svg',
                fit: BoxFit.contain,
              ),
            ),
            // Text content
            Positioned(
              left: w * 0.061,
              top: 0,
              bottom: 0,
              width: w * 0.590,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Оценить состояние\nкожи сегодня!',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.alertRed,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    letterSpacing: -1.1,
                    height: 1.27,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
