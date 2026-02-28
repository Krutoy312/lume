import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../widgets/care_routine_section.dart';
import '../widgets/goal_progress_card.dart';
import '../widgets/mascot_tip_card.dart';
import '../widgets/quick_actions.dart';
import '../widgets/skin_analysis_button.dart';
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
              _RateStateCta(w: w),
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

class _RateStateCta extends StatelessWidget {
  const _RateStateCta({required this.w});

  final double w;

  @override
  Widget build(BuildContext context) {
    final hPad = w * 0.051;

    return GestureDetector(
      onTap: () {},
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: hPad),
        height: w * 0.244,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Arrow decoration (background element)
            Positioned(
              right: w * 0.046,
              top: 0,
              bottom: 0,
              child: Center(
                child: _BrushArrow(w: w),
              ),
            ),
            // Text content
            Positioned(
              left: w * 0.061,
              top: 0,
              bottom: 0,
              width: w * 0.590,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Оценить состояние\nкожи сегодня!',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.alertRed,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    letterSpacing: -1.1,
                    height: 1.27,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrushArrow extends StatelessWidget {
  const _BrushArrow({required this.w});

  final double w;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(w * 0.280, w * 0.178),
      painter: _BrushArrowPainter(),
    );
  }
}

class _BrushArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.alertRed.withValues(alpha: 0.8)
      ..strokeWidth = size.height * 0.11
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(0, size.height * 0.55)
      ..cubicTo(
        size.width * 0.20, size.height * 0.10,
        size.width * 0.55, size.height * 0.85,
        size.width * 0.88, size.height * 0.35,
      );

    canvas.drawPath(path, paint);

    // Arrowhead
    final arrowPaint = Paint()
      ..color = AppColors.alertRed.withValues(alpha: 0.8)
      ..strokeWidth = size.height * 0.11
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(size.width * 0.88, size.height * 0.35),
      Offset(size.width * 0.70, size.height * 0.25),
      arrowPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.88, size.height * 0.35),
      Offset(size.width * 0.88, size.height * 0.57),
      arrowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
