import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Fixed top bar: character avatar + "Lume" title + "AI-ассистент" subtitle.
class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ChatAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(92);

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;

    return Container(
      height: 92,
      color: AppColors.surface,
      padding: EdgeInsets.only(
        left: w * 0.051,
        right: w * 0.051,
        top: MediaQuery.paddingOf(context).top,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Character avatar circle
          Container(
            width: w * 0.107, // ~42px
            height: w * 0.107,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.progressBarBack,
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/images/img_character_chat.png',
              fit: BoxFit.cover,
            ),
          ),
          SizedBox(width: w * 0.030),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lume',
                style: TextStyle(
                  fontFamily: 'SF Pro',
                  fontSize: w * 0.041,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryDark,
                  height: 1.25,
                ),
              ),
              Text(
                'AI-ассистент',
                style: TextStyle(
                  fontFamily: 'SF Pro Rounded',
                  fontSize: w * 0.031,
                  fontWeight: FontWeight.w400,
                  color: AppColors.primaryMedium,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
