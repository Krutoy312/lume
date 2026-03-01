import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Full-screen semi-transparent overlay with a centered spinner.
/// Wrap the page content with this to block interaction during async operations.
///
/// Usage:
/// ```dart
/// LoadingOverlay(
///   isLoading: authState.isLoading,
///   child: _MyPageBody(),
/// )
/// ```
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
  });

  final bool isLoading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x55000000),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.golden,
                  strokeWidth: 2.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
