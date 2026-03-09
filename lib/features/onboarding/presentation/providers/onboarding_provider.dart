import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/onboarding_service.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class OnboardingState {
  const OnboardingState({
    this.currentStep = 1,
    this.q1OilWeight = 0.0,
    this.q1DryWeight = 0.0,
    this.q2OilWeight = 0.0,
    this.q3DryWeight = 0.0,
    this.selectedGoal,
    this.birthDate,
    this.gender,
    this.submissionState = const AsyncData(null),
  });

  final int currentStep; // 1–7
  final double q1OilWeight;
  final double q1DryWeight;
  final double q2OilWeight;
  final double q3DryWeight;
  final String? selectedGoal; // 'clear_skin' | 'oil_control' | etc.
  final DateTime? birthDate;
  final String? gender; // 'male' | 'female'
  final AsyncValue<void> submissionState;

  // ── Computed: skin type ──────────────────────────────────────────────────────

  /// Derives skin type from the weighted answers of Q1–Q3.
  ///
  /// oil_score  = (q1_oil + q2_oil) / 2
  /// dry_score  = (q1_dry + q3_dry) / 2
  String get skinType {
    final oilScore = (q1OilWeight + q2OilWeight) / 2;
    final dryScore = (q1DryWeight + q3DryWeight) / 2;
    if (oilScore >= 3.5) return 'oily';
    if (dryScore >= 3.5) return 'dry';
    if (oilScore >= 2.5) return 'combo';
    return 'normal';
  }

  // ── Computed: tracked metrics ────────────────────────────────────────────────

  /// Returns 4 metric keys to track based on the chosen goal.
  List<String> get trackedMetrics {
    switch (selectedGoal) {
      case 'clear_skin':
        return ['skinClarity', 'porePurity', 'sebumBalance', 'smoothness'];
      case 'oil_control':
        return ['sebumBalance', 'porePurity', 'hydration', 'skinClarity'];
      case 'hydration_balance':
        return ['hydration', 'elasticity', 'evenTone', 'smoothness'];
      case 'texture':
        return ['smoothness', 'skinClarity', 'hydration', 'porePurity'];
      case 'firmness':
        return ['elasticity', 'evenTone', 'hydration', 'smoothness'];
      case 'maintenance':
        return ['sebumBalance', 'hydration', 'elasticity', 'skinClarity'];
      default:
        return ['hydration', 'elasticity', 'skinClarity', 'smoothness'];
    }
  }

  OnboardingState copyWith({
    int? currentStep,
    double? q1OilWeight,
    double? q1DryWeight,
    double? q2OilWeight,
    double? q3DryWeight,
    String? selectedGoal,
    DateTime? birthDate,
    String? gender,
    AsyncValue<void>? submissionState,
  }) =>
      OnboardingState(
        currentStep: currentStep ?? this.currentStep,
        q1OilWeight: q1OilWeight ?? this.q1OilWeight,
        q1DryWeight: q1DryWeight ?? this.q1DryWeight,
        q2OilWeight: q2OilWeight ?? this.q2OilWeight,
        q3DryWeight: q3DryWeight ?? this.q3DryWeight,
        selectedGoal: selectedGoal ?? this.selectedGoal,
        birthDate: birthDate ?? this.birthDate,
        gender: gender ?? this.gender,
        submissionState: submissionState ?? this.submissionState,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  OnboardingNotifier() : super(const OnboardingState());

  void answerQ1({required double oilWeight, required double dryWeight}) {
    state = state.copyWith(
      q1OilWeight: oilWeight,
      q1DryWeight: dryWeight,
      currentStep: 2,
    );
  }

  void answerQ2(double oilWeight) {
    state = state.copyWith(q2OilWeight: oilWeight, currentStep: 3);
  }

  void answerQ3(double dryWeight) {
    state = state.copyWith(q3DryWeight: dryWeight, currentStep: 4);
  }

  void answerQ4() {
    state = state.copyWith(currentStep: 5);
  }

  void answerQ5() {
    state = state.copyWith(currentStep: 6);
  }

  void selectGoal(String goal) {
    state = state.copyWith(selectedGoal: goal, currentStep: 7);
  }

  void setBirthDate(DateTime date) {
    state = state.copyWith(birthDate: date);
  }

  void setGender(String gender) {
    state = state.copyWith(gender: gender);
  }

  void goBack() {
    if (state.currentStep > 1) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  Future<void> submit() async {
    final goal = state.selectedGoal;
    final birthDate = state.birthDate;
    final gender = state.gender;
    if (goal == null || birthDate == null || gender == null) return;

    state = state.copyWith(submissionState: const AsyncLoading());
    state = state.copyWith(
      submissionState: await AsyncValue.guard(
        () => OnboardingService.saveProfile(
          skinType: state.skinType,
          goal: goal,
          birthDate: birthDate,
          gender: gender,
          trackedMetrics: state.trackedMetrics,
        ),
      ),
    );
  }
}

final onboardingProvider =
    StateNotifierProvider.autoDispose<OnboardingNotifier, OnboardingState>(
  (_) => OnboardingNotifier(),
);
