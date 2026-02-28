import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class MascotTipCard extends StatelessWidget {
  const MascotTipCard({super.key});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final hPad = w * 0.051;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        child: Container(
          color: AppColors.surface,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Mascot placeholder area
              SizedBox(
                width: w * 0.305,
                height: w * 0.376,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: w * 0.229,
                      height: w * 0.229,
                      decoration: BoxDecoration(
                        color: AppColors.progressBarBack,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Text(
                      '🧴',
                      style: TextStyle(fontSize: w * 0.127),
                    ),
                  ],
                ),
              ),
              // Text content
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(0, w * 0.046, w * 0.046, w * 0.046),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Совет от Бубылька:',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.amber,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: w * 0.020),
                      Text(
                        'Наносите увлажняющий крем сразу после умывания, чтобы закрепить влагу в коже. Это особенно важно утром!',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: const Color(0xFF6B5446),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
