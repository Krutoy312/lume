import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// ── Data ─────────────────────────────────────────────────────────────────────

/// Ordered list of (Russian label, Firestore value).
///
/// Firestore rules enforce: skinType in ['normal', 'dry', 'oily', 'combo'].
/// Note: "Комбинированная" maps to 'combo', NOT 'combination'.
const List<(String, String)> _skinTypes = [
  ('Сухая',           'dry'),
  ('Жирная',          'oily'),
  ('Комбинированная', 'combo'),
  ('Нормальная',      'normal'),
];

/// Public reverse-lookup: Firestore value → Russian display label.
///
/// Used by [AccountScreen] to show the selected type in the row subtitle.
/// Returns null when [value] is null or not in the known set.
String? skinTypeLabel(String? value) {
  if (value == null) return null;
  for (final (label, v) in _skinTypes) {
    if (v == value) return label;
  }
  return null;
}

// ── Launcher ─────────────────────────────────────────────────────────────────

/// Shows the skin-type picker as a modal bottom sheet.
///
/// Pass [currentSkinType] (the Firestore value, e.g. 'oily') so the sheet
/// can highlight the currently-selected row.
Future<void> showSkinTypeBottomSheet(
  BuildContext context, {
  String? currentSkinType,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,   // renders above FloatingNavBar
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: const Color(0x80000000), // 50 % black dim
    builder: (_) => ColoredBox(
      color: Colors.transparent,
      child: SkinTypeBottomSheet(currentSkinType: currentSkinType),
    ),
  );
}

// ── Widget ───────────────────────────────────────────────────────────────────

class SkinTypeBottomSheet extends ConsumerStatefulWidget {
  const SkinTypeBottomSheet({super.key, this.currentSkinType});

  /// Currently-saved Firestore value (e.g. 'oily'). Used to pre-select a row.
  final String? currentSkinType;

  @override
  ConsumerState<SkinTypeBottomSheet> createState() =>
      _SkinTypeBottomSheetState();
}

class _SkinTypeBottomSheetState extends ConsumerState<SkinTypeBottomSheet> {
  bool _loading = false;

  Future<void> _onSelect(String value) async {
    if (_loading) return;
    setState(() => _loading = true);

    await ref.read(authControllerProvider.notifier).updateSkinType(value);
    if (!mounted) return;

    // Pop on success; reset loading on error so the user can retry.
    final authState = ref.read(authControllerProvider);
    if (authState is AsyncError) {
      setState(() => _loading = false);
    } else {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final sysPad = MediaQuery.paddingOf(context).bottom;
    // Safe-area + 24 px breathing room below the last row.
    final bottomPad = (sysPad > 0 ? sysPad : 0.0) + 24.0;

    // Match the Russian label to pre-select the correct row.
    final selectedLabel = skinTypeLabel(widget.currentSkinType);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        w * 0.051, // 20 px left  (ref: 20 / 393)
        w * 0.061, // 24 px top   (ref: 24 / 393)
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
          SizedBox(height: w * 0.061), // ~24 px gap before list
          for (var i = 0; i < _skinTypes.length; i++) ...[
            _TypeRow(
              w: w,
              label: _skinTypes[i].$1,
              isSelected: _skinTypes[i].$1 == selectedLabel,
              enabled: !_loading,
              onTap: () => _onSelect(_skinTypes[i].$2),
            ),
            if (i < _skinTypes.length - 1)
              SizedBox(height: w * 0.031), // ~12 px gap between rows
          ],
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.w});

  final double w;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Выберете тип кожи',
            style: AppTextStyles.rowTitle.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryDark,
              letterSpacing: -0.5,
            ),
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.of(context, rootNavigator: true).pop(),
          child: SvgPicture.asset(
            'assets/icons/ic_close.svg',
            width: w * 0.041,  // ~16 px
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

class _TypeRow extends StatelessWidget {
  const _TypeRow({
    required this.w,
    required this.label,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
  });

  final double w;
  final String label;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: w * 0.102, // ~40 px  (ref: 40 / 393)
        padding: EdgeInsets.symmetric(horizontal: w * 0.051), // 20 px
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.progressBarGradient : null,
          color: isSelected ? null : const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(15),
        ),
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: AppTextStyles.rowTitle.copyWith(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.primaryDark,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}
