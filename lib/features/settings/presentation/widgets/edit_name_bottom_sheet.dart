import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/domain/auth_failure.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Shows the "Введите имя" bottom sheet.
///
/// Use [useRootNavigator: true] so the sheet overlays the FloatingNavBar:
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   useRootNavigator: true,
///   isScrollControlled: true,
///   builder: (_) => const EditNameBottomSheet(),
/// );
/// ```
Future<void> showEditNameBottomSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,   // renders above FloatingNavBar
    isScrollControlled: true, // sheet can grow to full height
    backgroundColor: Colors.transparent, // no opaque Material behind the sheet
    elevation: 0,             // no shadow that could paint an opaque surface
    barrierColor: const Color(0x80000000), // 50 % black dim overlay
    // AnimatedPadding tracks keyboard height and smoothly lifts the sheet.
    // The gap below the white Container is filled only by the barrier overlay
    // (transparent background + elevation: 0 = no extra opaque layers).
    builder: (ctx) => AnimatedPadding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(ctx).bottom,
      ),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      // Explicit transparent wrapper ensures the route's internal Material
      // widget (if any) cannot paint an opaque background behind the sheet.
      child: const ColoredBox(
        color: Colors.transparent,
        child: EditNameBottomSheet(),
      ),
    ),
  );
}

class EditNameBottomSheet extends ConsumerStatefulWidget {
  const EditNameBottomSheet({super.key});

  @override
  ConsumerState<EditNameBottomSheet> createState() =>
      _EditNameBottomSheetState();
}

class _EditNameBottomSheetState extends ConsumerState<EditNameBottomSheet> {
  late final TextEditingController _controller;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ── Save ────────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    setState(() => _loading = true);
    // _run() in AuthController never rethrows — errors go into AsyncError state.
    await ref.read(authControllerProvider.notifier).updateName(name);
    if (!mounted) return;
    setState(() => _loading = false);

    final authState = ref.read(authControllerProvider);
    if (authState is AsyncError && authState.error is AuthFailure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text((authState.error as AuthFailure).message)),
      );
    } else {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final sysPad = MediaQuery.paddingOf(context).bottom;

    // Keyboard insets are handled by the AnimatedPadding wrapper in
    // showEditNameBottomSheet, so only the safe-area + extra breathing
    // room is needed here (50 px below the Save button).
    final bottomPad = (sysPad > 0 ? sysPad : 0.0) + 50.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        w * 0.051, // 20 px left
        w * 0.061, // 24 px top
        w * 0.051, // 20 px right
        bottomPad,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(w: w),
          SizedBox(height: w * 0.056), // ~22 px
          _NameField(controller: _controller, w: w),
          SizedBox(height: w * 0.038), // ~15 px
          _SaveButton(w: w, loading: _loading, onTap: _save),
        ],
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.w});

  final double w;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Введите имя',
            style: AppTextStyles.rowTitle.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
              letterSpacing: -0.5,
              height: 1.25,
            ),
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.of(context, rootNavigator: true).pop(),
          child: SvgPicture.asset(
            'assets/icons/ic_close.svg',
            width: w * 0.041, // ~16 px
            height: w * 0.041,
            colorFilter: const ColorFilter.mode(
              AppColors.primaryMedium,
              BlendMode.srcIn,
            ),
          ),
        ),
      ],
    );
  }
}

class _NameField extends StatelessWidget {
  const _NameField({required this.controller, required this.w});

  final TextEditingController controller;
  final double w;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: w * 0.102, // ~40 px
      child: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        style: AppTextStyles.rowTitle.copyWith(
          fontSize: 14,
          color: AppColors.primaryDark,
        ),
        decoration: InputDecoration(
          hintText: 'Ваше имя',
          hintStyle: AppTextStyles.rowCaption.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w300,
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: w * 0.051, // 20 px
            vertical: 0,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: AppColors.goldenLight),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: AppColors.golden),
          ),
          filled: false,
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.w,
    required this.loading,
    required this.onTap,
  });

  final double w;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: w * 0.071, // ~28 px matches Figma
        decoration: BoxDecoration(
          gradient: AppColors.progressBarGradient,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                'Сохранить',
                style: AppTextStyles.rowTitle.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.5,
                  height: 1.71,
                ),
              ),
      ),
    );
  }
}
