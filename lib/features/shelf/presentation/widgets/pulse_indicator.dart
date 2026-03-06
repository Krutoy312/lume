import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Animated golden pulse indicator shown on scheduled products.
///
/// Renders a static center dot with an expanding ring that fades out,
/// creating a "breathing" pulse effect.
/// Wrapped in [RepaintBoundary] to isolate repaints from parent widgets.
class PulseIndicator extends StatefulWidget {
  const PulseIndicator({super.key});

  @override
  State<PulseIndicator> createState() => _PulseIndicatorState();
}

class _PulseIndicatorState extends State<PulseIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    // Outer container is larger than the visible 12px Figma dot so the wave
    // has room to expand without clipping.
    final outerSize = w * 0.046; // ~18 px at 393 px reference
    final dotSize = w * 0.015;   // ~6 px static center dot

    return RepaintBoundary(
      child: SizedBox.square(
        dimension: outerSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Expanding pulse wave — scale 0.4 → 1.0, opacity 0.22 → 0
            AnimatedBuilder(
              animation: _controller,
              builder: (_, __) {
                final t = _controller.value;
                return Opacity(
                  opacity: 0.22 * (1.0 - t),
                  child: Transform.scale(
                    scale: 0.4 + 0.6 * t,
                    child: Container(
                      width: outerSize,
                      height: outerSize,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.golden,
                      ),
                    ),
                  ),
                );
              },
            ),
            // Static center dot
            Container(
              width: dotSize,
              height: dotSize,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.golden,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
