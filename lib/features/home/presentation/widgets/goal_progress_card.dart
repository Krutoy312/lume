import 'dart:math' show pi;

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class GoalProgressCard extends StatelessWidget {
  const GoalProgressCard({super.key});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final hPad = w * 0.051;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: hPad),
      padding: EdgeInsets.fromLTRB(w * 0.061, w * 0.056, w * 0.061, w * 0.061),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Цель:',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.primaryLight,
              fontWeight: FontWeight.w300,
            ),
          ),
          SizedBox(height: w * 0.046),
          Text(
            'Увеличить матовость кожи',
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: w * 0.041),
          // Progress bar track + fill
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            child: Stack(
              children: [
                Container(
                  height: 12,
                  decoration: const BoxDecoration(
                    color: AppColors.progressBarBack,
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: 0.30,
                  child: Container(
                    height: 12,
                    decoration: const BoxDecoration(
                      gradient: AppColors.progressBarGradient,
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: w * 0.013),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Прогресс:',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.primaryMedium,
                ),
              ),
              Text(
                '30%',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.primaryMedium,
                ),
              ),
            ],
          ),
          SizedBox(height: w * 0.051),
          // Advice lamp card
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: w * 0.038,
              vertical: w * 0,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-1.0, 0.0),
                end: Alignment(1.0, 0.0),
                stops: [0.092, 0.908],
                colors: [AppColors.adviceLampStart, AppColors.adviceLampEnd],
              ),
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Transform.rotate(
                    angle: 0,
                    child: Image.asset(
                      'assets/images/img_light_bulb.png',
                      width: w * 0.17,
                      fit: BoxFit.contain,
                    ),
                  ),
                  SizedBox(width: w * 0.02),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: RichText(
                        textAlign: TextAlign.right,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Матовость увелиилась с 6 до 8\n',
                              style: AppTextStyles.labelMedium.copyWith(
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF6B5446),
                                letterSpacing: -0.5,
                              ),
                            ),
                            TextSpan(
                              text: 'Вы на правильном пути!',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: const Color(0xFF6B5446),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
