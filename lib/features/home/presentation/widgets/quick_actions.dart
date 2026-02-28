import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final hPad = w * 0.051;
    final gap = w * 0.030;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Инструменты ухода',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.primaryLight,
              fontWeight: FontWeight.w300,
            ),
          ),
          SizedBox(height: w * 0.030),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.search_rounded,
                  label: 'Найти уход',
                  onTap: () {},
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                child: _ActionButton(
                  icon: Icons.science_outlined,
                  label: 'Анализ продукта',
                  onTap: () {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: w * 0.173,
        padding: EdgeInsets.symmetric(
          horizontal: w * 0.046,
          vertical: w * 0.030,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        child: Row(
          children: [
            Icon(icon, size: w * 0.046, color: AppColors.golden),
            SizedBox(width: w * 0.025),
            Flexible(
              child: Text(
                label,
                style: AppTextStyles.labelMedium.copyWith(
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
