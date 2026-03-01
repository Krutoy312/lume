import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Generic sign-in button following the app's card design language.
///
/// Shows a [leadingIcon], [label], and optionally a loading spinner.
/// Background, text color, and border are fully configurable so the same
/// widget covers Google (white) and Apple (black) variants.
class SocialSignInButton extends StatelessWidget {
  const SocialSignInButton({
    super.key,
    required this.label,
    required this.leadingIcon,
    required this.onPressed,
    this.backgroundColor = AppColors.surface,
    this.foregroundColor = AppColors.primaryDark,
    this.borderColor = AppColors.progressBarBack,
    this.isLoading = false,
  });

  final String label;
  final Widget leadingIcon;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final height = w * 0.138; // ≈ 54 px at 393 px reference width

    return SizedBox(
      width: double.infinity,
      height: height,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledForegroundColor: foregroundColor.withAlpha(120),
          side: BorderSide(color: borderColor, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: EdgeInsets.symmetric(horizontal: w * 0.051),
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: foregroundColor,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  leadingIcon,
                  SizedBox(width: w * 0.031),
                  Text(
                    label,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: foregroundColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Google brand icon (inline, no external asset required) ───────────────────

/// Minimal "G" icon that approximates the Google logo coloring.
class GoogleLogoIcon extends StatelessWidget {
  const GoogleLogoIcon({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    // Blue arc (top-right)
    canvas.drawArc(rect, -1.57, 2.2,
        false, Paint()..color = const Color(0xFF4285F4)..strokeWidth = size.width * 0.22..style = PaintingStyle.stroke..strokeCap = StrokeCap.butt);
    // Red arc (bottom-left)
    canvas.drawArc(rect, 0.63, 1.85,
        false, Paint()..color = const Color(0xFFEA4335)..strokeWidth = size.width * 0.22..style = PaintingStyle.stroke..strokeCap = StrokeCap.butt);
    // Yellow arc
    canvas.drawArc(rect, 2.48, 0.80,
        false, Paint()..color = const Color(0xFFFBBC05)..strokeWidth = size.width * 0.22..style = PaintingStyle.stroke..strokeCap = StrokeCap.butt);
    // Green arc
    canvas.drawArc(rect, 3.28, 0.71,
        false, Paint()..color = const Color(0xFF34A853)..strokeWidth = size.width * 0.22..style = PaintingStyle.stroke..strokeCap = StrokeCap.butt);
    // "G" horizontal bar (blue)
    final paint = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = size.height * 0.22
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx + r * 0.78, cy),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Apple icon ────────────────────────────────────────────────────────────────

/// Simple Apple-brand "" rendered via the system font (Unicode).
class AppleLogoIcon extends StatelessWidget {
  const AppleLogoIcon({super.key, this.size = 20, this.color = Colors.white});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      '\uF8FF', // Apple logo private-use character (renders on Apple devices)
      style: TextStyle(
        fontFamily: '.SF Pro Text',
        fontSize: size,
        color: color,
        height: 1,
      ),
    );
  }
}
