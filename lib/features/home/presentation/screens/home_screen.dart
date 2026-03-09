import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/care_routine_section.dart';
import '../widgets/goal_progress_card.dart';
import '../widgets/mascot_tip_card.dart';
import '../widgets/quick_actions.dart';
import '../widgets/skin_analysis_button.dart';
import '../widgets/skin_assessment_button.dart';
import '../widgets/skin_metrics_grid.dart';

/// Home screen.
///
/// Waits for the [userDocumentProvider] Firestore document to exist before
/// rendering content. This handles the race window between Firebase Auth
/// sign-in and the async `initUserDocument` Cloud Function invocation —
/// typically 200–2000 ms on a cold start.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userDocAsync = ref.watch(userDocumentProvider);

    return userDocAsync.when(
      // Firestore subscription is loading (first frame only).
      loading: () => const _AccountSetupScreen(),

      // Firestore error — show the home content anyway (graceful degradation).
      error: (_, __) => const _HomeBody(),

      data: (snapshot) {
        // Null = user not signed in (router handles redirect before this point).
        // !exists = authenticated but CF hasn't created the document yet.
        if (snapshot == null || !snapshot.exists) {
          return const _AccountSetupScreen();
        }
        return const _HomeBody();
      },
    );
  }
}

// ── Account setup loading screen ──────────────────────────────────────────────

/// Shown while [initUserDocument] Cloud Function is creating the user doc.
/// Replaces any blank flash or null-data errors that would appear otherwise.
class _AccountSetupScreen extends StatelessWidget {
  const _AccountSetupScreen();

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: AppColors.golden,
              strokeWidth: 2.5,
            ),
            SizedBox(height: w * 0.061),
            Text(
              'Настраиваем ваш профиль…',
              style: AppTextStyles.bodyLargeProgress,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Main home body ────────────────────────────────────────────────────────────

class _HomeBody extends StatelessWidget {
  const _HomeBody();

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
                child: const _Greeting(),
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

// ── Greeting ──────────────────────────────────────────────────────────────────

class _Greeting extends ConsumerWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docAsync = ref.watch(userDocumentProvider);
    final name = docAsync.when(
      data: (snap) => (snap?.data()?['name'] as String?)?.trim(),
      loading: () => null,
      error: (_, __) => null,
    );

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: 'Привет, ',
            style: AppTextStyles.displayMedium.copyWith(
              fontWeight: FontWeight.w400,
            ),
          ),
          TextSpan(
            text: name != null && name.isNotEmpty ? '$name!' : 'друг!',
            style: AppTextStyles.displayMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
