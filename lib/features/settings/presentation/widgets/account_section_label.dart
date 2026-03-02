import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';

/// Grey section header rendered above each card group.
/// Examples: "Профиль", "Настройки приложения", "Обратная связь".
class AccountSectionLabel extends StatelessWidget {
  const AccountSectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label, style: AppTextStyles.sectionLabel);
  }
}
