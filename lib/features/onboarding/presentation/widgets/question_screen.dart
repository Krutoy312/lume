import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

// ── Data model ────────────────────────────────────────────────────────────────

class QuizOption {
  const QuizOption({required this.text});
  final String text;
}

// ── Screen ────────────────────────────────────────────────────────────────────

/// A single step in the onboarding quiz.
///
/// Shows a progress bar, step label, question, and tappable answer options.
/// Tapping an option briefly highlights it (200 ms) and then calls
/// [onOptionSelected] with the zero-based index so the parent can advance.
class QuestionScreen extends StatefulWidget {
  const QuestionScreen({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.question,
    required this.options,
    required this.onOptionSelected,
  });

  final int step;
  final int totalSteps;
  final String question;
  final List<String> options;
  final void Function(int index) onOptionSelected;

  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {
  int? _selectedIndex;

  Future<void> _onTap(int index) async {
    if (_selectedIndex != null) return; // ignore while animating
    setState(() => _selectedIndex = index);
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (mounted) widget.onOptionSelected(index);
  }

  @override
  void didUpdateWidget(QuestionScreen old) {
    super.didUpdateWidget(old);
    // Reset selection when the question changes (step advanced).
    if (old.step != widget.step) _selectedIndex = null;
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final hPad = w * 0.051; // ~20 px

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: w * 0.122), // ~48 px — top of progress bar
                _ProgressBar(
                  step: widget.step,
                  totalSteps: widget.totalSteps,
                  w: w,
                ),
                SizedBox(height: w * 0.036), // ~14 px
                _StepLabel(
                  step: widget.step,
                  totalSteps: widget.totalSteps,
                ),
                SizedBox(height: w * 0.107), // ~42 px — gap to question
                Text(
                  widget.question,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.rowTitle.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                    letterSpacing: -0.5,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: w * 0.102), // ~40 px — gap to first option
                Column(
                  children: [
                    for (int i = 0; i < widget.options.length; i++) ...[
                      _AnswerOption(
                        text: widget.options[i],
                        isSelected: _selectedIndex == i,
                        onTap: () => _onTap(i),
                        w: w,
                      ),
                      if (i < widget.options.length - 1)
                        SizedBox(height: w * 0.040), // ~16 px gap
                    ],
                  ],
                ),
                SizedBox(height: w * 0.081), // ~32 px bottom breathing room
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Progress bar ──────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.step,
    required this.totalSteps,
    required this.w,
  });

  final int step;
  final int totalSteps;
  final double w;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final fillWidth = (step / totalSteps) * constraints.maxWidth;
        return Stack(
          children: [
            // Track
            Container(
              height: w * 0.0305, // ~12 px
              decoration: BoxDecoration(
                color: AppColors.progressBarBack,
                borderRadius: BorderRadius.circular(w * 0.040),
              ),
            ),
            // Fill
            Container(
              height: w * 0.0305,
              width: fillWidth,
              decoration: BoxDecoration(
                gradient: AppColors.progressBarGradient,
                borderRadius: BorderRadius.circular(w * 0.040),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Step label ────────────────────────────────────────────────────────────────

class _StepLabel extends StatelessWidget {
  const _StepLabel({required this.step, required this.totalSteps});

  final int step;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Шаг $step из $totalSteps',
      style: AppTextStyles.rowTitle.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w300,
        color: AppColors.primaryMedium,
        letterSpacing: 0,
      ),
    );
  }
}

// ── Answer option ─────────────────────────────────────────────────────────────

class _AnswerOption extends StatelessWidget {
  const _AnswerOption({
    required this.text,
    required this.isSelected,
    required this.onTap,
    required this.w,
  });

  final String text;
  final bool isSelected;
  final VoidCallback onTap;
  final double w;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: w * 0.112, // ~44 px
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: w * 0.051),
        decoration: isSelected
            ? BoxDecoration(
                gradient: AppColors.progressBarGradient,
                borderRadius: BorderRadius.circular(w * 0.038),
              )
            : BoxDecoration(
                color: AppColors.scaffoldBackground,
                border: Border.all(color: const Color(0xFFD9D9D9)),
                borderRadius: BorderRadius.circular(w * 0.038),
              ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: AppTextStyles.rowTitle.copyWith(
            fontSize: isSelected ? 16.0 : 14.0,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.primaryDark,
            letterSpacing: -0.5,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
