import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/mock_assessments_generator.dart';
import '../widgets/chart/metrics_chart_widget.dart';
import '../widgets/calendar/calendar_view.dart';
import '../widgets/metrics/daily_assessment_section.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final hPad = w * 0.051;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      // Prevent the scaffold from resizing when the keyboard appears.
      // Without this, Flutter fills the vacated space with the scaffold
      // background color, showing a gray block beneath the floating nav bar.
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(hPad, w * 0.084, hPad, w * 0.076),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Прогресс', style: AppTextStyles.displayMedium),
              SizedBox(height: w * 0.061),

              // ── Daily skin-state assessment ────────────────────────────
              const DailyAssessmentSection(),

              SizedBox(height: w * 0.051),

              // ── Metrics trend chart ────────────────────────────────────
              const MetricsChartWidget(),

              SizedBox(height: w * 0.051),

              // ── Calendar + comparison ──────────────────────────────────
              const CalendarView(),

              // ── [DEV] Mock data button — debug builds only ─────────────
              SizedBox(height: w * 0.051),
              const _MockDataButton(),

              SizedBox(height: w * 0.030),
            ],
          ),
        ),
      ),
    );
  }
}

// ── [DEV] Mock data trigger ───────────────────────────────────────────────────
// TODO: remove this widget before production release.

class _MockDataButton extends StatefulWidget {
  const _MockDataButton();

  @override
  State<_MockDataButton> createState() => _MockDataButtonState();
}

class _MockDataButtonState extends State<_MockDataButton> {
  bool _loading = false;
  bool _done = false;

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _done = false;
    });

    try {
      await generateMockAssessments();
      if (mounted) {
        setState(() {
          _loading = false;
          _done = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ 90 days of data generated'),
            backgroundColor: Color(0xFF6F8F5A),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✗ Error: $e'),
            backgroundColor: AppColors.alertRed,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;

    return SizedBox(
      width: double.infinity,
      height: w * 0.112,
      child: OutlinedButton.icon(
        onPressed: _loading ? null : _generate,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.golden, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(w * 0.038),
          ),
          foregroundColor: AppColors.golden,
        ),
        icon: _loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: AppColors.golden,
                ),
              )
            : Icon(
                _done ? Icons.check_circle_outline : Icons.science_outlined,
                size: 18,
              ),
        label: Text(
          _done
              ? '90 days generated'
              : _loading
              ? 'Generating…'
              : '[DEV] Generate 90-day mock data',
          style: const TextStyle(
            fontFamily: 'SF Pro',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.3,
          ),
        ),
      ),
    );
  }
}
