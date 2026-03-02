import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Golden ON/OFF switch for the "Получать уведомления об уходе" row.
///
/// Thumb is always white; track is [AppColors.golden] when ON and
/// [AppColors.progressBarBack] when OFF — matching the Figma design.
class AccountNotificationsToggle extends StatelessWidget {
  const AccountNotificationsToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      onChanged: onChanged,
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.golden
            : AppColors.progressBarBack,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
