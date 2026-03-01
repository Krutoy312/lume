import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../domain/auth_failure.dart';
import '../providers/auth_provider.dart';
import '../widgets/social_sign_in_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // Which button is currently loading (prevents double-tap of other buttons).
  _AuthMethod? _activeMethod;

  @override
  Widget build(BuildContext context) {
    // Listen for errors — surface them as an inline message.
    ref.listen<AsyncValue<void>>(authControllerProvider, (_, state) {
      if (state.hasError) {
        // On success the router redirects automatically; errors stay here.
        setState(() => _activeMethod = null);
      }
      if (state is AsyncData) {
        setState(() => _activeMethod = null);
      }
    });

    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;
    final errorMessage = authState.hasError
        ? (authState.error is AuthFailure
            ? (authState.error as AuthFailure).message
            : 'Ошибка входа. Попробуйте снова.')
        : null;

    final w = MediaQuery.sizeOf(context).width;
    final hPad = w * 0.064; // ~25 px at 393 px

    return LoadingOverlay(
      isLoading: isLoading,
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height -
                  MediaQuery.paddingOf(context).top -
                  MediaQuery.paddingOf(context).bottom,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),

                  // ── Branding ──────────────────────────────────────────────
                  _BrandingSection(w: w),

                  const Spacer(flex: 4),

                  // ── Error banner ──────────────────────────────────────────
                  if (errorMessage != null) ...[
                    _ErrorBanner(
                      message: errorMessage,
                      onDismiss: () =>
                          ref.read(authControllerProvider.notifier).clearError(),
                    ),
                    SizedBox(height: w * 0.046),
                  ],

                  // ── Sign-in buttons ───────────────────────────────────────
                  SocialSignInButton(
                    label: 'Войти через Google',
                    leadingIcon: GoogleLogoIcon(size: w * 0.051),
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.primaryDark,
                    borderColor: AppColors.progressBarBack,
                    isLoading: _activeMethod == _AuthMethod.google,
                    onPressed: isLoading
                        ? null
                        : () => _signIn(_AuthMethod.google),
                  ),

                  SizedBox(height: w * 0.031),

                  if (Platform.isIOS)
                    SocialSignInButton(
                      label: 'Войти через Apple',
                      leadingIcon: AppleLogoIcon(
                        size: w * 0.051,
                        color: AppColors.surface,
                      ),
                      backgroundColor: AppColors.primaryDark,
                      foregroundColor: AppColors.surface,
                      borderColor: Colors.transparent,
                      isLoading: _activeMethod == _AuthMethod.apple,
                      onPressed: isLoading
                          ? null
                          : () => _signIn(_AuthMethod.apple),
                    ),

                  if (Platform.isIOS) SizedBox(height: w * 0.031),

                  // ── Divider ───────────────────────────────────────────────
                  _OrDivider(w: w),

                  SizedBox(height: w * 0.046),

                  // ── Anonymous ─────────────────────────────────────────────
                  _AnonymousButton(
                    isLoading: _activeMethod == _AuthMethod.anonymous,
                    onPressed: isLoading
                        ? null
                        : () => _signIn(_AuthMethod.anonymous),
                  ),

                  const Spacer(flex: 2),

                  // ── Legal note ────────────────────────────────────────────
                  _LegalNote(w: w),

                  SizedBox(height: w * 0.046),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signIn(_AuthMethod method) async {
    setState(() => _activeMethod = method);

    final controller = ref.read(authControllerProvider.notifier);
    switch (method) {
      case _AuthMethod.google:
        await controller.signInWithGoogle();
      case _AuthMethod.apple:
        await controller.signInWithApple();
      case _AuthMethod.anonymous:
        await controller.signInAnonymously();
    }
  }
}

// ── Enum ──────────────────────────────────────────────────────────────────────

enum _AuthMethod { google, apple, anonymous }

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _BrandingSection extends StatelessWidget {
  const _BrandingSection({required this.w});

  final double w;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Mascot placeholder — replaced with Lottie animation later.
        Container(
          width: w * 0.254,
          height: w * 0.254,
          decoration: const BoxDecoration(
            color: AppColors.progressBarBack,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '🧴',
              style: TextStyle(fontSize: w * 0.112),
            ),
          ),
        ),

        SizedBox(height: w * 0.061),

        Text(
          'SkinCare',
          style: AppTextStyles.displayMedium.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: w * 0.076,
          ),
        ),

        SizedBox(height: w * 0.020),

        Text(
          'Твой персональный уход за кожей',
          style: AppTextStyles.bodyLargeProgress,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: w * 0.046,
        vertical: w * 0.036,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFDAD6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.alertRed, size: 18),
          SizedBox(width: w * 0.025),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.alertRed,
              ),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close, color: AppColors.alertRed, size: 18),
          ),
        ],
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.w});

  final double w;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.progressBarBack)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: w * 0.036),
          child: Text(
            'или',
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.primaryLight,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.progressBarBack)),
      ],
    );
  }
}

class _AnonymousButton extends StatelessWidget {
  const _AnonymousButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryMedium,
        padding: EdgeInsets.symmetric(
          horizontal: w * 0.051,
          vertical: w * 0.025,
        ),
      ),
      child: isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                color: AppColors.primaryMedium,
                strokeWidth: 2,
              ),
            )
          : Text(
              'Продолжить без аккаунта',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.primaryMedium,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.primaryMedium,
              ),
            ),
    );
  }
}

class _LegalNote extends StatelessWidget {
  const _LegalNote({required this.w});

  final double w;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Входя в приложение, вы соглашаетесь с\nПолитикой конфиденциальности',
      style: AppTextStyles.labelSmall.copyWith(
        color: AppColors.primaryLight,
        fontSize: w * 0.028,
      ),
      textAlign: TextAlign.center,
    );
  }
}
