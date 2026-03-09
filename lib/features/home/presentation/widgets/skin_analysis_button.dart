import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/providers/shell_tab_provider.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../ai_assistant/presentation/controllers/chat_controller.dart';

class SkinAnalysisButton extends ConsumerWidget {
  const SkinAnalysisButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = MediaQuery.sizeOf(context).width;
    final hPad = w * 0.051;

    return GestureDetector(
      onTap: () {
        ref.read(chatProvider.notifier).selectMode(ChatMode.skinPhoto);
        ref.read(shellTabProvider.notifier).state = 3; // Chat tab
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: hPad),
        height: w * 0.092,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFFC89968), Color(0xFFD4A574), Color(0xFFDFB586)],
          ),
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: w * 0.046),
          child: Row(
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Анализ кожи ',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.5,
                      ),
                    ),
                    TextSpan(
                      text: 'по фото',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: w * 0.005),
              SvgPicture.asset(
                'assets/icons/ic_star.svg',
                width: w * 0.025,
                height: w * 0.025,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
