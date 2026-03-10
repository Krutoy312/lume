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
              // Mascot
              SizedBox(
                width: w * 0.305,
                height: w * 0.376,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Image.asset(
                    'assets/images/img_mascot.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              SizedBox(width: w * 0.03),
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Совет от Lume:',
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
            ],
          ),
        ),
      ),
    );
  }
}
