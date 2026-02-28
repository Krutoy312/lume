import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

/// Main ThemeData for the SkinCare app.
/// Apply via MaterialApp(theme: AppTheme.light).
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      // Primary — dark espresso brown
      primary: AppColors.primaryDark,
      onPrimary: AppColors.surface,
      // Primary container — golden caramel (accent, progress, icons)
      primaryContainer: AppColors.golden,
      onPrimaryContainer: AppColors.surface,
      // Secondary — warm sand
      secondary: AppColors.primaryLight,
      onSecondary: AppColors.surface,
      secondaryContainer: AppColors.progressBarBack,
      onSecondaryContainer: AppColors.primaryDark,
      // Tertiary — amber (Bubylka, advice)
      tertiary: AppColors.amber,
      onTertiary: AppColors.surface,
      tertiaryContainer: AppColors.adviceLampStart,
      onTertiaryContainer: AppColors.primaryDark,
      // Error — alert red ("Rate the state" CTA)
      error: AppColors.alertRed,
      onError: AppColors.surface,
      errorContainer: Color(0xFFFFDAD6),
      onErrorContainer: AppColors.alertRed,
      // Surfaces
      surface: AppColors.surface,
      onSurface: AppColors.primaryDark,
      surfaceContainerHighest: AppColors.scaffoldBackground,
      onSurfaceVariant: AppColors.primaryMedium,
      outline: AppColors.primaryLight,
      outlineVariant: AppColors.progressBarBack,
      shadow: AppColors.primaryDark,
      scrim: AppColors.primaryDark,
      inverseSurface: AppColors.primaryDark,
      onInverseSurface: AppColors.surface,
      inversePrimary: AppColors.goldenLight,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.scaffoldBackground,

      // -------------------------------------------------------------------------
      // Typography
      // -------------------------------------------------------------------------
      fontFamily: 'SF Pro',
      textTheme: const TextTheme(
        // 24 px — screen/section headings
        displayMedium: AppTextStyles.displayMedium,
        // 16 px — body copy, progress labels
        bodyLarge: AppTextStyles.bodyLarge,
        bodyMedium: AppTextStyles.bodyLargeProgress,
        // 14 px — captions, section labels, CTA text
        labelLarge: AppTextStyles.labelMedium,
        labelMedium: AppTextStyles.labelMediumGolden,
        bodySmall: AppTextStyles.labelMediumAlert,
        // 10 px — micro labels, score suffixes, icon labels
        labelSmall: AppTextStyles.labelSmall,
      ),

      // -------------------------------------------------------------------------
      // AppBar
      // -------------------------------------------------------------------------
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primaryDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: AppTextStyles.displayMedium,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),

      // -------------------------------------------------------------------------
      // Bottom Navigation Bar
      // -------------------------------------------------------------------------
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primaryDark,
        unselectedItemColor: AppColors.primaryLight,
        selectedLabelStyle: AppTextStyles.labelSmall,
        unselectedLabelStyle: AppTextStyles.labelSmall,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),

      // -------------------------------------------------------------------------
      // Cards
      // -------------------------------------------------------------------------
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // -------------------------------------------------------------------------
      // Elevated Button — primary CTA (golden)
      // -------------------------------------------------------------------------
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.golden,
          foregroundColor: AppColors.surface,
          textStyle: AppTextStyles.labelMedium,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),

      // -------------------------------------------------------------------------
      // Filled Button — alert / "Rate the state" CTA
      // -------------------------------------------------------------------------
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.alertRed,
          foregroundColor: AppColors.surface,
          textStyle: AppTextStyles.labelMedium,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // -------------------------------------------------------------------------
      // Outlined Button — secondary actions
      // -------------------------------------------------------------------------
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryDark,
          side: const BorderSide(color: AppColors.primaryLight),
          textStyle: AppTextStyles.labelMedium,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // -------------------------------------------------------------------------
      // Input Fields
      // -------------------------------------------------------------------------
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: AppTextStyles.bodyLargeProgress,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.progressBarBack),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.golden),
        ),
      ),

      // -------------------------------------------------------------------------
      // Slider — used in Metrics screen
      // -------------------------------------------------------------------------
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.golden,
        inactiveTrackColor: AppColors.progressBarBack,
        thumbColor: AppColors.golden,
        overlayColor: Color(0x29C89968),
        valueIndicatorColor: AppColors.primaryDark,
        valueIndicatorTextStyle: AppTextStyles.labelSmall,
      ),

      // -------------------------------------------------------------------------
      // Progress Indicator
      // -------------------------------------------------------------------------
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.golden,
        linearTrackColor: AppColors.progressBarBack,
      ),

      // -------------------------------------------------------------------------
      // Chip
      // -------------------------------------------------------------------------
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.progressBarBack,
        labelStyle: AppTextStyles.labelSmall,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),

      // -------------------------------------------------------------------------
      // Divider
      // -------------------------------------------------------------------------
      dividerTheme: const DividerThemeData(
        color: AppColors.progressBarBack,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
