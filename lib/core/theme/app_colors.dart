import 'package:flutter/material.dart';

/// All project colors extracted from the Figma design tokens frame.
/// Usage: AppColors.primaryDark, AppColors.golden, etc.
class AppColors {
  AppColors._();

  // ---------------------------------------------------------------------------
  // Primary Brown Palette
  // ---------------------------------------------------------------------------

  /// Dark espresso — main headings / primary text
  static const Color primaryDark = Color(0xFF5C4A3D);

  /// Medium taupe — progress text
  static const Color primaryMedium = Color(0xFFA89580);

  /// Warm sand — skin indicators / care-today labels / /10 text
  static const Color primaryLight = Color(0xFFBDA593);

  /// Amber — Bubylka advice text
  static const Color amber = Color(0xFFB87A39);

  // ---------------------------------------------------------------------------
  // Golden / Caramel Palette
  // ---------------------------------------------------------------------------

  /// Golden caramel — icons, primary accent, progress bar, metrics gradient start
  static const Color golden = Color(0xFFC89968);

  /// Warm gold mid — progress bar gradient midpoint
  static const Color goldenMid = Color(0xFFD4A574);

  /// Soft gold — progress bar gradient light step
  static const Color goldenLight = Color(0xFFDFB586);

  /// Champagne — metrics gradient end
  static const Color goldenLighter = Color(0xFFF3D2AF);

  // ---------------------------------------------------------------------------
  // Surface / Background
  // ---------------------------------------------------------------------------

  /// Progress bar track background
  static const Color progressBarBack = Color(0xFFF5EDE4);

  /// App scaffold background — light warm grey
  static const Color scaffoldBackground = Color(0xFFF7F7F7);

  /// Card / main-block surface — pure white
  static const Color surface = Color(0xFFFFFFFF);

  // ---------------------------------------------------------------------------
  // Advice Lamp Gradient (blue-tinted highlight)
  // ---------------------------------------------------------------------------

  /// Advice lamp gradient — start (cool blue tint)
  static const Color adviceLampStart = Color(0xFFECF3FF);

  /// Advice lamp gradient — end (near white)
  static const Color adviceLampEnd = Color(0xFFF5F9FF);

  // ---------------------------------------------------------------------------
  // Semantic
  // ---------------------------------------------------------------------------

  /// Alert / CTA destructive — "Rate the state" button
  static const Color alertRed = Color(0xFFA72608);

  // ---------------------------------------------------------------------------
  // Gradients
  // ---------------------------------------------------------------------------

  /// Progress bar fill gradient (left → right, golden shades)
  static const LinearGradient progressBarGradient = LinearGradient(
    colors: [golden, goldenMid, goldenLight, goldenLight, golden],
  );

  /// Metrics slider gradient
  static const LinearGradient metricsGradient = LinearGradient(
    colors: [golden, goldenLighter],
  );

  /// Advice card with lamp icon — subtle blue-tinted background gradient
  static const LinearGradient adviceLampGradient = LinearGradient(
    begin: Alignment(-1.0, 0.0),
    end: Alignment(1.0, 0.0),
    stops: [0.092, 0.908],
    colors: [adviceLampStart, adviceLampEnd],
  );
}
