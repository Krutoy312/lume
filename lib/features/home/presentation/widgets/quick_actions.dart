import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/providers/shell_tab_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../ai_assistant/presentation/controllers/chat_controller.dart';

class QuickActions extends ConsumerWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  assetPath: 'assets/icons/ic_leaf.svg',
                  label: 'Подобрать уход',
                  onTap: () {
                    ref
                        .read(chatProvider.notifier)
                        .selectMode(ChatMode.routinePick);
                    ref.read(shellTabProvider.notifier).state = 3;
                  },
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                child: _ActionButton(
                  assetPath: 'assets/icons/ic_scan.svg',
                  label: 'Анализ продукта',
                  onTap: () {
                    ref
                        .read(chatProvider.notifier)
                        .selectMode(ChatMode.productPhoto);
                    ref.read(shellTabProvider.notifier).state = 3;
                  },
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
    required this.assetPath,
    required this.label,
    required this.onTap,
  });

  final String assetPath;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: w * 0.173,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(assetPath, width: w * 0.046, height: w * 0.046),
              SizedBox(width: w * 0.020),
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
      ),
    );
  }
}
