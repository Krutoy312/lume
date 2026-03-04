import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../widgets/metrics/daily_assessment_section.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final hPad = w * 0.051;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(hPad, w * 0.084, hPad, w * 0.076),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Прогресс',
                style: AppTextStyles.displayMedium,
              ),
              SizedBox(height: w * 0.061),

              // ── Daily skin-state assessment ────────────────────────────
              const DailyAssessmentSection(),

              // Future sections (charts, calendar, streak card) go here.
              SizedBox(height: w * 0.030),
            ],
          ),
        ),
      ),
    );
  }
}
