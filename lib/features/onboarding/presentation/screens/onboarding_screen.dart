import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/onboarding_provider.dart';
import '../widgets/personal_data_screen.dart';
import '../widgets/question_screen.dart';

// ── Quiz question definitions ─────────────────────────────────────────────────

class _Q1Option {
  const _Q1Option({
    required this.text,
    required this.oilWeight,
    required this.dryWeight,
  });
  final String text;
  final double oilWeight;
  final double dryWeight;
}

const _q1Options = [
  _Q1Option(
    text: 'Становится жирной и начинает блестеть',
    oilWeight: 4,
    dryWeight: 1,
  ),
  _Q1Option(
    text: 'Блестит только Т-зона (лоб, нос, подбородок)',
    oilWeight: 3,
    dryWeight: 1,
  ),
  _Q1Option(
    text: 'Кожа становится сухой или стянутой',
    oilWeight: 1,
    dryWeight: 4,
  ),
  _Q1Option(
    text: 'Кожа чувствует себя комфортно',
    oilWeight: 2,
    dryWeight: 2,
  ),
];

const _q2OilWeights = [4.0, 3.0, 2.0, 1.0];
const _q3DryWeights = [4.0, 3.0, 2.0, 1.0];

const _goalOptions = [
  ('Чистота кожи', 'clear_skin'),
  ('Контроль жирности кожи', 'oil_control'),
  ('Баланс увлажнённости', 'hydration_balance'),
  ('Гладкая текстура кожи', 'texture'),
  ('Упругость и тонус кожи', 'firmness'),
  ('Поддерживать состояние', 'maintenance'),
];

// ── Screen ────────────────────────────────────────────────────────────────────

/// Root onboarding screen that orchestrates all 7 steps.
///
/// Steps 1–6 are question screens; step 7 is the personal-data screen.
/// On successful submission the router automatically navigates to home.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    // Navigation to home is driven by the router: once Firestore confirms
    // onboardingCompleted = true, _AppRouterNotifier fires and GoRouter
    // automatically redirects away from /onboarding.

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && state.currentStep > 1) {
          notifier.goBack();
        }
        // On step 1 the back press is swallowed — quiz is mandatory.
      },
      child: _buildStep(state, notifier),
    );
  }

  Widget _buildStep(OnboardingState state, OnboardingNotifier notifier) {
    switch (state.currentStep) {
      case 1:
        return QuestionScreen(
          step: 1,
          totalSteps: 7,
          question:
              'Как ваша кожа чувствует себя через 2–3 часа после умывания, если не наносить уход?',
          options: _q1Options.map((o) => o.text).toList(),
          onOptionSelected: (i) => notifier.answerQ1(
            oilWeight: _q1Options[i].oilWeight,
            dryWeight: _q1Options[i].dryWeight,
          ),
        );

      case 2:
        return QuestionScreen(
          step: 2,
          totalSteps: 7,
          question: 'Как часто на коже появляется жирный блеск в течение дня?',
          options: const [
            'Почти всегда',
            'Иногда, в основном в Т-зоне',
            'Редко',
            'Почти никогда',
          ],
          onOptionSelected: (i) => notifier.answerQ2(_q2OilWeights[i]),
        );

      case 3:
        return QuestionScreen(
          step: 3,
          totalSteps: 7,
          question: 'Часто ли вы ощущаете сухость или стянутость кожи?',
          options: const [
            'Часто',
            'Иногда',
            'Редко',
            'Никогда',
          ],
          onOptionSelected: (i) => notifier.answerQ3(_q3DryWeights[i]),
        );

      case 4:
        return QuestionScreen(
          step: 4,
          totalSteps: 7,
          question: 'Как выглядят поры на вашей коже?',
          options: const [
            'Расширенные и заметные',
            'Заметны в Т-зоне (лоб, нос, подбородок)',
            'Менее заметные поры',
            'Трудно оценить',
          ],
          onOptionSelected: (_) => notifier.answerQ4(),
        );

      case 5:
        return QuestionScreen(
          step: 5,
          totalSteps: 7,
          question:
              'Насколько чувствительна ваша кожа к новым средствам или погоде?',
          options: const [
            'Очень чувствительная',
            'Иногда реагирует',
            'Редко реагирует',
            'Не замечал чувствительности',
          ],
          onOptionSelected: (_) => notifier.answerQ5(),
        );

      case 6:
        return QuestionScreen(
          step: 6,
          totalSteps: 7,
          question: 'Какая ваша главная цель ухода за кожей?',
          options: _goalOptions.map((g) => g.$1).toList(),
          onOptionSelected: (i) => notifier.selectGoal(_goalOptions[i].$2),
        );

      case 7:
      default:
        return const PersonalDataScreen();
    }
  }
}
