import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class CareRoutineSection extends StatelessWidget {
  const CareRoutineSection({super.key});

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
            'Ваш уход сегодня',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.primaryLight,
              fontWeight: FontWeight.w300,
            ),
          ),
          SizedBox(height: w * 0.030),
          Row(
            children: [
              Expanded(
                child: _RoutineCard(
                  icon: Icons.wb_sunny_outlined,
                  label: 'Утренний уход',
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                child: _RoutineCard(
                  icon: Icons.bedtime_outlined,
                  label: 'Вечерний уход',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;

    return GestureDetector(
      onTap: () {},
      child: Container(
        height: w * 0.224,
        padding: EdgeInsets.fromLTRB(w * 0.046, w * 0.030, w * 0.046, w * 0.030),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: w * 0.076,
              color: const Color(0xFFE3E3E3),
            ),
            const Spacer(),
            Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                fontWeight: FontWeight.w500,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
