import 'package:flutter/material.dart';
import 'app_colors.dart';

/// All text styles extracted from the Figma design tokens frame.
///
/// Font family: SF Pro (Apple system font on iOS; bundle via pubspec.yaml
/// for Android, or substitute with a Google Font such as Inter/Nunito).
/// Declare the font in pubspec.yaml:
///   fonts:
///     - family: SF Pro
///       fonts:
///         - asset: fonts/SF-Pro-Text-Regular.otf
///         - asset: fonts/SF-Pro-Text-Medium.otf
///           weight: 500
///         - asset: fonts/SF-Pro-Text-Semibold.otf
///           weight: 600
class AppTextStyles {
  AppTextStyles._();

  static const String _fontFamily = 'SF Pro';

  // ---------------------------------------------------------------------------
  // Display / Heading  — 24 px
  // ---------------------------------------------------------------------------

  /// Large heading. Used for main metric values and screen titles.
  static const TextStyle displayMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w400,
    color: AppColors.primaryDark,
    height: 1.5, // ~36 px line-height matching Figma
  );

  // ---------------------------------------------------------------------------
  // Body / Progress  — 16 px
  // ---------------------------------------------------------------------------

  /// Standard body text and progress labels.
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.primaryDark,
    height: 1.5,
  );

  /// Body text in the medium-brown progress-text color.
  static const TextStyle bodyLargeProgress = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.primaryMedium,
    height: 1.5,
  );

  // ---------------------------------------------------------------------------
  // Label / Caption  — 14 px
  // ---------------------------------------------------------------------------

  /// General-purpose label — progress bar gradient description, section titles.
  static const TextStyle labelMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.primaryDark,
    height: 1.5,
  );

  /// Label for "Rate the state" and alert CTA buttons.
  static const TextStyle labelMediumAlert = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.alertRed,
    height: 1.5,
  );

  /// Label for "Skin gradient analysis" and similar image/section captions.
  static const TextStyle labelMediumGolden = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.golden,
    height: 1.5,
  );

  // ---------------------------------------------------------------------------
  // Small / Micro  — 10 px
  // ---------------------------------------------------------------------------

  /// Smallest readable label — skin indicator names, care-today tags.
  static const TextStyle labelSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: AppColors.primaryLight,
    height: 1.5,
  );

  /// Micro label in amber — Bubylka advice subtitle.
  static const TextStyle labelSmallAmber = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: AppColors.amber,
    height: 1.5,
  );

  /// Micro label for "/10" score suffix.
  static const TextStyle labelSmallScore = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: AppColors.primaryLight,
    height: 1.5,
  );

  /// Micro icon / utility label in golden color.
  static const TextStyle labelSmallGolden = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: AppColors.golden,
    height: 1.5,
  );

  // ---------------------------------------------------------------------------
  // Account / Settings screen
  // ---------------------------------------------------------------------------

  /// Section header (e.g. "Профиль", "Настройки приложения") — 16 px.
  /// Figma: SF Pro Light → nearest bundled weight is w400.
  static const TextStyle sectionLabel = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.primaryLight,
    height: 1.5, // 24 px line-height
  );

  /// Settings row title (e.g. "Имя", "Тип кожи") — 14 px Medium.
  /// Figma: SF Pro Medium, tracking −0.5 px.
  static const TextStyle rowTitle = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.primaryDark,
    height: 1.43, // 20 px line-height
    letterSpacing: -0.5,
  );

  /// Settings row subtitle / placeholder — 12 px.
  /// Figma: SF Pro Light → nearest bundled weight is w400.
  static const TextStyle rowCaption = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.primaryMedium,
    height: 1.67, // 20 px line-height
    letterSpacing: -0.5,
  );
}
