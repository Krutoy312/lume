import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../widgets/care_routine_section.dart';
import '../widgets/goal_progress_card.dart';
import '../widgets/mascot_tip_card.dart';
import '../widgets/quick_actions.dart';
import '../widgets/skin_analysis_button.dart';
import '../widgets/skin_assessment_button.dart';
import '../widgets/skin_metrics_grid.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final hPad = w * 0.051;
    final sectionGap = w * 0.061;
    final smallGap = w * 0.030;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting
              Padding(
                padding: EdgeInsets.fromLTRB(hPad, w * 0.084, hPad, 0),
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '👋 Привет, ',
                        style: AppTextStyles.displayMedium.copyWith(
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      TextSpan(
                        text: 'Caddser!',
                        style: AppTextStyles.displayMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: w * 0.061),

              // Goal + progress
              const GoalProgressCard(),
              SizedBox(height: sectionGap),

              // Skin analysis button
              const SkinAnalysisButton(),
              SizedBox(height: smallGap),

              // Rate skin state CTA
              const SkinAssessmentButton(),
              SizedBox(height: sectionGap),

              // Metrics grid
              const SkinMetricsGrid(),
              SizedBox(height: sectionGap),

              // Care routine
              const CareRoutineSection(),
              SizedBox(height: sectionGap),

              // Mascot tip
              const MascotTipCard(),
              SizedBox(height: sectionGap),

              // Quick actions
              const QuickActions(),
              SizedBox(height: sectionGap),
            ],
          ),
        ),
      ),
    );
  }
}
